defmodule Aesir.ZoneServer.Mmo.StatusEffect.Removal do
  @moduledoc """
  Ends statuses through their end logic.

  `remove_status/4` and `remove_statuses/4` run a status's `on_expire` (or its
  `on_end_request/3` decision), delete the instance, end its `end_on_end`
  chain, clear its display and notify the holder's session. The
  `expire_*_if_current` entries do the same only while a captured entry is
  still the current generation. The batch entries (`remove_on_death/3`,
  `remove_on_map_change/2`, `enforce_weapon_requirements/3`,
  `remove_all_statuses/3`, `end_removed_unit_statuses/2`,
  `end_unsaved_statuses/2`) select what a lifecycle event ends and run it
  through the same path.
  """

  alias Aesir.ZoneServer.Mmo.StatusEffect.ContextBuilder
  alias Aesir.ZoneServer.Mmo.StatusEffect.Notifications
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusEffect.StatusDisplay
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @type unit_type :: Unit.unit_type()
  @type remove_option :: Notifications.remove_option()
  @type status_event :: Notifications.status_event()

  @doc """
  Removes a status effect, running its on_expire callback first.

  A status implementing `on_end_request/3` decides whether it ends; this holds
  for every removal below that goes through `remove_statuses/4` too. A holder
  already gone from the registry still ends it, its end logic seeing empty
  target stats.

  `owner_refresh: :notify` publishes the player's asynchronous refresh after a
  real removal. `owner_refresh: :defer` is for an owning session that will
  synchronously recalculate and commit the state in the same handler. The
  default `:auto` defers when the caller is the owning player process and
  notifies otherwise.
  """
  @spec remove_status(unit_type(), integer(), atom(), [remove_option()]) :: :ok
  def remove_status(unit_type, unit_id, status_id, opts \\ []) do
    {:ok, _events} = remove_status_with_events(unit_type, unit_id, status_id, opts)
    :ok
  end

  @doc "Removes a status through its normal lifecycle and returns actual committed mutations."
  @spec remove_status_with_events(unit_type(), integer(), atom(), [remove_option()]) ::
          {:ok, [status_event()]}
  def remove_status_with_events(unit_type, unit_id, status_id, opts) do
    events = remove_status_events(unit_type, unit_id, status_id)
    Notifications.maybe_refresh_owner(unit_type, unit_id, events, opts)
    {:ok, events}
  end

  @doc """
  Removes a status only while `instance` is still its current entry, through the
  normal expiration lifecycle, then applies the owner-refresh policy. Returns
  whether `instance` was removed.
  """
  @spec remove_status_if_current(unit_type(), integer(), atom(), StatusEntry.t(), [
          remove_option()
        ]) ::
          boolean()
  def remove_status_if_current(unit_type, unit_id, status_id, instance, opts \\ []) do
    events = expire_status_events_if_current(unit_type, unit_id, status_id, instance)
    Notifications.maybe_refresh_owner(unit_type, unit_id, events, opts)
    events != []
  end

  @doc """
  Removes the supplied statuses through the normal expiration lifecycle and
  applies the selected owner-refresh policy once after the batch.
  """
  @spec remove_statuses(unit_type(), integer(), [atom()], [remove_option()]) :: :ok
  def remove_statuses(unit_type, unit_id, status_ids, opts \\ []) do
    {:ok, events} = remove_statuses_with_events(unit_type, unit_id, status_ids, opts)
    Notifications.maybe_refresh_owner(unit_type, unit_id, events, opts)
  end

  @doc "Removes the supplied statuses with no owner refresh and returns the committed mutations."
  @spec remove_statuses_with_events(unit_type(), integer(), [atom()], keyword()) ::
          {:ok, [status_event()]}
  def remove_statuses_with_events(unit_type, unit_id, status_ids, _opts) do
    events = Enum.flat_map(status_ids, &remove_status_events(unit_type, unit_id, &1))
    {:ok, events}
  end

  @doc "Removes a status with no owner refresh; returns whether anything was removed."
  @spec remove_status_without_refresh(unit_type(), integer(), atom()) :: boolean()
  def remove_status_without_refresh(unit_type, unit_id, status_id),
    do: remove_status_events(unit_type, unit_id, status_id) != []

  defp remove_status_events(unit_type, unit_id, status_id) do
    if MapSet.member?(Registry.statuses_implementing(:on_end_request), status_id),
      do: request_end_events(unit_type, unit_id, status_id),
      else: end_status_events(unit_type, unit_id, status_id)
  end

  defp end_status_events(unit_type, unit_id, status_id) do
    case {Registry.get_definition(status_id),
          StatusStorage.get_status(unit_type, unit_id, status_id)} do
      {%{module: module}, %StatusEntry{} = instance} ->
        context = end_context(unit_type, unit_id, instance)
        module.on_expire({unit_type, unit_id}, instance, context)
        StatusStorage.remove_status(unit_type, unit_id, status_id)
        chained = end_on_end_events(unit_type, unit_id, status_id)
        StatusDisplay.on_removed(unit_type, unit_id, status_id, instance)
        Notifications.notify_unit_status_removed(unit_type, unit_id, status_id)
        recheck_touch_on_end(unit_type, unit_id, status_id)
        [{status_id, :removed} | chained]

      _absent ->
        []
    end
  end

  defp end_on_end_events(unit_type, unit_id, status_id) do
    %{end_on_end: chained} = Registry.get_definition(status_id)

    chained
    |> Enum.reject(&infinite_endure?(StatusStorage.get_status(unit_type, unit_id, &1)))
    |> Enum.flat_map(&remove_status_events(unit_type, unit_id, &1))
  end

  # A status deciding how it ends (`on_end_request/3`): its outcome is stored
  # only over the entry it was asked about, asking again after a lost race.
  defp request_end_events(unit_type, unit_id, status_id) do
    %{module: module} = Registry.get_definition(status_id)

    case StatusStorage.get_status(unit_type, unit_id, status_id) do
      nil ->
        []

      instance ->
        context = end_context(unit_type, unit_id, instance)
        outcome = module.on_end_request({unit_type, unit_id}, instance, context)

        case store_end_outcome(outcome, unit_type, unit_id, status_id, instance) do
          :lost_race -> request_end_events(unit_type, unit_id, status_id)
          :kept -> []
          :ended -> finish_requested_end(module, unit_type, unit_id, instance, context, outcome)
        end
    end
  end

  defp store_end_outcome({:keep, kept, after_end}, unit_type, unit_id, status_id, instance) do
    if StatusStorage.replace_status_if_current(unit_type, unit_id, status_id, instance, kept) do
      after_end.()
      :kept
    else
      :lost_race
    end
  end

  defp store_end_outcome({:end, _after_end}, unit_type, unit_id, status_id, instance) do
    if StatusStorage.remove_status_if_current(unit_type, unit_id, status_id, instance),
      do: :ended,
      else: :lost_race
  end

  defp finish_requested_end(module, unit_type, unit_id, instance, context, {:end, after_end}) do
    module.on_expire({unit_type, unit_id}, instance, context)
    chained = end_on_end_events(unit_type, unit_id, instance.type)
    StatusDisplay.on_removed(unit_type, unit_id, instance.type, instance)
    Notifications.notify_unit_status_removed(unit_type, unit_id, instance.type)
    recheck_touch_on_end(unit_type, unit_id, instance.type)
    after_end.()
    [{instance.type, :removed} | chained]
  end

  @doc """
  Expires a status only when `instance` is still the current stored generation.

  The compare-delete is atomic. On an actual removal, this runs the status's
  `on_expire` callback and removes its display when no newer same-type generation
  is active. Returns whether the captured entry was removed.
  """
  @spec expire_status_if_current(unit_type(), integer(), atom(), StatusEntry.t()) :: boolean()
  def expire_status_if_current(unit_type, unit_id, status_id, instance),
    do: expire_status_events_if_current(unit_type, unit_id, status_id, instance) != []

  @doc "Expires the current entry and returns every committed removal in its lifecycle chain."
  @spec expire_status_events_if_current(unit_type(), integer(), atom(), StatusEntry.t()) ::
          [status_event()]
  def expire_status_events_if_current(unit_type, unit_id, status_id, instance) do
    if StatusStorage.remove_status_if_current(unit_type, unit_id, status_id, instance) do
      events = expire_status_entry(unit_type, unit_id, status_id, instance)
      Notifications.notify_mob_status_write(unit_type, unit_id, status_id, :removed)
      events
    else
      []
    end
  end

  defp expire_status_entry(unit_type, unit_id, status_id, instance) do
    %{module: module} = Registry.get_definition(status_id)
    context = ContextBuilder.build_context(unit_type, unit_id, instance.source_id, instance)

    module.on_expire({unit_type, unit_id}, instance, context)
    chained = end_on_end_events(unit_type, unit_id, status_id)

    if is_nil(StatusStorage.get_status(unit_type, unit_id, status_id)) do
      StatusDisplay.on_removed(unit_type, unit_id, status_id, instance)
      recheck_touch_on_end(unit_type, unit_id, status_id)
    end

    [{status_id, :removed} | chained]
  end

  # An OnTouch status (Hiding, Cloaking, Chase Walk) ending on a player re-runs
  # the touch check of the cell it stands on now; the session skips it while a
  # warp is pending or once the player has moved on.
  defp recheck_touch_on_end(:player, unit_id, status_id) do
    with true <- status_id in Registry.statuses_with_flag(:on_touch),
         {:ok, {_module, %{map_name: map_name, x: x, y: y}, pid}} when is_pid(pid) <-
           UnitRegistry.get_unit(:player, unit_id),
         do: PlayerSession.recheck_touch(pid, {map_name, x, y})

    :ok
  end

  defp recheck_touch_on_end(_unit_type, _unit_id, _status_id), do: :ok

  @doc """
  Ends the entry of `generation` through the expiration lifecycle, retrying
  while the same generation is rewritten in place (a tick) between the read and
  the compare-delete. Returns whether it was removed.
  """
  @spec end_generation(unit_type(), integer(), atom(), pos_integer()) :: boolean()
  def end_generation(unit_type, unit_id, status_id, generation),
    do: end_generation_events(unit_type, unit_id, status_id, generation) != []

  @doc "`end_generation/4` returning the committed removals of the chain."
  @spec end_generation_events(unit_type(), integer(), atom(), pos_integer()) :: [status_event()]
  def end_generation_events(unit_type, unit_id, status_id, generation) do
    case StatusStorage.get_status(unit_type, unit_id, status_id) do
      %StatusEntry{generation: ^generation} = current ->
        case expire_status_events_if_current(unit_type, unit_id, status_id, current) do
          [] -> end_generation_events(unit_type, unit_id, status_id, generation)
          events -> events
        end

      _gone_or_newer ->
        []
    end
  end

  @doc """
  Ends a status's `end_on_end` statuses right after its own end logic, through
  `ender`. The ended status is already out of storage, so statuses naming each
  other end once each. Ending this way never ends an infinite Endure.
  """
  @spec end_on_end(unit_type(), integer(), atom(), (unit_type(), integer(), atom() -> term())) ::
          :ok
  def end_on_end(unit_type, unit_id, status_id, ender) do
    %{end_on_end: chained} = Registry.get_definition(status_id)

    chained
    |> Enum.reject(&infinite_endure?(StatusStorage.get_status(unit_type, unit_id, &1)))
    |> Enum.each(&ender.(unit_type, unit_id, &1))
  end

  @doc "Drops `instance` while current, with no end logic, and tells a monster's session."
  @spec remove_current_status_and_notify(unit_type(), integer(), atom(), StatusEntry.t()) ::
          :ok | nil
  def remove_current_status_and_notify(unit_type, unit_id, status_id, instance) do
    if StatusStorage.remove_status_if_current(unit_type, unit_id, status_id, instance),
      do: Notifications.notify_mob_status_write(unit_type, unit_id, status_id, :removed)
  end

  @doc """
  Removes statuses whose definitions set `remove_on_death: true` through
  the normal removal lifecycle, including infinite statuses with that flag,
  and those a surviving status's `ends_on_death?/1` still ends.

  Permanent definitions default to surviving death unless explicitly opted in.
  The selected owner-refresh policy is applied once after the filtered batch.
  """
  @spec remove_on_death(unit_type(), integer(), [remove_option()]) :: :ok
  def remove_on_death(unit_type, unit_id, opts \\ []) do
    unit_type
    |> StatusStorage.get_unit_statuses(unit_id)
    |> Enum.filter(&remove_on_death?/1)
    |> Enum.map(& &1.type)
    |> then(&remove_statuses(unit_type, unit_id, &1, opts))
  end

  defp remove_on_death?(%StatusEntry{type: type} = entry) do
    case Registry.get_definition(type) do
      %{remove_on_death: true} ->
        true

      %{module: module} ->
        function_exported?(module, :ends_on_death?, 1) and module.ends_on_death?(entry)

      _unknown ->
        false
    end
  end

  @doc """
  Ends, through the normal removal path, the statuses a unit loses when it
  leaves its map: on every warp of a player, monster or Homunculus, the same
  map included.

  Those are the statuses flagged `remove_on_map_change`, Cloaking (every
  warp ends it, whatever the unit), the Battle Chant caster lock and an
  infinite Provoke (`val4` 1, the Auto Berserk one). `sc_gospel` is only ever
  the caster's own chant; the Battle Chant slow on an enemy
  (`sc_gospel_slow`) survives the map change.
  """
  @spec remove_on_map_change(unit_type(), integer()) :: :ok
  def remove_on_map_change(unit_type, unit_id) do
    unit_type
    |> StatusStorage.get_unit_statuses(unit_id)
    |> Enum.filter(&remove_on_map_change?/1)
    |> Enum.map(& &1.type)
    |> then(&remove_statuses(unit_type, unit_id, &1, owner_refresh: :notify))
  end

  defp remove_on_map_change?(%StatusEntry{type: type})
       when type in [:sc_cloaking, :sc_gospel],
       do: true

  defp remove_on_map_change?(%StatusEntry{type: :sc_provoke, val4: val4}), do: val4 == 1

  defp remove_on_map_change?(%StatusEntry{type: type}) do
    match?(%{remove_on_map_change: true}, Registry.get_definition(type))
  end

  @doc """
  Ends every active status whose `require_weapon` list is non-empty and
  excludes `weapon_type` (the RequireWeapon flag).

  Consumed by the equipment-change and job-change paths; a status opts in via
  its definition's `:require_weapon` list, so callers stay ignorant of any
  specific status.
  """
  @spec enforce_weapon_requirements(unit_type(), integer(), atom()) :: :ok
  def enforce_weapon_requirements(unit_type, unit_id, weapon_type) do
    unit_type
    |> StatusStorage.get_unit_statuses(unit_id)
    |> Enum.filter(&weapon_requirement_broken?(&1, weapon_type))
    |> Enum.map(& &1.type)
    |> then(&remove_statuses(unit_type, unit_id, &1, owner_refresh: :notify))
  end

  defp weapon_requirement_broken?(%StatusEntry{type: type}, weapon_type) do
    case Registry.get_definition(type) do
      %{require_weapon: [_ | _] = allowed} -> weapon_type not in allowed
      _ -> false
    end
  end

  @doc """
  Removes every active status through the normal expiration lifecycle.

  Each status receives `on_expire` and display cleanup before the selected
  owner-refresh policy is applied once for the batch.

  Passing `except_permanent: true` skips any status whose definition sets
  `permanent: true` (e.g. `SC_RIDING`, `SC_PUSHCART`): these aren't a timed
  buff to expire, they mirror an out-of-band state (a mount/cart toggle, an
  option bit) that a caller like death's cleanup must leave standing so it
  keeps surviving through the respawn that follows.
  """
  @spec remove_all_statuses(unit_type(), integer(), [
          remove_option() | {:except_permanent, boolean()}
        ]) ::
          :ok
  def remove_all_statuses(unit_type, unit_id, opts \\ []) do
    {except_permanent?, remove_opts} = Keyword.pop(opts, :except_permanent, false)

    unit_type
    |> StatusStorage.get_unit_statuses(unit_id)
    |> Enum.reject(&(except_permanent? and permanent?(&1)))
    |> Enum.map(& &1.type)
    |> then(&remove_statuses(unit_type, unit_id, &1, remove_opts))
  end

  defp permanent?(%StatusEntry{type: type}) do
    match?(%{permanent: true}, Registry.get_definition(type))
  end

  @doc """
  Ends every status of a unit leaving the world (logout, despawn, a dead
  monster's removal, a homunculus put away) through its end logic, then drops
  whatever is left with the unit's status counters.

  Each status is taken out of storage before its `on_expire` runs. A status
  deciding how it ends (`on_end_request/3`) still runs its outcome, and is
  dropped even when it asks to stay. An infinite Endure never runs its end
  logic. An engine-only status has no end case of its own: it goes with the
  unit after the others ended. The holder may already be gone from the
  registry; its end logic then sees empty target stats. No owner refresh is
  published: the unit is leaving.
  """
  @spec end_removed_unit_statuses(unit_type(), integer()) :: :ok
  def end_removed_unit_statuses(unit_type, unit_id) do
    unit_type
    |> StatusStorage.get_unit_statuses(unit_id)
    |> Enum.each(&end_on_removal(unit_type, unit_id, &1.type))

    StatusStorage.clear_unit_statuses(unit_type, unit_id)
  end

  @doc """
  Ends, through their end logic and with no owner refresh, the unit's statuses
  a logout does not save: those whose definition sets `no_save`, those setting
  `no_save_infinite` while infinite (`val4` set or no expiry), and those leaving
  the map ends (see `remove_on_map_change/2`), a player's Cloaking excepted. An
  infinite Endure refuses to end this way and stays. A logout runs it before
  saving the rest.
  """
  @spec end_unsaved_statuses(unit_type(), integer()) :: :ok
  def end_unsaved_statuses(unit_type, unit_id) do
    unit_type
    |> StatusStorage.get_unit_statuses(unit_id)
    |> Enum.filter(&(unsaved?(&1) or ends_with_map?(unit_type, &1)))
    |> Enum.reject(&infinite_endure?/1)
    |> Enum.map(& &1.type)
    |> then(&remove_statuses(unit_type, unit_id, &1, owner_refresh: :defer))
  end

  # Leaving the map at logout ends the map-change statuses before the save; a
  # player's Cloaking ends only on a warp.
  defp ends_with_map?(:player, %StatusEntry{type: :sc_cloaking}), do: false
  defp ends_with_map?(_unit_type, entry), do: remove_on_map_change?(entry)

  defp unsaved?(%StatusEntry{type: type} = entry) do
    case Registry.get_definition(type) do
      %{no_save: true} -> true
      %{no_save_infinite: true} -> entry.val4 > 0 or is_nil(entry.expires_at)
      _ -> false
    end
  end

  defp infinite_endure?(%StatusEntry{type: :sc_endure, val4: val4}), do: val4 != 0
  defp infinite_endure?(_entry), do: false

  defp end_on_removal(unit_type, unit_id, status_id) do
    case {Registry.get_definition(status_id),
          StatusStorage.get_status(unit_type, unit_id, status_id)} do
      {_definition, nil} ->
        :ok

      {nil, _instance} ->
        :ok

      {%{engine_only: true}, _instance} ->
        :ok

      {_definition, %StatusEntry{type: :sc_endure, val4: val4} = instance} when val4 != 0 ->
        remove_current_status_and_notify(unit_type, unit_id, status_id, instance)

      {%{module: module}, instance} ->
        context = end_context(unit_type, unit_id, instance)
        end_removed(module, unit_type, unit_id, instance, context)
    end

    :ok
  end

  defp end_removed(module, unit_type, unit_id, %StatusEntry{type: status_id} = instance, context) do
    after_end =
      if MapSet.member?(Registry.statuses_implementing(:on_end_request), status_id) do
        case module.on_end_request({unit_type, unit_id}, instance, context) do
          {:keep, _kept, after_end} -> {:dropped, after_end}
          {:end, after_end} -> {:ended, after_end}
        end
      else
        {:ended, fn -> :ok end}
      end

    if StatusStorage.remove_status_if_current(unit_type, unit_id, status_id, instance) do
      finish_removal(after_end, module, unit_type, unit_id, instance, context)
    end
  end

  defp finish_removal({:dropped, after_end}, _module, _unit_type, _unit_id, _instance, _context),
    do: after_end.()

  defp finish_removal({:ended, after_end}, module, unit_type, unit_id, instance, context) do
    module.on_expire({unit_type, unit_id}, instance, context)
    end_on_end(unit_type, unit_id, instance.type, &end_on_removal/3)
    StatusDisplay.on_removed(unit_type, unit_id, instance.type, instance)
    Notifications.notify_unit_status_removed(unit_type, unit_id, instance.type)
    recheck_touch_on_end(unit_type, unit_id, instance.type)
    after_end.()
  end

  # Ending a status never needs its holder in the world: a holder already gone
  # (a removal's chained ends, an orphan) shows its end logic empty stats.
  defp end_context(unit_type, unit_id, instance) do
    target =
      if UnitRegistry.unit_exists?(unit_type, unit_id),
        do: ContextBuilder.get_unit_stats(unit_type, unit_id),
        else: %{}

    ContextBuilder.build_context(unit_type, unit_id, instance.source_id, instance, target)
  end
end
