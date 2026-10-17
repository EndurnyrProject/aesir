defmodule Aesir.ZoneServer.Unit.Mob.AIStateMachine do
  @moduledoc """
  The monster's hard AI think (`process_ai/3`), run in its session by
  `AiHandler`: target validity, the attacked event's target change, the
  target search, random walks, the attack order, the chase and the immobile
  fallback, each moving the mob's skill state (`MobState.set_state/2`).
  """

  import Bitwise

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
  alias Aesir.ZoneServer.Unit.HitStop
  alias Aesir.ZoneServer.Unit.Mob.Handlers.MovementHandler
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Movement
  alias Aesir.ZoneServer.Unit.Player.Invincibility
  alias Aesir.ZoneServer.Unit.Ref
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

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

  defp adopt_attacker(%MobState{} = state, attacker),
    do: %{state | target_ref: attacker, attacked_count: max(state.attacked_count - 1, 0)}

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
    not can_move?(state, System.monotonic_time(:millisecond)) and
      not MobState.walk_delayed?(state, System.monotonic_time(:millisecond)) and
      Enum.any?(@reach_blocking_statuses, &StatusStorage.has_status?(:mob, state.instance_id, &1))
  end

  @doc """
  Whether the mob can move at monotonic `mono` (ms): it has the move mode, no
  status blocks its movement and its walk delay has passed.
  """
  @spec can_move?(MobState.t(), integer()) :: boolean()
  def can_move?(%MobState{} = state, mono) do
    :can_move in (state.mob_data.modes || []) and
      Interpreter.can_move?(:mob, state.instance_id) and
      not MobState.walk_delayed?(state, mono)
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

  defp can_target?(%MobState{} = state, {:player, _target_id} = target_ref) do
    enemy?(state, target_ref) and not gangster_protected?(state, target_ref) and
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
      class: MobState.monster_class(state),
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

  defp target_in_attack_range?(state, target_ref) do
    attack_range = MobState.get_attack_range(state)
    target_in_range?(state, target_ref, attack_range)
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

  defp target_position({type, id}), do: SpatialIndex.get_unit_position(type, id)

  @unlock_time 2000
  @random_walk_interval 4000
  @random_walk_span 7
  @random_walk_side @random_walk_span * 2 + 1

  @doc """
  One hard AI think at `now` (ms) after skill selection: target validity,
  the attacked event (`process_attacked/1`, with `opts[:on_rude]` run on a rude
  attack), target search, random walk when there is no target, else the
  attack, the chase or the immobile fallback. Returns the updated state.
  """
  @spec process_ai(MobState.t(), integer(), keyword()) :: MobState.t()
  def process_ai(%MobState{} = state, now, opts \\ []) do
    mono = System.monotonic_time(:millisecond)

    view_range =
      if StatusStorage.has_status?(:mob, state.instance_id, :sc_blind),
        do: 1,
        else: state.view_range

    can_move = can_move?(state, mono)
    state = if can_move, do: %{state | last_canmove: now}, else: state

    case check_target(state, now) do
      {:halt, state} ->
        state

      {:cont, state} ->
        {state, rude?} = process_attacked(state)
        state = if rude?, do: Keyword.get(opts, :on_rude, & &1).(state), else: state
        state = search(state, view_range)

        case state.target_ref do
          nil -> idle_step(state, now, mono)
          target -> engage(state, target, can_move, now, mono)
        end
    end
  end

  # A walk never exceeds the chase refresh distance, so a walking mob keeps
  # walking before dropping a target that became invalid; a target gone from
  # the world is dropped at once.
  defp check_target(%MobState{target_ref: nil} = state, _now), do: {:cont, state}

  defp check_target(%MobState{target_ref: target} = state, now) do
    cond do
      valid_target?(state, target) ->
        if MobState.chasing?(state) and not walking?(state) and
             not target_in_attack_range?(state, target) and not visible?(state, target),
           do: {:halt, unlock_target(state, now)},
           else: {:cont, state}

      walking?(state) and in_world?(target) ->
        {:halt, state}

      true ->
        {:cont, unlock_target(state, now)}
    end
  end

  defp in_world?({type, id}), do: match?({:ok, _unit}, UnitRegistry.get_unit(type, id))

  defp valid_target?(state, {type, id} = target) do
    case SpatialIndex.get_unit_position(type, id) do
      {:ok, {_x, _y, map_name}} when map_name == state.map_name ->
        enemy?(state, target) and not gangster_protected?(state, target) and
          (MobState.attacking?(state) or attack_visible?(state, target))

      _other ->
        false
    end
  end

  defp visible?(state, {:player, target_id}),
    do: Targeting.attack_visible?(attack_viewer(state), %{unit_type: :player, unit_id: target_id})

  defp visible?(_state, _target), do: true

  defp gangster_protected?(state, {:player, id}),
    do:
      StatusStorage.has_status?(:player, id, :sc_gangsterparadise) and
        not MobState.status_immune?(state)

  defp gangster_protected?(_state, _target), do: false

  defp walking?(%MobState{movement_state: :moving}), do: true
  defp walking?(_state), do: false

  defp search(%MobState{} = state, view_range) do
    modes = state.mob_data.modes || []

    cond do
      (:aggressive in modes and is_nil(state.target_ref)) or state.skill_state == :follow ->
        state |> active_search(view_range) |> rush_new_target_in_range(state.target_ref)

      :change_chase in modes and MobState.chasing?(state) ->
        change_chase(state, min(view_range, MobState.get_attack_range(state)))

      true ->
        state
    end
  end

  # A new target found already in attack range puts the mob straight into
  # rush, out of its aggressive mode.
  defp rush_new_target_in_range(%MobState{target_ref: nil} = state, _previous), do: state
  defp rush_new_target_in_range(%MobState{target_ref: same} = state, same), do: state

  defp rush_new_target_in_range(%MobState{target_ref: target} = state, _previous) do
    if target_in_attack_range?(state, target),
      do: MobState.set_state(%{state | aggressive: false}, :rush),
      else: state
  end

  # Takes the closest enemy in view the mob can see, attack and path to; the
  # current target is kept unless a candidate is strictly closer.
  defp active_search(state, view_range) do
    current = state.target_ref
    current_distance = current && target_distance(state, current)

    {target, _distance} =
      state
      |> units_in_range(view_range)
      |> Enum.reject(&(&1 == current))
      |> Enum.filter(&(can_target?(state, &1) and not too_strong?(state, &1)))
      |> Enum.reduce({current, current_distance}, fn candidate, {best, best_distance} ->
        distance = target_distance(state, candidate)

        if not homunculus_kept?(best, candidate) and distance != nil and
             (best == nil or best_distance > distance) and
             in_sight?(state, candidate, view_range) and
             path_within?(state, candidate, search_path_limit(state, view_range)) do
          {candidate, distance}
        else
          {best, best_distance}
        end
      end)

    MobState.set_target(state, target)
  end

  # A homunculus pick is never replaced by a unit of another kind.
  defp homunculus_kept?({:homunculus, _id}, {type, _candidate}), do: type != :homunculus
  defp homunculus_kept?(_best, _candidate), do: false

  # A standing mob paths within its view range, a walking one within its chase range.
  defp search_path_limit(state, view_range),
    do: if(walking?(state), do: MobState.get_chase_range(state), else: view_range)

  defp too_strong?(state, {type, id}) do
    :target_weak in (state.mob_data.modes || []) and
      case UnitRegistry.get_unit(type, id) do
        {:ok, {module, unit, _pid}} ->
          module.get_stats(unit).base_level >= state.mob_data.level - 5

        {:error, :not_found} ->
          true
      end
  end

  defp in_sight?(state, {type, id}, range) do
    case SpatialIndex.get_unit_position(type, id) do
      {:ok, {x, y, map_name}} when map_name == state.map_name ->
        Geometry.chebyshev_distance(state.x, state.y, x, y) <= range and
          LineOfSight.passable?(state.map_name, {state.x, state.y}, {x, y})

      _other ->
        false
    end
  end

  # The search's reach check paths around walls only.
  defp path_within?(state, {type, id}, max_cells) do
    with {:ok, {x, y, _map}} <- SpatialIndex.get_unit_position(type, id),
         {:ok, map_data} <- MapCache.get(state.map_name),
         {:ok, path} <- Pathfinding.find_path(map_data, {state.x, state.y}, {x, y}, cells: :walls) do
      length(path) <= max_cells
    else
      _ -> false
    end
  end

  # A chasing mob takes an enemy it can attack from where it stands, the last
  # such in block order.
  defp change_chase(state, range) do
    state
    |> units_in_range(range)
    |> Enum.filter(fn candidate ->
      candidate != state.target_ref and can_target?(state, candidate) and
        target_in_attack_range?(state, candidate)
    end)
    |> List.last()
    |> case do
      nil -> state
      candidate -> MobState.set_target(state, candidate)
    end
  end

  # The players and homunculi in the square of `range` cells around the mob,
  # in the map's block order.
  defp units_in_range(state, range) do
    state.map_name
    |> SpatialIndex.units_in_area(
      state.x - range,
      state.y - range,
      state.x + range,
      state.y + range
    )
    |> Enum.filter(&(elem(&1, 0) in [:player, :homunculus]))
  end

  defp target_distance(state, {type, id}) do
    case SpatialIndex.get_unit_position(type, id) do
      {:ok, {x, y, map_name}} when map_name == state.map_name ->
        Geometry.chebyshev_distance(state.x, state.y, x, y)

      _other ->
        nil
    end
  end

  # No target: unlock, then a random walk when due (slaves never wander); a
  # walk that fails is retried after the walk delay or within a second.
  defp idle_step(state, now, mono) do
    state = unlock_target(state, now)

    if is_nil(state.master_id) and state.next_walktime != nil and state.next_walktime <= now do
      case random_walk(state, now, mono) do
        {:ok, state} -> state
        {:error, state} -> delay_failed_walk(state, now, mono)
      end
    else
      state
    end
  end

  # A failed walk is booked for the walk delay's end when that is later than
  # the walk time, past or not, else within a second.
  defp delay_failed_walk(%MobState{walk_delay_until: 0} = state, now, _mono),
    do: %{state | next_walktime: now + :rand.uniform(1000) - 1}

  defp delay_failed_walk(state, now, mono) do
    canmove = now + (state.walk_delay_until - mono)

    if state.next_walktime < canmove,
      do: %{state | next_walktime: canmove},
      else: %{state | next_walktime: now + :rand.uniform(1000) - 1}
  end

  defp engage(state, target, can_move, now, mono) do
    cond do
      target_in_attack_range?(state, target) ->
        case attack_in_range(state, target, now) do
          {state, :stop} -> stop_walk(state)
          {state, :continue} -> state
        end

      walking?(state) and MobState.chasing?(state) ->
        state

      immobile?(state, can_move, mono) ->
        immobile_step(state, now)

      true ->
        follow_up(state, target, now, mono)
    end
  end

  # A mob that cannot chase: no move mode, or unable to move for a reason other
  # than a running walk delay.
  defp immobile?(state, can_move, mono) do
    :can_move not in (state.mob_data.modes || []) or
      (not can_move and
         (not Interpreter.can_move?(:mob, state.instance_id) or
            not MobState.walk_delayed?(state, mono)))
  end

  defp follow_up(state, target, now, mono) do
    cond do
      walking?(state) and chase_target?(state, target) ->
        state

      state.skill_state == :angry and
          not reachable?(state, target, MobState.get_chase_range(state)) ->
        unlock_target(state, now)

      true ->
        chase(state, target, now, mono)
    end
  end

  # The target is in attack range: the walk stops unless the attack order was
  # refused, in which case the mob keeps walking.
  defp attack_in_range(state, target, now) do
    cond do
      StatusStorage.has_status?(:mob, state.instance_id, :sc_hiding) ->
        {MobState.set_state(state, :berserk), :stop}

      state.attack_target != target or not MobState.attacking?(state) ->
        order_attack(state, target, now)

      true ->
        {state, :stop}
    end
  end

  # The attack order: a mob that cannot attack drops it and keeps walking; an
  # armed attack timer only switches the target; otherwise the swing fires now
  # when the attack delay has ended, else the attack timer is armed for its
  # end, and the state becomes the attack state either way.
  defp order_attack(state, target, now) do
    cond do
      not Interpreter.can_attack?(:mob, state.instance_id) ->
        {MobState.stop_attack(state), :continue}

      MobState.attacking?(state) ->
        {MobState.set_attack_target(state, target), :stop}

      true ->
        state = MobState.set_attack_target(state, target)

        state =
          if attack_delay_over?(state, now),
            do: execute_mob_attack(state, target, now),
            else: MobState.arm_attack_timer(state, attack_ready_at(state))

        {MobState.set_state(state, :berserk), :stop}
    end
  end

  @doc """
  Whether the target of the mob's attack order is still in the world, on the
  mob's map and visible to it.
  """
  @spec attack_target_visible?(MobState.t()) :: boolean()
  def attack_target_visible?(%MobState{attack_target: nil}), do: false

  def attack_target_visible?(%MobState{attack_target: {type, id} = target} = state) do
    case SpatialIndex.get_unit_position(type, id) do
      {:ok, {_x, _y, map_name}} when map_name == state.map_name -> visible?(state, target)
      _other -> false
    end
  end

  @doc "Whether the mob's attack delay has ended at `now` (ms)."
  @spec attack_delay_over?(MobState.t(), integer()) :: boolean()
  def attack_delay_over?(%MobState{last_attack_time: nil}, _now), do: true

  def attack_delay_over?(%MobState{} = state, now), do: now >= attack_ready_at(state)

  defp attack_ready_at(%MobState{last_attack_time: last} = state),
    do: last + MobState.get_attack_delay(state)

  defp immobile_step(state, now) do
    cond do
      MobState.attacking?(state) -> state
      now - (state.last_canmove || now) > @unlock_time -> unlock_target(state, now)
      true -> MobState.set_state(state, :idle)
    end
  end

  defp chase_target?(%MobState{chase_target: chase_target}, target), do: chase_target == target

  # The chase walk: a walk-delayed mob keeps the chase target and resumes the
  # walk one millisecond after its delay ends (`resume_chase/1`); a walk that
  # cannot start drops the target.
  defp chase(state, target, now, mono) do
    case target_position(target) do
      {:ok, {target_x, target_y, map_name}} when map_name == state.map_name ->
        {dest_x, dest_y} = chase_destination(state, {target_x, target_y})
        state = state |> MobState.stop_attack() |> Map.put(:chase_target, target)

        if MobState.walk_delayed?(state, mono),
          do: %{state | chase_resume_at: state.walk_delay_until + 1},
          else: chase_walk(state, dest_x, dest_y, now)

      _other ->
        unlock_target(state, now)
    end
  end

  @doc """
  Resumes a chase walk held by the walk delay: a standing mob still chasing
  its target walks to it once the delay has passed and it may move; a delay
  still running books the resume again at its end.
  """
  @spec resume_chase(MobState.t()) :: MobState.t()
  def resume_chase(%MobState{chase_target: nil} = state), do: %{state | chase_resume_at: nil}

  def resume_chase(%MobState{chase_target: target} = state) do
    mono = System.monotonic_time(:millisecond)
    state = %{state | chase_resume_at: nil}

    cond do
      walking?(state) ->
        state

      MobState.walk_delayed?(state, mono) ->
        %{state | chase_resume_at: state.walk_delay_until + 1}

      can_move?(state, mono) ->
        resume_chase_walk(state, target)

      true ->
        state
    end
  end

  defp chase_walk(state, x, y, now) do
    case start_walk(state, x, y) do
      {:ok, state} -> MobState.set_state(state, :rush)
      {:error, state} -> unlock_target(state, now)
    end
  end

  defp resume_chase_walk(state, target) do
    with {:ok, {x, y, map_name}} when map_name == state.map_name <- target_position(target),
         {dest_x, dest_y} <- chase_destination(state, {x, y}),
         {:ok, walking} <- start_walk(state, dest_x, dest_y) do
      MobState.set_state(walking, :rush)
    else
      {:error, state} -> state
      _other -> state
    end
  end

  @doc """
  Locks the mob's target onto `target_ref` for a taunt (`provoke?` for a
  provoke, which also stamps the provoke flag): a current target is kept
  unless the skill state allows the change (`can_change_target?/2`), and a
  unit the mob cannot attack is not taken. A lock onto a unit other than the
  provoker clears the provoke flag; a provoked aggressive mob leaves its
  aggressive mode.
  """
  @spec lock_target(MobState.t(), Ref.t(), boolean()) :: MobState.t()
  def lock_target(%MobState{} = state, target_ref, provoke?) do
    state = if provoke?, do: %{state | provoke_flag: target_ref}, else: state

    if (is_nil(state.target_ref) or can_change_target?(state, target_ref)) and
         can_target?(state, target_ref),
       do: state |> MobState.set_target(target_ref) |> settle_provoke(target_ref),
       else: state
  end

  defp settle_provoke(%MobState{provoke_flag: nil} = state, _target_ref), do: state

  defp settle_provoke(%MobState{provoke_flag: flag} = state, target_ref) when flag != target_ref,
    do: %{state | provoke_flag: nil}

  defp settle_provoke(%MobState{} = state, _target_ref), do: %{state | aggressive: false}

  @doc """
  Drops the mob's target: an attack or chase state stops the attack, goes idle
  and sets the next random walk 4-5 s away; a finished walk goes idle; an idle
  or ongoing walk keeps its state. The chase target is cleared too.
  """
  @spec unlock_target(MobState.t(), integer()) :: MobState.t()
  def unlock_target(%MobState{} = state, now) do
    state =
      case state.skill_state do
        :walk ->
          if walking?(state), do: state, else: MobState.set_state(state, :idle)

        :idle ->
          state

        _other ->
          state
          |> MobState.stop_attack()
          |> MobState.set_state(:idle)
          |> Map.put(:next_walktime, next_walktime(now))
      end

    %{state | target_ref: nil, chase_target: nil}
  end

  @doc "The next random walk time from `now`: 4000-4999 ms away."
  @spec next_walktime(integer()) :: integer()
  def next_walktime(now), do: now + :rand.uniform(1000) - 1 + @random_walk_interval

  @doc """
  Starts a random walk when one is due and the mob may move and has no
  `no_random_walk` mode: up to 225 cells of the 15x15 square around the mob
  are tried from a random start, stepping 7 cells in a random direction order,
  until one is passable and reachable. Returns `{:ok, state}` in the walk
  state with the next walk time set past the walk, else `{:error, state}`.
  """
  @spec random_walk(MobState.t(), integer(), integer()) ::
          {:ok, MobState.t()} | {:error, MobState.t()}
  def random_walk(%MobState{} = state, now, mono) do
    modes = state.mob_data.modes || []

    if state.next_walktime > now or :no_random_walk in modes or not can_move?(state, mono) do
      {:error, state}
    else
      state = %{state | chase_target: nil}
      r = :rand.uniform(1 <<< 31) - 1
      rdir = :rand.uniform(4) - 1
      dx = rem(r, @random_walk_side) - @random_walk_span
      dy = rem(div(r, @random_walk_side), @random_walk_side) - @random_walk_span

      case try_random_cells(state, dx, dy, rdir, @random_walk_side * @random_walk_side) do
        {:ok, state} ->
          {:ok,
           %{
             MobState.set_state(state, :walk)
             | next_walktime: next_walktime(now) + walk_path_time(state)
           }}

        :error ->
          {:error, state}
      end
    end
  end

  defp try_random_cells(_state, _dx, _dy, _rdir, 0), do: :error

  defp try_random_cells(state, dx, dy, rdir, tries) do
    x = state.x + dx
    y = state.y + dy

    with true <- {x, y} != {state.x, state.y} and Cell.traversable?(state.map_name, x, y),
         {:ok, state} <- start_walk(state, x, y) do
      {:ok, state}
    else
      _ ->
        {dx, dy} = next_random_cell(dx, dy, rdir)
        try_random_cells(state, dx, dy, rdir, tries - 1)
    end
  end

  defp next_random_cell(dx, dy, 0), do: wrap_major(dx + @random_walk_span, dy, 1)
  defp next_random_cell(dx, dy, 1), do: wrap_major(dx - @random_walk_span, dy, -1)
  defp next_random_cell(dx, dy, 2), do: swap(wrap_major(dy + @random_walk_span, dx, 1))
  defp next_random_cell(dx, dy, 3), do: swap(wrap_major(dy - @random_walk_span, dx, -1))

  defp wrap_major(major, minor, sign) do
    if sign * major > @random_walk_span do
      minor = minor + sign * @random_walk_span

      minor =
        if sign * minor > @random_walk_span, do: minor - sign * @random_walk_side, else: minor

      {major - sign * @random_walk_side, minor}
    else
      {major, minor}
    end
  end

  defp swap({a, b}), do: {b, a}

  # The time to walk the current path: the walk speed per step, 14/10 of it
  # for a diagonal step.
  defp walk_path_time(%MobState{walk_path: path, walk_speed: speed} = state) do
    [{state.x, state.y} | path]
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.reduce(0, fn [{x1, y1}, {x2, y2}], acc ->
      if x1 != x2 and y1 != y2, do: acc + div(speed * 14, 10), else: acc + speed
    end)
  end

  # Starts a walk to `{x, y}` in the session (the think runs there); `{:ok,
  # state}` when the mob is walking afterwards.
  defp start_walk(%MobState{} = state, x, y) do
    {:noreply, state} = MovementHandler.handle_move_to(state, x, y)
    if walking?(state), do: {:ok, state}, else: {:error, state}
  end

  defp stop_walk(%MobState{movement_state: :moving} = state) do
    HitStop.cancel(state.pending_step)
    state = MobState.stop_movement(%{state | chase_target: nil})
    Movement.set_position(:mob, state.instance_id, state, state.map_name)
    state
  end

  defp stop_walk(state), do: %{state | chase_target: nil}

  @doc """
  Attacks `target_ref` once if it is in attack range, without changing the
  mob's target (an attack order such as Poison React's counter); the mob
  enters its attack state.
  """
  @spec attack_once(MobState.t(), Ref.t()) :: MobState.t()
  def attack_once(%MobState{} = state, target_ref) do
    if target_in_attack_range?(state, target_ref),
      do: state |> order_attack(target_ref, System.system_time(:millisecond)) |> elem(0),
      else: state
  end

  # Swings at the target: an intercepted swing (a target status caught it,
  # dealing no damage) still advances the attack cadence, rests the AI for the
  # attack motion and re-arms the attack timer; a refused one drops the timer.
  defp execute_mob_attack(state, target_ref, now) do
    case Combat.execute_mob_attack(state, target_ref) do
      result when result in [:ok, :intercepted] ->
        state = MobState.rest(%{state | last_attack_time: now, last_skill_id: nil}, now)
        MobState.arm_attack_timer(state, attack_ready_at(state))

      {:error, reason} ->
        Logger.debug("Mob #{state.instance_id} attack failed: #{inspect(reason)}")
        %{state | attack_timer_at: nil}
    end
  end
end
