defmodule Aesir.ZoneServer.Mmo.Skill.Unit.Traps do
  @moduledoc """
  The Hunter-trap operations the manager serializes: spending a trap through
  Claymore, springing, reclaiming and revealing one, and what an armed trap
  does when its own time runs out.

  Every function runs inside `Skill.Unit.Manager`.
  """

  require Logger

  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Cells
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.GroupLifecycle
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Handler
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Publisher
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.Skill.Unit.TrapCombat
  alias Aesir.ZoneServer.Mmo.Skill.Unit.TrapState
  alias Aesir.ZoneServer.Mmo.Skill.Unit.TrapTransition

  @type owner :: {atom(), integer()}
  @type unit_available :: (atom(), integer(), String.t() -> boolean())

  @doc "Whether a group acts on movers: an armed trap or any non-trap group."
  @spec triggerable?(Group.t()) :: boolean()
  def triggerable?(%Group{} = group) do
    case TrapTransition.from_group(group) do
      {:ok, %TrapState{phase: :armed}} ->
        true

      {:ok, %TrapState{}} ->
        false

      {:error, :unsupported_trap} ->
        true

      {:error, :invalid_trap_state} ->
        Logger.error("Skill.Unit.Manager rejected invalid trap state group_id=#{group.group_id}")
        false
    end
  end

  @doc "Moves an exhausted armed trap to its used phase for the sprung lifetime."
  @spec mark_used(Group.t(), integer()) :: {:ok, Group.t()} | {:error, term()}
  def mark_used(%Group{} = group, now) do
    used = TrapTransition.transition(group, :used, now + TrapTransition.sprung_lifetime())

    case TrapTransition.persist(group, used) do
      :ok -> {:ok, used}
      {:error, _reason} = error -> error
    end
  end

  @doc """
  Spends every Claymore-spendable armed trap in the square area around a
  point. Returns the groups it changed, as stored.
  """
  @spec spend_in_area(String.t(), integer(), integer(), non_neg_integer(), integer()) ::
          [Group.t()]
  def spend_in_area(map_name, x, y, radius, now) do
    map_name
    |> groups_in_area(x, y, radius)
    |> Enum.flat_map(&spend(&1, now))
  end

  defp spend(%Group{} = group, now) do
    case TrapTransition.from_group(group) do
      {:ok, %TrapState{phase: :armed, claymore_spendable?: true}} ->
        used = TrapTransition.transition(group, :used, sprung_expiry(group, now))

        case TrapTransition.persist(group, used) do
          :ok ->
            [used]

          {:error, reason} ->
            Logger.error(
              "Skill.Unit.Manager spend_traps failed group_id=#{group.group_id}: #{inspect(reason)}"
            )

            []
        end

      _ineligible ->
        []
    end
  end

  # A sprung trap lingers as a used trap, never past its own lifetime.
  defp sprung_expiry(%Group{expires_at: expires_at}, now) when is_integer(expires_at),
    do: min(now + TrapTransition.sprung_lifetime(), expires_at)

  defp sprung_expiry(%Group{}, now), do: now + TrapTransition.sprung_lifetime()

  @doc """
  Reaps a group whose expiry passed. An armed trap that becomes used on
  expiry transitions instead of going; an armed or spent trap returns its
  item to a present owner before going.
  """
  @spec expire_naturally(Group.t(), integer(), unit_available()) :: :ok
  def expire_naturally(%Group{} = group, now, unit_available?) do
    case TrapTransition.from_group(group) do
      {:ok, %TrapState{phase: :armed, natural_expiry: :become_used}} ->
        used = TrapTransition.transition(group, :used, now + TrapTransition.sprung_lifetime())

        :ok = log_natural_expiry_callback_failure(run_natural_expiry_callback(group), group)

        case TrapTransition.persist(group, used) do
          :ok ->
            :ok

          {:error, reason} ->
            Logger.error(
              "Skill.Unit.Manager natural trap transition failed group_id=#{group.group_id}: #{inspect(reason)}"
            )

            GroupLifecycle.cleanup(group)
        end

      {:ok, %TrapState{phase: phase} = trap} when phase in [:armed, :spent] ->
        maybe_drop_expired_trap(group, trap, unit_available?)
        GroupLifecycle.cleanup(group)

      {:ok, %TrapState{}} ->
        GroupLifecycle.cleanup(group)

      {:error, :unsupported_trap} ->
        GroupLifecycle.cleanup(group)

      {:error, :invalid_trap_state} ->
        Logger.error("Skill.Unit.Manager expiring invalid trap state group_id=#{group.group_id}")
        GroupLifecycle.cleanup(group)
    end
  end

  defp run_natural_expiry_callback(%Group{} = group) do
    case Handler.for_group(group) do
      {:ok, module} -> invoke_natural_expiry_callback(module, group)
      :error -> :ok
    end
  end

  defp log_natural_expiry_callback_failure(:ok, _group), do: :ok

  defp log_natural_expiry_callback_failure({:error, reason}, group) do
    Handler.log_error(group, :on_natural_expiry, reason)
  end

  defp invoke_natural_expiry_callback(module, group) do
    if function_exported?(module, :on_natural_expiry, 1) do
      case Handler.invoke(module, :on_natural_expiry, [group]) do
        {:ok, :ok} -> :ok
        {:ok, {:error, reason}} -> {:error, {:returned_error, reason}}
        {:ok, result} -> {:error, {:invalid_natural_expiry_return, result}}
        {:error, reason} -> {:error, {:natural_expiry_callback_failed, reason}}
      end
    else
      :ok
    end
  end

  defp maybe_drop_expired_trap(
         %Group{caster_type: :player, caster_id: caster_id} = group,
         %TrapState{return_item_on_expiry?: true, reclaim_item_id: item_id},
         unit_available?
       )
       when is_integer(item_id) and item_id > 0 do
    if unit_available?.(:player, caster_id, group.map_name) and TrapCombat.intact?(group) do
      {x, y} = group.center
      Coordinator.drop_items(group.map_name, [{item_id, 1, x, y, true}], x, y)
    end
  end

  defp maybe_drop_expired_trap(_group, _trap, _unit_available?), do: :ok

  @doc "Springs the lowest-id armed trap at a cell, making it public for the sprung lifetime."
  @spec spring(String.t(), integer(), integer(), integer()) ::
          {:ok, %{group_id: non_neg_integer(), expires_at: integer()}} | {:error, atom()}
  def spring(map_name, x, y, now) do
    groups = map_name |> Storage.get_groups_at_cell(x, y) |> Enum.sort_by(& &1.group_id)

    case select(groups, &spring_eligibility/1) do
      {:ok, %Group{} = group} ->
        expires_at = now + TrapTransition.sprung_lifetime()

        sprung =
          group |> TrapTransition.transition(:sprung, expires_at) |> Map.put(:visibility, :public)

        case TrapTransition.persist(group, sprung) do
          :ok -> {:ok, %{group_id: group.group_id, expires_at: expires_at}}
          {:error, _reason} = error -> error
        end

      {:error, _reason} = error ->
        error
    end
  end

  @doc """
  Removes the lowest-id trap at a cell that `owner` may reclaim, returning its
  item only while it is still armed.
  """
  @spec reclaim(owner(), String.t(), integer(), integer()) ::
          {:ok, %{group_id: non_neg_integer(), item_id: pos_integer() | nil}} | {:error, atom()}
  def reclaim(owner, map_name, x, y) do
    groups = map_name |> Storage.get_groups_at_cell(x, y) |> Enum.sort_by(& &1.group_id)

    case select(groups, &reclaim_eligibility(&1, owner)) do
      {:ok, %Group{state: %{trap: %TrapState{phase: :armed, reclaim_item_id: item_id}}} = group} ->
        GroupLifecycle.cleanup_with_reason(group, :SKILL_UNIT_DESPAWN_REASON_CANCELED)
        {:ok, %{group_id: group.group_id, item_id: item_id}}

      {:ok, %Group{} = group} ->
        GroupLifecycle.cleanup_with_reason(group, :SKILL_UNIT_DESPAWN_REASON_CANCELED)
        {:ok, %{group_id: group.group_id, item_id: nil}}

      {:error, _reason} = error ->
        error
    end
  end

  @doc """
  Makes every hidden armed trap in the square area public, all or none, and
  announces each to the players who did not track it yet.
  """
  @spec reveal(String.t(), integer(), integer(), non_neg_integer()) ::
          {:ok, [non_neg_integer()]} | {:error, atom()}
  def reveal(map_name, x, y, range) do
    with {:ok, groups} <- hidden_supported_traps(map_name, x, y, range) do
      groups
      |> Enum.reduce_while({:ok, []}, &reveal_step/2)
      |> case do
        {:ok, transitions} -> {:ok, publish_revealed(transitions)}
        error -> error
      end
    end
  end

  defp publish_revealed(transitions) do
    transitions = Enum.reverse(transitions)
    Enum.each(transitions, fn {_original, visible} -> Publisher.spawn_untracked(visible) end)
    Enum.map(transitions, fn {_original, visible} -> visible.group_id end)
  end

  defp reveal_step(group, {:ok, transitions}) do
    case reveal_one(group) do
      {:ok, visible} ->
        {:cont, {:ok, [{group, visible} | transitions]}}

      {:error, _reason} = error ->
        rollback_revealed(transitions)
        {:halt, error}
    end
  end

  defp rollback_revealed(transitions) do
    Enum.each(transitions, fn {original, _visible} ->
      if Group.materialized?(original) do
        Storage.update(original)
      else
        TrapTransition.rollback_materialization(original)
      end
    end)
  end

  defp hidden_supported_traps(map_name, x, y, range) do
    map_name
    |> groups_in_area(x, y, range)
    |> Enum.reduce_while({:ok, []}, fn group, {:ok, groups} = result ->
      if Group.public?(group),
        do: {:cont, result},
        else: classify_hidden(group, groups)
    end)
    |> case do
      {:ok, groups} -> {:ok, Enum.reverse(groups)}
      error -> error
    end
  end

  defp classify_hidden(group, groups) do
    case TrapTransition.from_group(group) do
      {:ok, %TrapState{phase: :armed}} -> {:cont, {:ok, [group | groups]}}
      {:ok, %TrapState{}} -> {:cont, {:ok, groups}}
      {:error, :unsupported_trap} -> {:cont, {:ok, groups}}
      {:error, :invalid_trap_state} = error -> {:halt, error}
    end
  end

  defp groups_in_area(map_name, x, y, range) do
    groups =
      for cell_x <- (x - range)..(x + range),
          cell_y <- (y - range)..(y + range),
          group <- Storage.get_groups_at_cell(map_name, cell_x, cell_y),
          uniq: true,
          do: group

    Enum.sort_by(groups, & &1.group_id)
  end

  defp reveal_one(%Group{} = group) do
    visible = %{group | visibility: :public}

    case Storage.get_cells_by_group(group.group_id) do
      [] ->
        :ok = Storage.update(visible)

        case Cells.materialize_visible(visible, []) do
          {:ok, _cells} ->
            {:ok, visible}

          {:error, _reason} = error ->
            TrapTransition.rollback_materialization(group)
            error
        end

      [_cell | _cells] ->
        :ok = Storage.update(visible)
        {:ok, visible}
    end
  end

  defp select([], _eligibility), do: {:error, :not_found}

  defp select(groups, eligibility) do
    results = Enum.map(groups, &{&1, eligibility.(&1)})

    case Enum.find(results, fn {_group, result} -> result == :eligible end) do
      {group, :eligible} ->
        {:ok, group}

      nil ->
        {_group, {:error, reason}} =
          Enum.find(results, fn {_group, result} -> result != {:error, :unsupported_trap} end) ||
            hd(results)

        {:error, reason}
    end
  end

  defp spring_eligibility(%Group{} = group) do
    case TrapTransition.from_group(group) do
      {:ok, %TrapState{phase: :armed}} -> :eligible
      {:ok, %TrapState{}} -> {:error, :already_spent}
      {:error, _reason} = error -> error
    end
  end

  defp reclaim_eligibility(%Group{} = group, owner) do
    case TrapTransition.from_group(group) do
      {:ok, %TrapState{}} ->
        # The reference allows the owner's traps everywhere and any trap on a Vs
        # map; a trap past its armed phase is still removed, just without
        # returning an item.
        if reclaim_allowed?(group, owner), do: :eligible, else: {:error, :not_owner}

      {:error, _reason} = error ->
        error
    end
  end

  defp reclaim_allowed?(%Group{} = group, owner) do
    {group.caster_type, group.caster_id} == owner or MapFlags.versus?(group.map_name)
  end
end
