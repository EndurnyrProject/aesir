defmodule Aesir.ZoneServer.Mmo.Combat do
  @moduledoc """
  Core combat system orchestrating damage calculations and application.
  """

  require Logger

  alias Aesir.Commons.Utils.ServerTick
  alias Aesir.Net.Knockback
  alias Aesir.Net.SkillDamage
  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.HitCalculations
  alias Aesir.ZoneServer.Mmo.Combat.MagicDamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.PacketFactory
  alias Aesir.ZoneServer.Mmo.Skill.Passives
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Movement
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  # Combat packets broadcast from the victim's position, per rAthena.
  @combat_view_range 14

  # ZC_NOTIFY_SKILL `type` for a splash/area skill hit (e_damage_type DMG_SPLASH).
  @dmg_splash 5

  @doc """
  Executes an attack from player to target.

  Flow:
  1. Validate attack (range, target exists, cooldowns)
  2. Convert unit states to combatants
  3. Check hit/miss and calculate damage
  4. Apply damage to target
  5. Broadcast combat packets
  6. Handle death/rewards if applicable

  ## Parameters
    - player_state: Player state containing all required combat information
    - stats: Player stats from session
    - target_id: ID of the target entity

  ## Returns
    - :ok if attack was successful
    - {:error, reason} if attack failed
  """
  @spec execute_attack(map(), map(), integer()) :: :ok | {:error, atom()}
  def execute_attack(stats, player_state, target_id) do
    # Create player combatant - player_state already implements to_combatant
    # But we need to update the stats first
    player_state = %{player_state | stats: stats}
    attacker_combatant = player_state.__struct__.to_combatant(player_state)

    with {:ok, target_pid, target_state, target_type} <- get_target_unit_state(target_id),
         target_combatant <- target_state.__struct__.to_combatant(target_state),
         :ok <- validate_attack_with_combatants(attacker_combatant, target_combatant),
         {:ok, combat_result} <-
           check_hit_and_calculate_damage_with_combatants(attacker_combatant, target_combatant) do
      case combat_result do
        {:miss} ->
          Logger.debug(
            "Combat: Player #{attacker_combatant.unit_id} attack missed #{target_type} #{target_id}"
          )

          # Broadcast miss packet to nearby players
          miss_packet = PacketFactory.build_miss_packet(attacker_combatant, target_combatant)
          broadcast_to_nearby_players(target_combatant, miss_packet)

        {:perfect_dodge} ->
          Logger.debug(
            "Combat: Player #{attacker_combatant.unit_id} attack perfect dodged by #{target_type} #{target_id}"
          )

          # Broadcast perfect dodge packet to nearby players
          dodge_packet =
            PacketFactory.build_perfect_dodge_packet(attacker_combatant, target_combatant)

          broadcast_to_nearby_players(target_combatant, dodge_packet)

        {:hit, damage_result} ->
          handle_player_attack_hit(
            damage_result,
            attacker_combatant,
            target_combatant,
            target_pid,
            target_type,
            target_id,
            attack_hits(player_state)
          )
      end

      :ok
    end
  end

  # The number of basic-attack hits to deliver, driven by passive procs (e.g.
  # Double Attack's `%{multi_hit: 2}`). Defaults to a single hit.
  defp attack_hits(player_state) do
    case Passives.attack_procs(player_state) do
      %{multi_hit: n} when n > 1 -> n
      _ -> 1
    end
  end

  defp handle_player_attack_hit(
         damage_result,
         attacker_combatant,
         target_combatant,
         target_pid,
         target_type,
         target_id,
         hits
       ) do
    damage = damage_result.damage
    is_critical = damage_result.is_critical

    Logger.debug(
      "Combat: Player #{attacker_combatant.unit_id} attacking #{target_type} #{target_id} for #{damage} damage#{if hits > 1, do: " x#{hits}", else: ""}#{if is_critical, do: " (CRITICAL)", else: ""}"
    )

    case target_type do
      :mob ->
        Enum.each(1..hits//1, fn _ ->
          apply_unit_damage(:mob, target_pid, damage, attacker_combatant.unit_id)
        end)

        :ok

      :player ->
        Logger.warning("PvP combat not yet implemented")
        {:error, :pvp_not_implemented}
    end

    attack_packet =
      PacketFactory.build_attack_packet(
        attacker_combatant,
        target_combatant,
        damage_result,
        hits
      )

    broadcast_to_nearby_players(target_combatant, attack_packet)
  end

  @doc """
  Deals damage to a target entity (used by status effects).

  This is a simplified version of execute_attack that bypasses
  validation and is used by status effects and other systems.
  """
  @spec deal_damage(integer(), integer(), atom(), atom()) :: :ok | {:error, atom()}
  def deal_damage(target_id, damage, element \\ :neutral, source_type \\ :status_effect) do
    with {:ok, target_pid, _target_state, target_type} <- get_target_unit_state(target_id) do
      Logger.debug(
        "Combat: Dealing #{damage} #{element} damage to #{target_type} #{target_id} from #{source_type}"
      )

      apply_unit_damage(target_type, target_pid, damage)
      :ok
    end
  end

  @doc """
  Resolves a unit id to its combatant struct.

  Wraps the internal unit-state lookup so callers outside this module (e.g. ground
  skill-units resolving their caster once per tick) can build a `Combatant` without
  knowing how players and mobs are stored. Returns `{:error, reason}` when the unit
  is gone (logged out, despawned), so the caller can skip cleanly.
  """
  @spec resolve_combatant(integer()) :: {:ok, struct()} | {:error, atom()}
  def resolve_combatant(unit_id) do
    with {:ok, _pid, state, _type} <- get_target_unit_state(unit_id) do
      {:ok, state.__struct__.to_combatant(state)}
    end
  end

  @doc """
  Computes and applies a single magic skill-unit hit, broadcasting its visual.

  Used by magic ground skill-units (e.g. Storm Gust). Resolves the target
  combatant, runs the hit through `MagicDamageCalculator` (real MATK/MDEF/element)
  with the given `skill_ratio` and `element`, broadcasts a `ZC_NOTIFY_SKILL` from
  the target's cell so nearby players see the hit number, then applies the damage.

  ## Parameters
    - `caster` - the casting unit's combatant (`src_id`/MATK source)
    - `unit_type` / `target_id` - the target being hit
    - `skill_id` / `skill_level` - identify the skill for the damage packet
    - `element` - the skill's magic element (element resistance + damage context)
    - `skill_ratio` - percent of base MATK the skill deals this hit
  """
  @spec apply_skill_unit_damage(
          struct(),
          atom(),
          integer(),
          integer(),
          integer(),
          atom(),
          non_neg_integer()
        ) :: :ok | {:error, atom()}
  def apply_skill_unit_damage(
        caster,
        unit_type,
        target_id,
        skill_id,
        skill_level,
        element,
        skill_ratio
      ) do
    with {:ok, target} <- resolve_combatant(target_id),
         {:ok, {tx, ty, map_name}} <- SpatialIndex.get_unit_position(unit_type, target_id),
         {:ok, %{damage: damage}} <-
           MagicDamageCalculator.calculate_magic_damage(caster, target,
             element: element,
             skill_ratio: skill_ratio
           ) do
      packet = %SkillDamage{
        skill_id: skill_id,
        level: skill_level,
        src_id: caster.unit_id,
        target_id: target_id,
        server_tick: ServerTick.now(),
        src_delay: 0,
        dst_delay: 0,
        damage: damage,
        div: 1,
        type: @dmg_splash
      }

      Broadcast.to_in_range(map_name, tx, ty, @combat_view_range, packet)
      deal_damage(target_id, damage, element, :skill_unit)
    end
  end

  @doc """
  Executes a single-target offensive skill from a caster against a target.

  Reuses the melee range check and the unified damage calculator (passing the
  skill's ratio), broadcasts a ZC_NOTIFY_SKILL packet, then applies damage.

  ## Options
    - `:skill_id` / `:skill_level` - identify the skill for the damage packet
    - `:skill_ratio` - percent of base attack the skill deals
    - `:skip_crit` - skip the critical roll (most skills don't crit)
    - `:bonus_atk` - flat ATK added after the skill ratio, before defense
    - `:fixed_damage` - deal exactly this value, bypassing weapon/defense/flee

  ## Returns
    - :ok if the skill connected
    - {:error, reason} if the target was invalid, out of range, or PvP
  """
  @spec execute_skill_attack(struct(), integer(), keyword()) :: :ok | {:error, atom()}
  def execute_skill_attack(caster_state, target_id, opts) do
    attacker = caster_state.__struct__.to_combatant(caster_state)
    skill_id = Keyword.fetch!(opts, :skill_id)
    skill_level = Keyword.fetch!(opts, :skill_level)
    calc_opts = Keyword.take(opts, [:skill_ratio, :skip_crit, :bonus_atk, :fixed_damage])

    # TODO: skills always connect here; skill miss/flee isn't modeled yet.
    with {:ok, target_pid, target_state, target_type} <- get_target_unit_state(target_id),
         target <- target_state.__struct__.to_combatant(target_state),
         :ok <- validate_attack_with_combatants(attacker, target),
         :ok <- ensure_offensive_target(target_type) do
      apply_skill_damage(
        attacker,
        target_type,
        target_pid,
        target,
        skill_id,
        skill_level,
        calc_opts
      )
    end
  end

  @doc """
  Executes a self/ground-centered splash skill against every offensive target in
  `radius` cells of `{x, y}`.

  Resolves units via the spatial index, filters to valid offensive targets
  (mobs only for now, excluding the caster), then runs each through the shared
  single-target damage path **without** the per-target attack-range gate — the
  radius already bounds the hit set. Returns the list of hit target ids, consumed
  by knockback (#6).

  The spatial index filters by Manhattan distance (a diamond), but skill splash
  AoE is a Chebyshev square. We query a Manhattan radius of `2 * radius` so the
  full square is covered (a corner cell at `{radius, radius}` has Manhattan
  `2 * radius`), then post-filter to the Chebyshev square. Dead mobs (hp <= 0)
  are excluded so they receive no phantom damage or broadcast.

  ## Options
    - `:skill_id` / `:skill_level` - identify the skill for the damage packet
    - `:skill_ratio` - percent of base attack the skill deals
    - `:skip_crit` - skip the critical roll
  """
  @spec execute_splash_attack(struct(), {integer(), integer()}, non_neg_integer(), keyword()) ::
          [integer()]
  def execute_splash_attack(caster_state, center, radius, opts) do
    attacker = caster_state.__struct__.to_combatant(caster_state)
    skill_id = Keyword.fetch!(opts, :skill_id)
    skill_level = Keyword.fetch!(opts, :skill_level)
    calc_opts = Keyword.take(opts, [:skill_ratio, :skip_crit])

    attacker.map_name
    |> splash_targets(center, radius, attacker.unit_id)
    |> Enum.flat_map(fn {_unit_type, target_id} ->
      with {:ok, target_pid, target_state, target_type} <- get_target_unit_state(target_id),
           target <- target_state.__struct__.to_combatant(target_state),
           :ok <-
             apply_skill_damage(
               attacker,
               target_type,
               target_pid,
               target,
               skill_id,
               skill_level,
               calc_opts
             ) do
        [target_id]
      else
        _ -> []
      end
    end)
  end

  @doc """
  Selects the valid offensive targets for a center+radius splash/footprint.

  Returns the `{unit_type, unit_id}` units that are in the Chebyshev square of
  `radius` cells around `{cx, cy}`, are offensive (mobs only for now, excluding
  the caster and allies), and are alive (`hp > 0`). Shared by `execute_splash_attack`
  and ground skill-unit behaviours (e.g. Storm Gust) so the target filter — including
  the dead-mob guard — lives in one place.

  The spatial index filters by Manhattan distance (a diamond); we query a Manhattan
  radius of `2 * radius` so the full Chebyshev square is covered, then post-filter.
  """
  @spec splash_targets(String.t(), {integer(), integer()}, non_neg_integer(), integer()) ::
          [{atom(), integer()}]
  def splash_targets(map_name, {cx, cy}, radius, _caster_id) do
    map_name
    |> SpatialIndex.get_all_units_in_range(cx, cy, radius * 2)
    |> Enum.filter(fn {_unit_type, target_id} = unit ->
      splash_target?(unit) and offensive_target_in_square?(target_id, cx, cy, radius)
    end)
  end

  defp offensive_target_in_square?(target_id, cx, cy, radius) do
    case get_target_unit_state(target_id) do
      {:ok, _pid, target_state, _type} -> splash_hit?(target_state, cx, cy, radius)
      _ -> false
    end
  end

  # Mobs only for now; the caster (a player) is excluded by type, and PvP splash
  # is deferred with PvP single-target.
  defp splash_target?({:mob, _id}), do: true
  defp splash_target?({:player, _id}), do: false

  # Keeps the square (Chebyshev) AoE shape and drops dead mobs awaiting despawn.
  defp splash_hit?(%{hp: hp}, _x, _y, _radius) when hp <= 0, do: false

  defp splash_hit?(%{x: tx, y: ty}, x, y, radius),
    do: Geometry.chebyshev_distance(x, y, tx, ty) <= radius

  defp apply_skill_damage(
         attacker,
         target_type,
         target_pid,
         target,
         skill_id,
         skill_level,
         calc_opts
       ) do
    with {:ok, damage_result} <- DamageCalculator.calculate_damage(attacker, target, calc_opts) do
      packet =
        PacketFactory.build_skill_damage_packet(
          attacker,
          target,
          skill_id,
          skill_level,
          damage_result
        )

      broadcast_to_nearby_players(target, packet)

      apply_unit_damage(target_type, target_pid, damage_result.damage, attacker.unit_id)
      :ok
    end
  end

  defp ensure_offensive_target(:mob), do: :ok
  defp ensure_offensive_target(:player), do: {:error, :pvp_not_implemented}

  # Routes damage to the owning session by unit type, keeping the damage paths
  # free of concrete session-module knowledge.
  defp apply_unit_damage(target_type, target_pid, damage, attacker_id \\ nil) do
    unit_session(target_type).apply_damage(target_pid, damage, attacker_id)
  end

  defp unit_session(:mob), do: MobSession
  defp unit_session(:player), do: PlayerSession

  @doc """
  Knocks a unit back away from `{from_x, from_y}`, collision-aware.

  Walks the unit outward one cell at a time (8-dir, away from the source through
  its current cell) up to `distance` cells, stopping at the last walkable cell
  before a wall (rAthena `unit_blown`). Updates the unit state, the spatial index
  and the registry, then broadcasts `Knockback` to nearby players so they slide
  the unit to its landing cell.

  Returns `{:ok, {dst_x, dst_y}}` with the final cell (unchanged if it could not
  move), or `{:error, reason}` if the unit or its map could not be resolved.
  """
  @spec knockback(atom(), integer(), integer(), integer(), non_neg_integer()) ::
          {:ok, {integer(), integer()}} | {:error, atom()}
  def knockback(unit_type, unit_id, from_x, from_y, distance) do
    with {:ok, {x, y, map_name}} <- SpatialIndex.get_unit_position(unit_type, unit_id),
         {:ok, map} <- MapCache.get(map_name) do
      {dx, dy} = {sign(x - from_x), sign(y - from_y)}
      {dst_x, dst_y} = blow_path(map, x, y, dx, dy, distance)

      if {dst_x, dst_y} != {x, y} do
        move_unit(unit_type, unit_id, dst_x, dst_y, map_name)
        broadcast_blownback(unit_id, dst_x, dst_y, map_name)
      end

      {:ok, {dst_x, dst_y}}
    end
  end

  defp sign(n) when n > 0, do: 1
  defp sign(n) when n < 0, do: -1
  defp sign(_), do: 0

  # No direction (unit on top of source): nowhere to blow.
  defp blow_path(_map, x, y, 0, 0, _distance), do: {x, y}

  # Step outward, keeping the last walkable cell reached.
  defp blow_path(map, x, y, dx, dy, distance) do
    Enum.reduce_while(1..distance//1, {x, y}, fn _step, {cx, cy} ->
      {nx, ny} = {cx + dx, cy + dy}

      if MapData.walkable?(map, nx, ny) do
        {:cont, {nx, ny}}
      else
        {:halt, {cx, cy}}
      end
    end)
  end

  # Routes the landing-cell update through the owning session so it is the single
  # writer: the session updates its live `game_state` (position + stop walking)
  # and re-syncs the spatial index/registry/dirty set via `Movement.set_position`,
  # which prevents a knocked-back moving unit's own next tick from overwriting the
  # blow. Falls back to a direct write when the owning process can't be resolved.
  defp move_unit(unit_type, unit_id, x, y, map_name) do
    case owning_pid(unit_type, unit_id) do
      {:ok, pid} -> GenServer.cast(pid, {:knocked_back, x, y})
      :error -> move_unit_direct(unit_type, unit_id, x, y, map_name)
    end
  end

  defp owning_pid(unit_type, unit_id) do
    case UnitRegistry.get_unit(unit_type, unit_id) do
      {:ok, {_module, _state, pid}} when is_pid(pid) -> {:ok, pid}
      _ -> :error
    end
  end

  defp move_unit_direct(unit_type, unit_id, x, y, map_name) do
    with {:ok, {module, state, _pid}} <- UnitRegistry.get_unit(unit_type, unit_id) do
      UnitRegistry.update_unit_state(unit_type, unit_id, module.update_position(state, x, y))
    end

    SpatialIndex.update_unit_position(unit_type, unit_id, x, y, map_name)
    Movement.mark_dirty(map_name, unit_type, unit_id, 0)
  end

  defp broadcast_blownback(unit_id, dst_x, dst_y, map_name) do
    packet = %Knockback{unit_id: unit_id, dst_x: dst_x, dst_y: dst_y}
    Broadcast.to_in_range(map_name, dst_x, dst_y, @combat_view_range, packet)
  end

  @doc """
  Executes an attack from mob to player.

  Flow:
  1. Validate attack (range, target exists, cooldowns)
  2. Convert unit states to combatants
  3. Check hit/miss and calculate damage
  4. Apply damage to player
  5. Broadcast combat packets

  ## Parameters
    - mob_state: Mob state containing all required combat information
    - target_id: ID of the target player

  ## Returns
    - :ok if attack was successful
    - {:error, reason} if attack failed
  """
  @spec execute_mob_attack(map(), integer()) :: :ok | {:error, atom()}
  def execute_mob_attack(mob_state, target_id) do
    # Convert mob state to combatant
    attacker_combatant = mob_state.__struct__.to_combatant(mob_state)

    with {:ok, target_pid, target_state, :player} <- get_target_unit_state(target_id),
         target_combatant <- target_state.__struct__.to_combatant(target_state),
         :ok <- validate_mob_attack_with_combatants(attacker_combatant, target_combatant),
         {:ok, combat_result} <-
           check_hit_and_calculate_damage_with_combatants(attacker_combatant, target_combatant) do
      case combat_result do
        {:miss} ->
          Logger.debug(
            "Combat: Mob #{attacker_combatant.unit_id} attack missed player #{target_id}"
          )

          # Broadcast miss packet to nearby players
          miss_packet = PacketFactory.build_miss_packet(attacker_combatant, target_combatant)
          broadcast_to_nearby_players(target_combatant, miss_packet)

        {:perfect_dodge} ->
          Logger.debug(
            "Combat: Mob #{attacker_combatant.unit_id} attack perfect dodged by player #{target_id}"
          )

          # Broadcast perfect dodge packet to nearby players
          dodge_packet =
            PacketFactory.build_perfect_dodge_packet(attacker_combatant, target_combatant)

          broadcast_to_nearby_players(target_combatant, dodge_packet)

        {:hit, damage_result} ->
          handle_mob_attack_hit(
            damage_result,
            attacker_combatant,
            target_combatant,
            target_pid,
            target_id
          )
      end

      :ok
    end
  end

  defp handle_mob_attack_hit(
         damage_result,
         attacker_combatant,
         target_combatant,
         target_pid,
         target_id
       ) do
    damage = damage_result.damage
    is_critical = damage_result.is_critical

    Logger.debug(
      "Combat: Mob #{attacker_combatant.unit_id} attacking player #{target_id} for #{damage} damage#{if is_critical, do: " (CRITICAL)", else: ""}"
    )

    # Show the hit animation/damage number first, then apply HP loss so the
    # SP_HP update (and any death) follows the visible strike.
    attack_packet =
      PacketFactory.build_attack_packet(attacker_combatant, target_combatant, damage_result)

    broadcast_to_nearby_players(target_combatant, attack_packet)

    PlayerSession.apply_damage(target_pid, damage, attacker_combatant.unit_id)
  end

  # New function that returns actual unit states instead of maps
  defp get_target_unit_state(target_id) do
    case get_mob_unit_state(target_id) do
      {:ok, pid, mob_state, :mob} -> {:ok, pid, mob_state, :mob}
      {:error, :not_found} -> get_player_unit_state(target_id)
      {:error, :target_no_pid} -> {:error, :target_no_pid}
    end
  end

  defp get_mob_unit_state(target_id) do
    case UnitRegistry.get_unit(:mob, target_id) do
      {:ok, {_module, mob_state, pid}} when is_pid(pid) ->
        # Get the current position from SpatialIndex for consistency
        updated_mob_state =
          case SpatialIndex.get_unit_position(:mob, target_id) do
            {:ok, {x, y, _map}} ->
              %{mob_state | x: x, y: y}

            _ ->
              mob_state
          end

        {:ok, pid, updated_mob_state, :mob}

      {:error, :not_found} ->
        Logger.warning("Mob #{target_id} not found in registry")
        {:error, :not_found}

      {:ok, {_module, _state, nil}} ->
        Logger.warning("Mob #{target_id} found but has no pid")
        {:error, :target_no_pid}
    end
  end

  defp get_player_unit_state(target_id) do
    case UnitRegistry.get_player_pid(target_id) do
      {:ok, pid} ->
        stats = PlayerSession.get_current_stats(pid)
        session_state = PlayerSession.get_state(pid)
        # Extract the game_state which is the actual PlayerState
        player_state = session_state.game_state
        # Update player state with current stats for combat
        player_state = %{player_state | stats: stats}
        {:ok, pid, player_state, :player}

      {:error, :not_found} ->
        Logger.warning("Target #{target_id} not found in registry")
        {:error, :target_not_found}
    end
  end

  # New combatant-based functions
  defp validate_attack_with_combatants(attacker_combatant, target_combatant) do
    # Validate attack range using combatant positions for players
    attack_range = attacker_combatant.attack_range
    {attacker_x, attacker_y} = attacker_combatant.position
    {target_x, target_y} = target_combatant.position

    distance = Geometry.chebyshev_distance(attacker_x, attacker_y, target_x, target_y)

    if distance <= attack_range do
      :ok
    else
      Logger.debug(
        "Attack failed: target out of range (distance: #{distance}, max: #{attack_range})"
      )

      {:error, :target_out_of_range}
    end
  end

  defp validate_mob_attack_with_combatants(attacker_combatant, target_combatant) do
    # Validate mob attack range using combatant positions
    # Get attack range from the mob data via the combatant
    attack_range = attacker_combatant.attack_range
    {attacker_x, attacker_y} = attacker_combatant.position
    {target_x, target_y} = target_combatant.position

    distance = Geometry.chebyshev_distance(attacker_x, attacker_y, target_x, target_y)

    if distance <= attack_range do
      :ok
    else
      Logger.debug(
        "Mob attack failed: target out of range (distance: #{distance}, max: #{attack_range})"
      )

      {:error, :target_out_of_range}
    end
  end

  defp check_hit_and_calculate_damage_with_combatants(attacker_combatant, defender_combatant) do
    # Convert combatants to format expected by HitCalculations
    attacker_stats = %{
      hit: attacker_combatant.combat_stats.hit,
      char_id: attacker_combatant.unit_id
    }

    defender_stats = %{
      flee: defender_combatant.combat_stats.flee,
      perfect_dodge: defender_combatant.combat_stats.perfect_dodge,
      unit_id: defender_combatant.unit_id
    }

    case HitCalculations.calculate_hit_result(attacker_stats, defender_stats) do
      :hit ->
        # Calculate damage using the new DamageCalculator
        case DamageCalculator.calculate_damage(attacker_combatant, defender_combatant) do
          {:ok, damage_result} -> {:ok, {:hit, damage_result}}
          {:error, reason} -> {:error, reason}
        end

      :miss ->
        {:ok, {:miss}}

      :perfect_dodge ->
        {:ok, {:perfect_dodge}}
    end
  end

  # Broadcasts a combat packet to players near the target. Works for both
  # combatant structs and map-based target stats (both carry position/map_name).
  defp broadcast_to_nearby_players(target, packet) do
    {x, y} = target.position
    Broadcast.to_in_range(target.map_name, x, y, @combat_view_range, packet)
  end
end
