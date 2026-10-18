defmodule Aesir.ZoneServer.Unit.Mob.Looting do
  @moduledoc """
  A looter's floor-item search, walk and pickup. The oldest reachable item in
  a 12-cell square is chosen once and kept until it disappears or is taken.
  Ten stacks are retained, replacing the oldest stack when full. Player pickup
  protection does not restrict monsters.
  """

  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Map.LineOfSight
  alias Aesir.ZoneServer.Mmo.ItemDrop.DropCalculator
  alias Aesir.ZoneServer.Mmo.ItemDrop.GroundItemStore
  alias Aesir.ZoneServer.Mmo.ItemDrop.LootOwnership
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Unit.Mob.AIStateMachine
  alias Aesir.ZoneServer.Unit.Mob.Handlers.MovementHandler
  alias Aesir.ZoneServer.Unit.Mob.MobState

  @loot_range 12
  @capacity 10

  @doc "Retains a live floor target, or searches when free to move and act without an enemy."
  @spec search(MobState.t(), boolean(), integer()) :: MobState.t()
  def search(%MobState{loot_target_id: id} = state, can_move, now) when id != nil do
    case GroundItemStore.get(state.map_name, id) do
      {:ok, _item} -> state
      {:error, :gone} -> search(AIStateMachine.unlock_target(state, now), can_move, now)
    end
  end

  def search(%MobState{} = state, can_move, now) do
    if can_move and MobState.mode?(state, :looter) and state.target_ref == nil and
         (state.act_delay_until == nil or now > state.act_delay_until) do
      item =
        state.map_name
        |> GroundItemStore.query_in_range(state.x, state.y, @loot_range)
        |> Enum.sort_by(& &1.id)
        |> Enum.find(fn item ->
          LineOfSight.clear?(state.map_name, {state.x, state.y}, {item.x, item.y}) and
            AIStateMachine.reachable_cell?(state, {item.x, item.y}, @loot_range)
        end)

      %{state | loot_target_id: item && item.id}
    else
      state
    end
  end

  @doc "Validates a retained floor target; a walking mob keeps an extant invalid target until it stops."
  @spec validate_target(MobState.t(), integer()) :: {:cont | :halt, MobState.t()}
  def validate_target(state, now) do
    case GroundItemStore.get(state.map_name, state.loot_target_id) do
      {:error, :gone} ->
        {:cont, AIStateMachine.unlock_target(state, now)}

      {:ok, _item} ->
        cond do
          valid_floor_target?(state) -> {:cont, state}
          state.movement_state == :moving -> {:halt, state}
          true -> {:cont, AIStateMachine.unlock_target(state, now)}
        end
    end
  end

  defp valid_floor_target?(state) do
    modes = MobState.modes(state)

    state.attack_timer_at != nil or
      (:can_attack in modes and :looter in modes and
         Interpreter.can_attack?(:mob, state.instance_id))
  end

  @doc "Walks onto the floor target, then claims one stack when not busy attacking."
  @spec step(MobState.t(), boolean(), integer()) :: MobState.t()
  def step(%MobState{} = state, can_move, now) do
    case GroundItemStore.get(state.map_name, state.loot_target_id) do
      {:ok, item} -> approach(state, item, can_move, now)
      {:error, :gone} -> AIStateMachine.unlock_target(state, now)
    end
  end

  @doc "Returns retained loot to the floor on death, independently of normal drop suppression."
  @spec drop_on_death(MobState.t()) :: :ok
  def drop_on_death(%MobState{looted_items: []}), do: :ok

  def drop_on_death(%MobState{} = state) do
    drops = DropCalculator.scatter_loot(state.looted_items, state.map_name, state.x, state.y)
    ownership = LootOwnership.determine_typed(state)

    Coordinator.drop_items(state.map_name, drops, state.x, state.y,
      ownership: {ownership, MobState.is_boss?(state)}
    )
  end

  defp approach(%MobState{x: x, y: y} = state, %{x: x, y: y}, _can_move, now),
    do: pickup(state, now)

  defp approach(state, item, can_move, now) do
    cond do
      state.movement_state == :moving and state.walk_target == nil and
          List.last(state.walk_path) == {item.x, item.y} ->
        state

      not MobState.mode?(state, :can_move) ->
        AIStateMachine.unlock_target(state, now)

      not can_move ->
        state

      true ->
        {:noreply, moving} =
          MovementHandler.handle_move_to(
            MobState.set_state(%{state | chase_target: {:item, item.id}}, :loot),
            item.x,
            item.y,
            chase: true
          )

        if moving.movement_state == :moving,
          do: moving,
          else: AIStateMachine.unlock_target(moving, now)
    end
  end

  defp pickup(%MobState{attack_timer_at: timer} = state, _now) when timer != nil, do: state

  defp pickup(state, now) do
    state =
      case Coordinator.claim_loot_item(state.map_name, state.loot_target_id) do
        {:ok, item} ->
          items = Enum.take(state.looted_items, -(@capacity - 1)) ++ [item]
          %{state | looted_items: items}

        {:error, :gone} ->
          state
      end

    AIStateMachine.unlock_target(state, now)
  end
end
