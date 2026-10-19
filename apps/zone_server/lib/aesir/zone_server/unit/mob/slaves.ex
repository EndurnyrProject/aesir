defmodule Aesir.ZoneServer.Unit.Mob.Slaves do
  @moduledoc """
  Slave monster AI and master-owned lifecycle dispatch.

  Each slave mutates itself in its own session. Masters only read snapshots
  and send asynchronous death or warp requests to their linked slaves.
  """

  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Mmo.Combat.Relationship
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.Woe.Rules
  alias Aesir.ZoneServer.Pathfinding
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.HitStop
  alias Aesir.ZoneServer.Unit.Mob.AIStateMachine
  alias Aesir.ZoneServer.Unit.Mob.Handlers.CombatHandler
  alias Aesir.ZoneServer.Unit.Mob.Handlers.MovementHandler
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Movement
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @follow_distance 2

  @doc "Runs slave death, follow and target linking, halting a think when the step handles it."
  @spec process(MobState.t(), integer()) :: {:cont | :halt, MobState.t()}
  def process(%MobState{master_id: nil} = state, _now), do: {:cont, state}

  def process(state, now) do
    case UnitRegistry.get_unit(:mob, state.master_id) do
      {:ok, {_module, %MobState{} = master, _pid}} ->
        process_master(state, master, now)

      _missing ->
        kill(state)
    end
  end

  defp process_master(state, master, now) do
    cond do
      not Unit.living?(master) ->
        kill(state)

      not match?({:ok, _}, SpatialIndex.get_unit_position(:mob, master.instance_id)) ->
        {:cont, state}

      not MobState.mode?(state, :can_move) and master.map_name != state.map_name and
          Rules.ground?(state.map_name) ->
        kill(state)

      true ->
        case follow(state, master) do
          {:cont, state} -> inherit_target(state, master, now)
          halted -> halted
        end
    end
  end

  @doc "Recalls living slaves already on the master's map to cells within two cells of it."
  @spec recall(MobState.t()) :: :ok
  def recall(master) do
    Enum.each(linked(master), fn {_slave, pid} ->
      {x, y} =
        Cell.random_traversable_near(master.map_name, {master.x, master.y}, @follow_distance)

      if is_pid(pid), do: MobSession.warp(pid, master.map_name, x, y)
    end)

    :ok
  end

  @doc "Dispatches a summoning master's death to its living same-map slaves."
  @spec master_died(MobState.t()) :: :ok
  def master_died(%MobState{can_summon: false}), do: :ok

  def master_died(master) do
    Enum.each(linked(master), fn {_slave, pid} ->
      if is_pid(pid), do: GenServer.cast(pid, {:combat, {:master_dead, master.instance_id}})
    end)

    :ok
  end

  @doc "Returns living linked monsters in the master's map block order."
  @spec linked(MobState.t()) :: [{MobState.t(), pid() | nil}]
  def linked(master) do
    case MapCache.get(master.map_name) do
      {:ok, map} ->
        master.map_name
        |> SpatialIndex.units_in_area(0, 0, map.xs - 1, map.ys - 1)
        |> Enum.flat_map(&linked_ref(master.instance_id, &1))

      _unmapped ->
        []
    end
  end

  defp linked_ref(master_id, {:mob, id}) do
    case UnitRegistry.get_unit(:mob, id) do
      {:ok, {_, %MobState{master_id: ^master_id} = slave, pid}} ->
        if Unit.living?(slave), do: [{slave, pid}], else: []

      _other ->
        []
    end
  end

  defp linked_ref(_master_id, _ref), do: []

  defp kill(state) do
    {:noreply, dead} = CombatHandler.handle_master_death(state.master_id, state)
    {:halt, dead}
  end

  defp follow(state, master) do
    distance = Geometry.chebyshev_distance(state.x, state.y, master.x, master.y)

    if state.target_ref == nil and state.loot_target_id == nil and
         (distance > @follow_distance or distance == 0) and
         AIStateMachine.can_move?(state, System.monotonic_time(:millisecond)) do
      center = {master.x, master.y}
      destination = Cell.random_traversable_near(master.map_name, center, @follow_distance)
      if destination == center, do: {:cont, state}, else: walk_to_master(state, destination)
    else
      {:cont, state}
    end
  end

  defp inherit_target(%MobState{target_ref: nil, loot_target_id: nil} = state, master, now)
       when now - state.last_linktime >= 1_000 do
    with {type, id} = target <- master_target(master, state),
         {:ok, {_, unit, _}} <- UnitRegistry.get_unit(type, id) do
      state = %{state | last_linktime: now}
      viewer = %{class: MobState.monster_class(state), detector: MobState.detector?(state)}

      if Unit.living?(unit) and Interpreter.targetable?(type, id) and
           Targeting.attack_visible?(viewer, %{unit_type: type, unit_id: id}),
         do: {:halt, %{state | target_ref: target}},
         else: {:cont, state}
    else
      _missing -> {:cont, state}
    end
  end

  defp inherit_target(state, _master, _now), do: {:cont, state}

  defp master_target(%MobState{attack_target: target}, _slave) when not is_nil(target), do: target
  defp master_target(%MobState{chase_target: target}, _slave) when not is_nil(target), do: target

  defp master_target(%MobState{casting: %{unit_target: {:unit, type, id}}}, slave) do
    with {:ok, {module, unit, _}} <- UnitRegistry.get_unit(type, id),
         true <- Relationship.enemy?(MobState.to_combatant(slave), module.to_combatant(unit)) do
      {type, id}
    else
      _support_or_missing -> nil
    end
  end

  defp master_target(master, _slave), do: master.target_ref

  defp walk_to_master(state, {x, y} = destination) do
    with {:ok, map} <- MapCache.get(state.map_name),
         {:ok, _path} <- Pathfinding.walk_path(map, {state.x, state.y}, destination) do
      {:noreply, walking} = MovementHandler.handle_move_to(state, x, y)
      if walking.movement_state == :moving, do: {:halt, walking}, else: {:cont, walking}
    else
      _blocked ->
        HitStop.cancel(state.pending_step)
        stopped = MobState.stop_movement(state)
        Movement.set_position(:mob, state.instance_id, stopped, state.map_name)
        {:cont, stopped}
    end
  end
end
