defmodule Aesir.ZoneServer.Unit.Mob.AIStateMachine do
  @moduledoc """
  AI state machine logic for mobs.

  Implements different AI behaviors based on the mob's current state:
  - :idle - Default state, passive behavior
  - :alert - Detected potential targets, evaluating threats
  - :combat - Actively fighting a target
  - :chase - Pursuing a target that moved out of attack range
  - :return - Returning to spawn area after losing target

  This module separates AI logic from the MobSession GenServer for better
  organization and testability.
  """

  require Logger

  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Guild.Relations
  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Map.LineOfSight
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.AttackPositioning
  alias Aesir.ZoneServer.Mmo.Combat.Relationship
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Pathfinding
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.Invincibility
  alias Aesir.ZoneServer.Unit.Ref
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @doc """
  Processes AI logic based on current state.
  Returns updated MobState.
  """
  @spec process_ai(MobState.t()) :: MobState.t()
  def process_ai(%MobState{ai_state: ai_state} = state) do
    current_time = System.system_time(:second)
    updated_state = %{state | last_ai_tick: current_time}

    case ai_state do
      :idle -> process_idle(updated_state)
      :alert -> process_alert(updated_state)
      :combat -> process_combat(updated_state)
      :chase -> process_chase(updated_state)
      :return -> process_return(updated_state)
    end
  end

  @doc """
  Checks if a mob should become aggressive towards nearby entities.
  """
  @spec check_aggro(MobState.t()) :: MobState.t()
  def check_aggro(%MobState{} = state) do
    if MobState.aggressive?(state) and state.ai_state == :idle do
      case find_nearby_targets(state) do
        [] ->
          state

        targets ->
          # Pick the closest target
          closest_target = select_closest_target(state, targets)

          state
          |> MobState.set_target(closest_target)
          |> MobState.set_initiated(true)
          |> MobState.set_ai_state(:alert)
      end
    else
      state
    end
  end

  @rude_attacked_count 1
  @area_size 14
  @reach_blocking_statuses [
    :sc_spiderweb,
    :sc_bite,
    :sc_vacuum_extreme,
    :sc_thornstrap,
    :sc__manhole
  ]

  @doc """
  The AI's target-change step for a pending attacked event (`attacked_ref`),
  run after skill selection and before the state's own step. Returns the
  updated state and whether the rude-attacked event skill use fires.

  A mob that cannot attack keeps the event pending. When the attacker is the
  current (valid) target and the mob can neither hit it from where it stands
  nor reach it within its chase range, it counts a rude attack. Otherwise,
  when the mob has no valid target or may change it (`can_change_target?/2`),
  an attacker it cannot fight back (off its map, beyond the visual area, not an
  enemy, or out of range and unreachable) counts a rude attack, unless the hit
  was self-inflicted; an attacker it can see is adopted as the target, taking
  one rude attack back off the count. A count above 1 fires the event. The
  event is consumed either way.
  """
  @spec process_attacked(MobState.t()) :: {MobState.t(), boolean()}
  def process_attacked(%MobState{attacked_ref: nil} = state), do: {state, false}

  def process_attacked(%MobState{} = state) do
    if :can_attack in (state.mob_data.modes || []) do
      {state, rude?} = change_target(state, valid_target(state))
      {MobState.clear_attacked(state), rude?}
    else
      {state, false}
    end
  end

  defp valid_target(%MobState{target_ref: nil}), do: nil

  defp valid_target(%MobState{target_ref: target_ref} = state) do
    if can_target?(state, target_ref), do: target_ref, else: nil
  end

  defp change_target(%MobState{attacked_ref: attacker} = state, attacker) do
    if not target_in_attack_range?(state, attacker) and
         not reachable?(state, attacker, MobState.get_chase_range(state)),
       do: count_rude_attack(state),
       else: {state, false}
  end

  defp change_target(%MobState{attacked_ref: attacker} = state, current) do
    cond do
      not (is_nil(current) or can_change_target?(state, attacker)) ->
        {state, false}

      not can_fight_back?(state, attacker) ->
        if attacker == {:mob, state.instance_id},
          do: {state, false},
          else: count_rude_attack(state)

      not attack_visible?(state, attacker) ->
        {state, false}

      true ->
        {adopt_attacker(state, attacker), false}
    end
  end

  defp count_rude_attack(%MobState{attacked_count: count} = state) do
    count = count + 1
    {%{state | attacked_count: count}, count > @rude_attacked_count}
  end

  defp adopt_attacker(%MobState{} = state, attacker) do
    state = %{state | target_ref: attacker, attacked_count: max(state.attacked_count - 1, 0)}

    if state.ai_state in [:combat, :chase],
      do: MobState.settle_skill_state(state),
      else: MobState.set_ai_state(state, :combat)
  end

  @doc """
  Whether a mob may switch its target to `attacker` in its skill state: in its
  attack state only with `change_target_melee` and only for the norm attacker;
  in rush only with `change_target_chase`; always in follow, angry, idle and
  walk.
  """
  @spec can_change_target?(MobState.t(), Ref.t()) :: boolean()
  def can_change_target?(%MobState{} = state, attacker) do
    modes = state.mob_data.modes || []

    case MobState.skill_state(state) do
      :berserk -> :change_target_melee in modes and state.norm_attacked_ref == attacker
      :rush -> :change_target_chase in modes
      _other -> true
    end
  end

  defp can_fight_back?(state, {type, id} = attacker) do
    case SpatialIndex.get_unit_position(type, id) do
      {:ok, {x, y, map_name}} when map_name == state.map_name ->
        distance = Geometry.chebyshev_distance(state.x, state.y, x, y)

        distance <= @area_size and enemy?(state, attacker) and
          (distance <= MobState.get_attack_range(state) or
             reachable?(state, attacker, distance + MobState.get_chase_range(state)))

      _other ->
        false
    end
  end

  # Whether the mob can reach a cell next to `target` within `range`: an
  # immobile mob held in place by a reach-blocking status, once its walk delay
  # has passed, cannot, nor can a mob
  # with no walk path to that cell, or with a long one around an obstacle.
  defp reachable?(state, {type, id}, range) do
    with true <- not reach_blocked?(state),
         {:ok, {x, y, map_name}} when map_name == state.map_name <-
           SpatialIndex.get_unit_position(type, id) do
      walk_reachable?(state, {x, y}, range)
    else
      _ -> false
    end
  end

  defp reach_blocked?(state) do
    not (:can_move in (state.mob_data.modes || []) and
           Interpreter.can_move?(:mob, state.instance_id)) and
      not MobState.walk_delayed?(state, System.monotonic_time(:millisecond)) and
      Enum.any?(@reach_blocking_statuses, &StatusStorage.has_status?(:mob, state.instance_id, &1))
  end

  defp walk_reachable?(%MobState{x: x, y: y}, {x, y}, _range), do: true

  defp walk_reachable?(state, {tx, ty}, range) do
    with true <- Geometry.chebyshev_distance(state.x, state.y, tx, ty) <= range,
         {:ok, cell} <- adjoining_cell(state, {tx, ty}),
         {:ok, map_data} <- MapCache.get(state.map_name),
         {:ok, path} <- Pathfinding.find_path(map_data, {state.x, state.y}, cell, profile: :mob) do
      length(path) <= @area_size or
        LineOfSight.passable?(state.map_name, {state.x, state.y}, cell)
    else
      _ -> false
    end
  end

  @dirs [{0, 1}, {-1, 1}, {-1, 0}, {-1, -1}, {0, -1}, {1, -1}, {1, 0}, {1, 1}]

  defp adjoining_cell(state, {tx, ty}) do
    toward = {tx - sign(tx - state.x), ty - sign(ty - state.y)}

    [toward | Enum.map(@dirs, fn {dx, dy} -> {tx - dx, ty - dy} end)]
    |> Enum.find(fn {x, y} -> Cell.traversable?(state.map_name, x, y) end)
    |> case do
      nil -> :error
      cell -> {:ok, cell}
    end
  end

  defp sign(n) when n > 0, do: 1
  defp sign(n) when n < 0, do: -1
  defp sign(_n), do: 0

  @doc """
  Attacks `target_ref` once if it is in attack range, without changing the
  mob's target (an attack order such as Poison React's counter). A mob with a
  target enters its attack state.
  """
  @spec attack_once(MobState.t(), Ref.t()) :: MobState.t()
  def attack_once(%MobState{} = state, target_ref) do
    state =
      if target_in_attack_range?(state, target_ref),
        do: execute_mob_attack(state, target_ref),
        else: state

    if state.target_ref, do: MobState.set_ai_state(state, :combat), else: state
  end

  @doc """
  Initiates movement toward a target position.
  """
  @spec move_toward(MobState.t(), integer(), integer()) :: MobState.t()
  def move_toward(%MobState{} = state, target_x, target_y) do
    if walk_ready?(state), do: MobSession.move_to(state.process_pid, target_x, target_y)

    state
  end

  # A mob starts a walk only from a live session, when it may move (no no_move
  # status), is not already moving and has not just stopped (300 ms cooldown).
  defp walk_ready?(%MobState{process_pid: nil}), do: false

  defp walk_ready?(%MobState{} = state) do
    current_time = System.system_time(:millisecond)

    Interpreter.can_move?(:mob, state.instance_id) and state.movement_state != :moving and
      (state.last_movement_end_time == nil or current_time - state.last_movement_end_time >= 300)
  end

  # A walk the AI starts settles the skill state: the source's unit_walktobl
  # (chase -> RUSH) and mob_randomwalk (-> WALK) each reach mob_setstate.
  defp start_walk(%MobState{} = state, target_x, target_y) do
    if walk_ready?(state),
      do: state |> move_toward(target_x, target_y) |> MobState.settle_skill_state(),
      else: state
  end

  # Picks the cell the mob should path to while chasing: an adjacent, unoccupied
  # cell within attack range of the target (shared with the player approach via
  # AttackPositioning), never the target's own cell. Recomputed every AI tick, so
  # a cell taken by another unit mid-approach is re-picked on the next tick.
  # Falls back to the target's cell when no free cell is known (e.g. map missing).
  defp chase_destination(%MobState{} = state, {target_x, target_y}) do
    attack_range = MobState.get_attack_range(state)

    case MapCache.get(state.map_name) do
      {:ok, _map_data} ->
        walkable? = &Cell.traversable?(state.map_name, &1, &2)
        occupied? = build_occupied?(state, {target_x, target_y}, attack_range)

        AttackPositioning.adjacent_attack_cell(
          {state.x, state.y},
          {target_x, target_y},
          attack_range,
          walkable?,
          occupied?
        ) || {target_x, target_y}

      {:error, _reason} ->
        {target_x, target_y}
    end
  end

  # Builds an `(x, y) -> bool` occupancy predicate from currently-known nearby
  # units, excluding the chasing mob itself and the target player so the mob is
  # not blocked by its own or the target's cell. A radius of `range * 2` covers
  # the full Chebyshev square of candidate cells.
  defp build_occupied?(%MobState{} = state, {target_x, target_y}, range) do
    cells =
      state.map_name
      |> SpatialIndex.get_all_units_in_range(target_x, target_y, range * 2)
      |> Enum.reject(fn {type, id} ->
        (type == :mob and id == state.instance_id) or
          {type, id} == state.target_ref or inactive_unit?({type, id})
      end)
      |> Enum.reduce(MapSet.new(), fn {type, id}, acc ->
        case SpatialIndex.get_unit_position(type, id) do
          {:ok, {x, y, _map}} -> MapSet.put(acc, {x, y})
          {:error, _reason} -> acc
        end
      end)

    fn x, y -> MapSet.member?(cells, {x, y}) end
  end

  @doc """
  Checks if mob should return to spawn area.
  """
  @spec should_return_to_spawn?(MobState.t()) :: boolean()
  def should_return_to_spawn?(%MobState{} = state) do
    {spawn_x, spawn_y} = spawn_anchor(state)

    # Calculate distance from spawn
    distance_from_spawn = abs(state.x - spawn_x) + abs(state.y - spawn_y)

    # Return if too far from spawn (beyond chase range)
    max_distance = MobState.get_chase_range(state) * 2
    distance_from_spawn > max_distance
  end

  @doc """
  Checks if mob has reached its spawn area.
  """
  @spec at_spawn_area?(MobState.t()) :: boolean()
  def at_spawn_area?(%MobState{} = state) do
    {spawn_x, spawn_y} = spawn_anchor(state)

    abs(state.x - spawn_x) <= 2 and abs(state.y - spawn_y) <= 2
  end

  # The cell the mob actually spawned on. `spawn_ref.spawn_area` is the raw
  # spawn config, whose x/y of 0,0 means "random cell anywhere on the map", so
  # it cannot anchor wander/return behavior.
  defp spawn_anchor(%MobState{spawn_point: {x, y}}), do: {x, y}
  defp spawn_anchor(%MobState{} = state), do: {state.x, state.y}

  defp process_idle(state) do
    result = check_aggro(state)

    if result.ai_state != state.ai_state do
      result
    else
      do_idle_movement(result)
    end
  end

  defp process_alert(state) do
    case state.target_ref do
      nil ->
        # No target, return to idle
        MobState.set_ai_state(state, :idle)

      target_ref ->
        cond do
          not can_target?(state, target_ref) ->
            state
            |> MobState.set_target(nil)
            |> MobState.set_ai_state(:idle)

          target_in_attack_range?(state, target_ref) ->
            # Target in attack range, switch to combat
            MobState.set_ai_state(state, :combat)

          target_in_chase_range?(state, target_ref) ->
            # Target in chase range, start chasing
            MobState.set_ai_state(state, :chase)

          true ->
            # Target too far, lose interest
            state
            |> MobState.set_target(nil)
            |> MobState.set_ai_state(:idle)
        end
    end
  end

  defp process_combat(state) do
    case state.target_ref do
      nil ->
        # No target, return to idle
        MobState.set_ai_state(state, :idle)

      target_ref ->
        cond do
          not can_target?(state, target_ref) ->
            # Target went untargetable (trick-dead) or concealed, shed aggro
            state
            |> MobState.set_target(nil)
            |> MobState.set_ai_state(:idle)

          target_in_attack_range?(state, target_ref) ->
            # Can attack - perform attack logic here
            execute_mob_attack(state, target_ref)

          target_in_chase_range?(state, target_ref) ->
            # Target moved out of attack range but still chaseable
            MobState.set_ai_state(state, :chase)

          should_return_to_spawn?(state) ->
            # Too far from spawn, return
            state
            |> MobState.set_target(nil)
            |> MobState.set_ai_state(:return)

          true ->
            # Target lost, return to idle
            state
            |> MobState.set_target(nil)
            |> MobState.set_ai_state(:idle)
        end
    end
  end

  defp process_chase(state) do
    case state.target_ref do
      nil ->
        # No target, return to idle
        MobState.set_ai_state(state, :idle)

      target_ref ->
        cond do
          not can_target?(state, target_ref) ->
            # Target went untargetable (trick-dead) or concealed, shed aggro and return to spawn
            state
            |> MobState.set_target(nil)
            |> MobState.set_ai_state(:return)

          target_in_attack_range?(state, target_ref) ->
            # Caught up to target, switch to combat
            MobState.set_ai_state(state, :combat)

          target_in_chase_range?(state, target_ref) ->
            # Continue chasing - move towards target using pathfinding
            # credo:disable-for-next-line Credo.Check.Refactor.Nesting
            case target_position(target_ref) do
              {:ok, {target_x, target_y, map_name}} when map_name == state.map_name ->
                {dest_x, dest_y} = chase_destination(state, {target_x, target_y})
                start_walk(state, dest_x, dest_y)

              _ ->
                # Target not found or on different map
                state
                |> MobState.set_target(nil)
                |> MobState.set_ai_state(:idle)
            end

          true ->
            # Lost target or too far from spawn: return to spawn
            state
            |> MobState.set_target(nil)
            |> MobState.set_ai_state(:return)
        end
    end
  end

  defp process_return(state) do
    if at_spawn_area?(state) do
      # Reached spawn, clear aggro and return to idle
      state
      |> MobState.clear_aggro()
      |> MobState.set_target(nil)
      |> MobState.set_ai_state(:idle)
      |> MobState.stop_movement()
    else
      # Continue returning to spawn using pathfinding
      {spawn_x, spawn_y} = spawn_anchor(state)

      move_toward(state, spawn_x, spawn_y)
    end
  end

  defp find_nearby_targets(state) do
    players =
      SpatialIndex.get_units_in_range(
        :player,
        state.map_name,
        state.x,
        state.y,
        state.view_range
      )
      |> Enum.map(&{:player, &1})

    homunculi =
      state.map_name
      |> SpatialIndex.get_all_units_in_range(state.x, state.y, state.view_range)
      |> Enum.filter(&(elem(&1, 0) == :homunculus))

    Enum.filter(players ++ homunculi, &can_target?(state, &1))
  end

  defp can_target?(%MobState{} = state, {:player, target_id} = target_ref) do
    enemy?(state, target_ref) and
      not StatusStorage.has_status?(:player, target_id, :sc_gangsterparadise) and
      attack_visible?(state, target_ref)
  end

  defp can_target?(%MobState{guild_id: 0} = state, {:homunculus, _id} = target_ref) do
    living_enemy?(state, target_ref)
  end

  defp can_target?(%MobState{guild_id: guild_id} = state, {:homunculus, id})
       when guild_id > 0 do
    case UnitRegistry.get_unit(:homunculus, id) do
      {:ok, {module, target, _pid}} ->
        combatant = module.to_combatant(target)

        Unit.living?(target) and
          Relationship.enemy?(MobState.to_combatant(state), combatant) and
          not Relations.friendly?(state.guild_id, owner_guild_id(combatant))

      {:error, :not_found} ->
        false
    end
  end

  defp can_target?(_state, _target_ref), do: false

  # Whether the mob may fight `target_ref` at all: a living, non-allied unit
  # that is not invincible.
  defp enemy?(%MobState{} = state, {:player, target_id}) do
    case UnitRegistry.get_unit(:player, target_id) do
      {:ok, {_module, target, _pid}} ->
        Unit.living?(target) and
          not Relations.friendly?(state.guild_id, target.guild_id) and
          not Invincibility.active?(target)

      {:error, :not_found} ->
        false
    end
  end

  defp enemy?(state, {:homunculus, _id} = target_ref), do: can_target?(state, target_ref)
  defp enemy?(_state, _target_ref), do: false

  # Whether the mob can act on an enemy it may fight: the enemy is targetable,
  # visible to it and not its charmer.
  defp attack_visible?(%MobState{} = state, {:player, target_id}) do
    Interpreter.targetable?(:player, target_id) and
      not Interpreter.charmed_against?(:mob, state.instance_id, target_id) and
      Targeting.attack_visible?(attack_viewer(state), %{unit_type: :player, unit_id: target_id})
  end

  defp attack_visible?(_state, _target_ref), do: true

  defp attack_viewer(state) do
    %{
      class: if(MobState.is_boss?(state), do: :boss, else: :normal),
      detector: MobState.detector?(state)
    }
  end

  defp living_enemy?(state, {type, id}) do
    case UnitRegistry.get_unit(type, id) do
      {:ok, {module, target, _pid}} ->
        Unit.living?(target) and
          Relationship.enemy?(MobState.to_combatant(state), module.to_combatant(target))

      {:error, :not_found} ->
        false
    end
  end

  defp owner_guild_id(combatant) do
    with {:player, owner_id} <- Relationship.social_root(combatant),
         {:ok, {_module, owner, _pid}} <- UnitRegistry.get_unit(:player, owner_id) do
      owner.guild_id
    else
      _ -> 0
    end
  end

  defp inactive_unit?({type, id}) when type in [:player, :homunculus] do
    case UnitRegistry.get_unit(type, id) do
      {:ok, {_module, unit, _pid}} -> not Unit.living?(unit)
      {:error, :not_found} -> true
    end
  end

  defp inactive_unit?(_unit), do: false

  defp select_closest_target(state, targets) when is_list(targets) do
    targets
    |> Enum.map(fn target_ref ->
      case target_position(target_ref) do
        {:ok, {target_x, target_y, _map}} ->
          distance = abs(state.x - target_x) + abs(state.y - target_y)
          {target_ref, distance}

        _ ->
          # Invalid position, very high distance
          {target_ref, 999_999}
      end
    end)
    |> Enum.min_by(fn {_id, distance} -> distance end)
    |> elem(0)
  end

  defp target_in_attack_range?(state, target_ref) do
    attack_range = MobState.get_attack_range(state)
    target_in_range?(state, target_ref, attack_range)
  end

  defp target_in_chase_range?(state, target_ref) do
    chase_range = MobState.get_chase_range(state)
    target_in_range?(state, target_ref, chase_range)
  end

  defp target_in_range?(state, target_ref, range) do
    case target_position(target_ref) do
      {:ok, {target_x, target_y, map_name}} when map_name == state.map_name ->
        distance = Geometry.chebyshev_distance(state.x, state.y, target_x, target_y)
        distance <= range

      _ ->
        false
    end
  end

  defp do_idle_movement(state) do
    current_time = System.system_time(:second)

    # Check if we can attempt idle movement
    modes = state.mob_data.modes || []

    can_move =
      state.movement_state == :standing and :can_move in modes and
        :no_random_walk not in modes

    random_value = :rand.uniform(100)
    random_chance = random_value <= 20

    enough_time_passed =
      state.last_idle_movement_time == nil or
        current_time - state.last_idle_movement_time >= 3

    if can_move and random_chance and enough_time_passed do
      {spawn_x, spawn_y} = spawn_anchor(state)
      # Maximum distance from spawn to wander
      max_wander_distance = 5

      # Random destination around the spawn cell; pathfinding rejects
      # unwalkable or out-of-bounds picks, so no further clamping is needed.
      random_x = spawn_x + :rand.uniform(max_wander_distance * 2 + 1) - max_wander_distance - 1
      random_y = spawn_y + :rand.uniform(max_wander_distance * 2 + 1) - max_wander_distance - 1

      target_x = max(random_x, 0)
      target_y = max(random_y, 0)

      # Update last idle movement attempt time and move
      updated_state = %{state | last_idle_movement_time: current_time}
      start_walk(updated_state, target_x, target_y)
    else
      state
    end
  end

  defp target_position({type, id}), do: SpatialIndex.get_unit_position(type, id)

  defp execute_mob_attack(state, target_ref) do
    # Check if enough time has passed since last attack
    current_time = System.system_time(:millisecond)
    attack_delay = MobState.get_attack_delay(state)

    can_attack =
      Interpreter.can_attack?(:mob, state.instance_id) and
        (state.last_attack_time == nil or
           current_time - state.last_attack_time >= attack_delay)

    if can_attack do
      # Execute attack using the Combat system. An intercepted swing (a target
      # status caught it, dealing no damage) still advances the attack cadence
      # and, like the source's unit_attack, settles the skill state; a refused
      # one returns before it.
      case Combat.execute_mob_attack(state, target_ref) do
        result when result in [:ok, :intercepted] ->
          state = MobState.settle_skill_state(state)
          MobState.rest(%{state | last_attack_time: current_time}, current_time)

        {:error, reason} ->
          # Attack failed, don't update attack time
          Logger.debug("Mob #{state.instance_id} attack failed: #{inspect(reason)}")
          state
      end
    else
      # Still in attack cooldown, stay in combat without attacking
      state
    end
  end
end
