defmodule Aesir.ZoneServer.Mmo.Skill.Unit.FieldSupport do
  @moduledoc """
  The status a ground field grants to the units standing in it, driven by the
  field's unit events and run inside `Skill.Unit.Manager`.

  A field describes its status through the handler's `field_support/1`
  (`status_type`, `params`, `target?`, optional `linger_ms` and `grants?`).
  `target?/2` is the unit's target check: the handler's predicate on a unit
  that is not an invincible player. The events:

    * `onplace/2` - a target entering a cell, standing on a cell being placed,
      or standing where a song cell arrives: the status starts only when the
      unit lacks it, for the group's whole lifetime (a solo song or dance adds
      one unit pass so the field is gone before the status). A dissonant song
      cell never grants; it ends the song as a step off would.
    * `onleft/2` - a unit that left the field entirely: Quagmire lets monsters
      keep it; a solo song or dance restarts a player's status once as the
      skill's linger (`val4` marks it, re-entry never refreshes it) and ends it
      on anyone else; an ensemble ends a performer's own performing lock and,
      Lullaby aside, the status; every other field ends the status.
    * `leave/3` - a target leaving the field for good (its removal from play,
      a cell vanishing under it): the handler's `on_out`, then `onleft`.
    * `out/3` - `leave/3` for every target standing on vanishing cells
      (deletion, a cell lost, a song moving on).

  The linger restarts the held entry only while it is still the one that was
  read, so a status ended or dispelled meanwhile stays ended.
  """

  require Logger

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Performance.Overlap
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Player.Invincibility
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @type mover :: {atom(), integer()}
  @type spec :: %{
          optional(:linger_ms) => non_neg_integer(),
          optional(:grants?) => (mover() -> boolean()),
          status_type: atom(),
          params: keyword() | map() | (atom(), integer() -> keyword() | map()),
          target?: (mover() -> boolean())
        }

  @lullaby 306

  @doc "The field's status description, when its handler grants one."
  @spec spec(Group.t()) :: {:ok, spec()} | :error
  def spec(%Group{} = group) do
    with {:ok, module} <- handler_for(group),
         true <- function_exported?(module, :field_support, 1) do
      case module.field_support(group) do
        %{status_type: nil} -> :error
        spec -> {:ok, %{status_type: _, params: _, target?: _} = spec}
      end
    else
      _ -> :error
    end
  end

  @doc """
  Whether the field's unit events reach `mover` (the unit's target check): never
  an invincible player, and only the handler's targets when it grants a status.
  """
  @spec target?(Group.t(), mover()) :: boolean()
  def target?(%Group{} = group, mover) do
    not Invincibility.active?(mover) and
      case spec(group) do
        {:ok, spec} -> spec.target?.(mover)
        :error -> true
      end
  end

  @doc """
  Places a target on one of the field's cells. Returns `:placed` when the
  event ran to its end (the status started or was already held) and
  `:skipped` when the cell refused it (dissonance, a Basilica cell, hiding).
  """
  @spec onplace(Group.t(), mover(), [non_neg_integer()]) :: :placed | :skipped
  def onplace(%Group{} = group, {unit_type, unit_id} = mover, except \\ []) do
    case spec(group) do
      {:ok, spec} ->
        cond do
          not living?(mover) ->
            :skipped

          dissonant_cell?(group, mover, except) ->
            group |> songs_at(mover) |> Enum.each(&onleft(&1, mover))
            :skipped

          not Targeting.placement_reaches?(group.skill_id, mover) or not grants?(spec, mover) ->
            :skipped

          StatusStorage.has_status?(unit_type, unit_id, spec.status_type) ->
            :placed

          true ->
            start(group, spec, mover)
            :placed
        end

      :error ->
        :placed
    end
  end

  @doc "A unit that left the field entirely."
  @spec onleft(Group.t(), mover()) :: :ok
  def onleft(%Group{} = group, {unit_type, unit_id} = mover) do
    case spec(group) do
      {:ok, spec} -> onleft(kind(group), group, spec, mover, unit_type, unit_id)
      :error -> if ensemble?(group), do: end_own_dancing(group, mover)
    end

    :ok
  end

  defp onleft(:quagmire, _group, _spec, _mover, :mob, _unit_id), do: :ok

  defp onleft(:solo, _group, spec, _mover, :player, unit_id),
    do: linger(unit_id, spec.status_type, Map.fetch!(spec, :linger_ms))

  defp onleft(:ensemble, group, spec, mover, unit_type, unit_id) do
    end_own_dancing(group, mover)

    if group.skill_id != @lullaby,
      do: Interpreter.remove_status(unit_type, unit_id, spec.status_type)
  end

  defp onleft(_kind, _group, spec, _mover, unit_type, unit_id),
    do: Interpreter.remove_status(unit_type, unit_id, spec.status_type)

  # Restarts a held, not yet lingering entry at the linger; a lost replace
  # reads again, so an entry ended meanwhile is left ended.
  defp linger(unit_id, status_type, linger_ms) do
    case StatusStorage.get_status(:player, unit_id, status_type) do
      %StatusEntry{val4: val4} = held when val4 in [nil, 0] ->
        lingering = %{held | val4: 1, expires_at: System.monotonic_time(:millisecond) + linger_ms}

        if Interpreter.restart_status_if_current(:player, unit_id, status_type, held, lingering),
          do: :ok,
          else: linger(unit_id, status_type, linger_ms)

      _lingering_or_absent ->
        :ok
    end
  end

  @doc """
  A target leaving the field for good: `on_out` (the handler's callback, run
  by the caller) and then `onleft`.
  """
  @spec leave(Group.t(), mover(), (mover() -> :ok)) :: :ok
  def leave(%Group{} = group, mover, on_out) do
    on_out.(mover)
    onleft(group, mover)
  end

  @doc "Runs `leave/3` for every target standing on `cells` as those cells vanish."
  @spec out(Group.t(), [Group.cell()], (mover() -> :ok)) :: :ok
  def out(%Group{} = group, cells, on_out) do
    group
    |> occupants(cells)
    |> Enum.each(fn mover -> if target?(group, mover), do: leave(group, mover, on_out) end)
  end

  @doc "Places every target standing on `cells` (a placement or a song's new cells)."
  @spec place(Group.t(), [Group.cell()], [non_neg_integer()]) :: :ok
  def place(%Group{} = group, cells, except \\ []) do
    group
    |> occupants(cells)
    |> Enum.each(fn mover -> if target?(group, mover), do: onplace(group, mover, except) end)
  end

  @doc """
  A song or dance stopped covering `cells`: an occupant of a song cell that is
  no longer dissonant is placed on it again.
  """
  @spec overlap_removed(Group.t(), [Group.cell()]) :: :ok
  def overlap_removed(%Group{state: %{performance: %{kind: kind}}} = group, cells)
      when kind in [:song, :dance] do
    Enum.each(cells, fn {x, y} = cell ->
      group.map_name
      |> Storage.get_groups_at_cell(x, y)
      |> Enum.filter(&match?(%{performance: %{kind: ^kind}}, &1.state))
      |> Enum.reject(
        &(&1.group_id == group.group_id or Overlap.dissonant?(&1, cell, [group.group_id]))
      )
      |> Enum.each(&place(&1, [cell], [group.group_id]))
    end)
  end

  def overlap_removed(%Group{}, _cells), do: :ok

  @doc "Whether placing `mover` on one of the field's cells would run to its end."
  @spec places?(Group.t(), mover()) :: boolean()
  def places?(%Group{} = group, mover) do
    case spec(group) do
      {:ok, spec} ->
        not dissonant_cell?(group, mover, []) and
          Targeting.placement_reaches?(group.skill_id, mover) and grants?(spec, mover)

      :error ->
        false
    end
  end

  @doc "The combat units standing on any of `cells`."
  @spec occupants(Group.t(), [Group.cell()]) :: [mover()]
  def occupants(%Group{map_name: map_name}, cells) do
    cells
    |> Enum.flat_map(fn {x, y} -> SpatialIndex.get_all_units_in_range(map_name, x, y, 0) end)
    |> Enum.uniq()
    |> Enum.filter(&(elem(&1, 0) in [:player, :mob, :homunculus]))
  end

  defp start(group, spec, {unit_type, unit_id} = mover) do
    params =
      spec
      |> params_for(mover)
      |> normalize()
      |> Keyword.put(:duration, group.expires_at - group.created_at + extra_ms(group))

    case Interpreter.apply_status(unit_type, unit_id, spec.status_type, params) do
      :ok ->
        :ok

      {:error, _reason} = error ->
        Logger.error(
          "Field status #{spec.status_type} failed for #{unit_type}:#{unit_id} " <>
            "skill=#{group.skill_name}: #{inspect(error)}"
        )
    end
  end

  defp extra_ms(group), do: if(kind(group) == :solo, do: Manager.tick_interval(), else: 0)

  defp end_own_dancing(%Group{skill_id: skill_id}, {unit_type, unit_id}) do
    case StatusStorage.get_status(unit_type, unit_id, :sc_dancing) do
      %StatusEntry{val1: ^skill_id} ->
        Interpreter.remove_status(unit_type, unit_id, :sc_dancing, owner_refresh: :notify)

      _other ->
        :ok
    end
  end

  defp dissonant_cell?(group, {unit_type, unit_id}, except) do
    case SpatialIndex.get_unit_position(unit_type, unit_id) do
      {:ok, {x, y, map_name}} when map_name == group.map_name ->
        Overlap.dissonant?(group, {x, y}, except)

      _ ->
        false
    end
  end

  defp songs_at(%Group{state: %{performance: %{kind: kind}}} = group, {unit_type, unit_id}) do
    case SpatialIndex.get_unit_position(unit_type, unit_id) do
      {:ok, {x, y, map_name}} when map_name == group.map_name ->
        map_name
        |> Storage.get_groups_at_cell(x, y)
        |> Enum.filter(&match?(%{performance: %{kind: ^kind}}, &1.state))

      _ ->
        [group]
    end
  end

  defp kind(%Group{skill_name: :wz_quagmire}), do: :quagmire
  defp kind(%Group{state: %{performance: %{kind: :ensemble}}}), do: :ensemble
  defp kind(%Group{state: %{performance: %{kind: kind}}}) when kind in [:song, :dance], do: :solo
  defp kind(%Group{}), do: :field

  defp ensemble?(group), do: kind(group) == :ensemble

  defp grants?(%{grants?: grants?}, mover), do: grants?.(mover)
  defp grants?(_spec, _mover), do: true

  defp params_for(%{params: params}, {unit_type, unit_id}) when is_function(params, 2),
    do: params.(unit_type, unit_id)

  defp params_for(%{params: params}, _mover), do: params

  defp normalize(params) when is_list(params), do: params
  defp normalize(params) when is_map(params), do: Map.to_list(params)

  defp living?({unit_type, unit_id}) do
    case UnitRegistry.get_unit(unit_type, unit_id) do
      {:ok, {_module, state, _pid}} -> Unit.living?(state)
      _ -> false
    end
  end

  defp handler_for(%Group{handler: handler}) when not is_nil(handler), do: {:ok, handler}
  defp handler_for(%Group{skill_name: skill_name}), do: Catalog.ground_module_for(skill_name)
end
