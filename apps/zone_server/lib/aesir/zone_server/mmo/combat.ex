defmodule Aesir.ZoneServer.Mmo.Combat do
  @moduledoc """
  Core combat system orchestrating damage calculations and application.
  """

  require Logger

  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Mmo.Combat.AttackValidator
  alias Aesir.ZoneServer.Mmo.Combat.DamageApplication
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.EquipBreak
  alias Aesir.ZoneServer.Mmo.Combat.HitCalculations
  alias Aesir.ZoneServer.Mmo.Combat.Knockback
  alias Aesir.ZoneServer.Mmo.Combat.MagicAttack
  alias Aesir.ZoneServer.Mmo.Combat.MiscDamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.PacketFactory
  alias Aesir.ZoneServer.Mmo.Combat.SplashTargets
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Passives
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Broadcast

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
         :ok <- ensure_targetable(target_state, target_type),
         target_combatant <- target_state.__struct__.to_combatant(target_state),
         :ok <-
           validate_attack_with_combatants(attacker_combatant, target_combatant,
             projectile?: true
           ),
         {:ok, combat_result} <-
           check_hit_and_calculate_damage_with_combatants(attacker_combatant, target_combatant) do
      resolve_player_attack(
        combat_result,
        player_state,
        target_state,
        attacker_combatant,
        target_combatant,
        target_pid,
        target_type,
        target_id
      )
    end
  end

  @doc """
  Resolves a target's type and authoritative spatial position.

  Player IDs take precedence over mob IDs when they collide.
  """
  defdelegate resolve_target_position(target_id), to: TargetResolver

  defp resolve_player_attack(
         {:miss},
         _player_state,
         _target_state,
         attacker,
         target,
         _target_pid,
         target_type,
         target_id
       ) do
    Logger.debug("Combat: Player #{attacker.unit_id} attack missed #{target_type} #{target_id}")
    broadcast_to_nearby_players(target, PacketFactory.build_miss_packet(attacker, target))
    :ok
  end

  defp resolve_player_attack(
         {:perfect_dodge},
         _player_state,
         _target_state,
         attacker,
         target,
         _target_pid,
         target_type,
         target_id
       ) do
    Logger.debug(
      "Combat: Player #{attacker.unit_id} attack perfect dodged #{target_type} #{target_id}"
    )

    broadcast_to_nearby_players(
      target,
      PacketFactory.build_perfect_dodge_packet(attacker, target)
    )

    :ok
  end

  defp resolve_player_attack(
         {:hit, damage_result},
         _player_state,
         _target_state,
         attacker,
         target,
         target_pid,
         :player,
         target_id
       ) do
    handle_player_attack_hit(damage_result, attacker, target, target_pid, :player, target_id, 1)
    :ok
  end

  defp resolve_player_attack(
         {:hit, damage_result},
         player_state,
         target_state,
         attacker,
         target,
         target_pid,
         target_type,
         target_id
       ) do
    with :ok <-
           handle_player_attack_hit(
             damage_result,
             attacker,
             target,
             target_pid,
             target_type,
             target_id,
             attack_hits(player_state)
           ) do
      roll_equipment_breaks(player_state, target_state, target_type, target_pid)
      dispatch_dealt_damage(attacker, target_type, target_id, damage_result)
      :ok
    end
  end

  # Rolls equipment breaks once per confirmed weapon hit (never once per
  # multi-hit) and dispatches each decision to the owning session. `execute_attack`
  # runs inside the attacker's `PlayerSession`, so a `:self` break is a cast to
  # `self()`; a `:target` break goes to `target_pid`. The resolver only emits
  # `:target` decisions for player victims (mob "equipment" never breaks in
  # Renewal), so mob targets receive nothing.
  #
  defp roll_equipment_breaks(player_state, target_state, target_type, target_pid) do
    target_type
    |> break_target(target_state)
    |> maybe_roll(player_state, target_pid)
  end

  defp break_target(:player, target_state), do: {:player, target_state.stats}
  defp break_target(target_type, target_state), do: {target_type, target_state}

  # NOTE: player victims are skipped entirely: `handle_player_attack_hit/7`
  # returns `{:error, :pvp_not_implemented}` and applies no damage, so rolling a
  # break here would silently destroy another player's gear with no hit dealt.
  # The enemy-break wiring (the `{:player, ...}` tuple above and the `:target`
  # dispatch below) stays built but unreachable; whoever implements PvP removes
  # the damage stub in `handle_player_attack_hit/7` AND this gate together.
  defp maybe_roll({:player, _victim_stats}, _player_state, _target_pid), do: :ok

  defp maybe_roll(target, player_state, target_pid) do
    player_state.stats
    |> EquipBreak.resolve(target)
    |> Enum.each(&dispatch_break(&1, target_pid))
  end

  defp dispatch_break({:self, slot}, _target_pid),
    do: GenServer.cast(self(), {:break_equip, break_slot(slot)})

  defp dispatch_break({:target, slot}, target_pid),
    do: GenServer.cast(target_pid, {:break_equip, break_slot(slot)})

  defp break_slot(:weapon), do: :right_hand
  defp break_slot(:armor), do: :armor

  # Fires the attacker's `on_dealt_damage` statuses once per confirmed weapon
  # swing (never per multi-hit), the attacker-side counterpart of the victim's
  # `on_damage`. Sited after the damage casts, the attack broadcast and the
  # break roll, so every effect of the triggering hit is already queued on the
  # victim's mailbox ahead of anything an auto-cast sends it.
  #
  # Skill units are excluded: they are not living targets and hold no state a
  # proc could act on (rAthena procs autospell against `bl` units only).
  defp dispatch_dealt_damage(_attacker, :skill_unit, _target_id, _damage_result), do: :ok

  defp dispatch_dealt_damage(attacker, target_type, target_id, damage_result) do
    hit_info = %{
      target: {target_type, target_id},
      damage: damage_result.damage,
      element: attacker.weapon.element
    }

    :player
    |> StatusInterpreter.on_dealt_damage(attacker.unit_id, hit_info)
    |> Enum.each(&drain_auto_cast/1)
  end

  # `execute_attack/3` runs inside the attacker's own `PlayerSession`, so the
  # auto-cast is a cast to `self()` (like a `:self` equipment break): it runs
  # after the current message finishes, on state the session has already
  # committed. `SC_AUTOSPELL` is the only producer today; the session's
  # `{:auto_cast, ...}` handler routes it to the interpreter's restricted entry.
  #
  # This is also why the proc cannot recurse: the bolt it casts is magic, and
  # only the weapon-attack path above ever reaches `dispatch_dealt_damage/4`.
  defp drain_auto_cast({:auto_cast, skill_name, level, target}) do
    case Catalog.by_name(skill_name) do
      {:ok, definition} ->
        GenServer.cast(self(), {:auto_cast, definition.id, level, target})

      :error ->
        raise "auto-cast of unknown skill #{inspect(skill_name)} at level #{level}: " <>
                "a status named a skill absent from the catalog"
    end
  end

  # The number of basic-attack hits to deliver, driven by passive procs (e.g.
  # Double Attack's `%{multi_hit: 2, chance: 7 * level}`). The proc's `:chance`
  # (default 100 when absent) is rolled out of 100 before the multi-hit is
  # delivered; a failed roll (or no proc) delivers a single hit.
  defp attack_hits(player_state) do
    case Passives.attack_procs(player_state) do
      %{multi_hit: n} = proc when n > 1 ->
        chance = Map.get(proc, :chance, 100)
        if :rand.uniform(100) <= chance, do: n, else: 1

      _ ->
        1
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
        hit_info = %{
          dmg_type: :physical,
          is_short: true,
          element: attacker_combatant.weapon.element,
          skill_id: nil,
          skill_level: nil,
          from_caster?: true
        }

        Enum.each(1..hits//1, fn _ ->
          apply_unit_damage(
            :mob,
            target_pid,
            target_id,
            damage,
            hit_info,
            attacker_combatant.unit_id
          )
        end)

        broadcast_basic_attack(attacker_combatant, target_combatant, damage_result, hits)

      :player ->
        Logger.warning("PvP combat not yet implemented")
        {:error, :pvp_not_implemented}

      :skill_unit ->
        apply_skill_unit_target_damage(
          target_pid,
          target_id,
          damage,
          attacker_combatant.unit_id,
          attacker_combatant,
          target_combatant,
          damage_result
        )
    end
  end

  defp broadcast_basic_attack(attacker, target, damage_result, hits) do
    broadcast_to_nearby_players(
      target,
      PacketFactory.build_attack_packet(attacker, target, damage_result, hits)
    )

    :ok
  end

  defp apply_skill_unit_target_damage(
         manager_pid,
         target_id,
         damage,
         attacker_id,
         attacker,
         target,
         damage_result
       ) do
    with :ok <-
           apply_skill_unit_target_damage(manager_pid, target_id, damage, {:player, attacker_id}) do
      broadcast_skill_unit_attack(attacker, target, damage_result)
    end
  end

  defp apply_skill_unit_target_damage(manager_pid, target_id, damage, source),
    do: DamageApplication.damage_skill_unit(manager_pid, target_id, damage, source)

  defp broadcast_skill_unit_attack(attacker, target, damage_result) do
    packet = PacketFactory.build_attack_packet(attacker, target, damage_result)
    broadcast_to_nearby_players(target, packet)
  end

  @doc """
  Deals damage to a target entity (used by status effects).

  See `Aesir.ZoneServer.Mmo.Combat.MagicAttack.deal_damage/4`.
  """
  defdelegate deal_damage(target_id, damage, element \\ :neutral, source_type \\ :status_effect),
    to: MagicAttack

  @doc """
  Broadcasts a heal to a player session via PubSub.

  An offline player (no subscriber) is a silent no-op. Mobs are never healed;
  for undead/demon targets use the damage path instead.
  """
  defdelegate apply_heal(target_id, amount, source_id \\ nil), to: DamageApplication

  @doc """
  Applies an explicit damage amount as a single magic hit of the given element,
  bypassing MATK and MDEF.

  See `Aesir.ZoneServer.Mmo.Combat.MagicAttack.execute_magic_damage/4`.
  """
  defdelegate execute_magic_damage(caster_state, target_id, amount, opts), to: MagicAttack

  @doc """
  Resolves a unit id to its combatant struct.

  Wraps the unit-state lookup so callers outside this module (e.g. ground
  skill-units resolving their caster once per tick) can build a `Combatant` without
  knowing how players and mobs are stored. Returns `{:error, reason}` when the unit
  is gone (logged out, despawned), so the caller can skip cleanly.
  """
  defdelegate resolve_combatant(unit_id), to: TargetResolver

  @doc """
  Computes and applies a single magic skill-unit hit, broadcasting its visual.

  See `Aesir.ZoneServer.Mmo.Combat.MagicAttack.apply_skill_unit_damage/7`.
  """
  defdelegate apply_skill_unit_damage(
                caster,
                unit_type,
                target_id,
                skill_id,
                skill_level,
                element,
                skill_ratio
              ),
              to: MagicAttack

  @doc """
  Applies a magic ground-unit hit with optional multi-hit, flat-MATK, and target
  walk-delay traits.

  See `Aesir.ZoneServer.Mmo.Combat.MagicAttack.apply_skill_unit_damage/8`.
  """
  defdelegate apply_skill_unit_damage(
                caster,
                unit_type,
                target_id,
                skill_id,
                skill_level,
                element,
                skill_ratio,
                opts_or_divisions
              ),
              to: MagicAttack

  @doc """
  Executes a direct single-target magic skill from a caster against a target.

  See `Aesir.ZoneServer.Mmo.Combat.MagicAttack.execute_magic_attack/3`.
  """
  defdelegate execute_magic_attack(caster_state, target_id, opts), to: MagicAttack

  @doc """
  Executes a center+radius magic splash against every offensive target in range.

  See `Aesir.ZoneServer.Mmo.Combat.MagicAttack.execute_magic_splash/4`.
  """
  defdelegate execute_magic_splash(caster_state, center, radius, opts), to: MagicAttack

  @doc """
  Executes a single-target BF_MISC skill (trap) from a caster against a target.

  Routes the caller-supplied `:base_damage` through `MiscDamageCalculator`
  (element + hard-DEF, soft-DEF/MDEF ignored), broadcasts a `ZC_NOTIFY_SKILL`
  packet, then applies the misc damage. Unlike the magic path there is no
  caster-target range check: a trap fires on contact regardless of where its
  owner stands. Hostility (owner/ally exclusion) is decided by the trap's
  `on_touch` before this is called.

  ## Options
    - `:skill_id` / `:skill_level` - identify the skill for the damage packet
    - `:base_damage` - the skill's per-level base damage (required)
    - `:element` - the skill's attack element (default `:neutral`)
  """
  @spec execute_misc_attack(struct(), integer(), keyword()) :: :ok | {:error, atom()}
  def execute_misc_attack(caster_state, target_id, opts) do
    attacker = caster_state.__struct__.to_combatant(caster_state)
    skill_id = Keyword.fetch!(opts, :skill_id)
    skill_level = Keyword.fetch!(opts, :skill_level)
    base_damage = Keyword.fetch!(opts, :base_damage)
    element = Keyword.get(opts, :element, :neutral)

    with {:ok, target_pid, target_state, target_type} <- get_target_unit_state(target_id),
         :ok <- ensure_targetable(target_state, target_type),
         target <- target_state.__struct__.to_combatant(target_state),
         :ok <- Targeting.validate_enemy(attacker, target),
         {:ok, %{damage: damage}} <-
           MiscDamageCalculator.calculate_misc_damage(attacker, target,
             base_damage: base_damage,
             element: element
           ) do
      {tx, ty} = target.position

      packet =
        PacketFactory.build_splash_damage_packet(
          attacker.unit_id,
          target_id,
          skill_id,
          skill_level,
          damage
        )

      Broadcast.to_in_range(target.map_name, tx, ty, Config.view_range(), packet)

      hit_info = %{
        dmg_type: :misc,
        is_short: false,
        element: element,
        skill_id: skill_id,
        skill_level: skill_level
      }

      apply_unit_damage(target_type, target_pid, target_id, damage, hit_info, attacker.unit_id)
      :ok
    end
  end

  @doc """
  Executes a center+radius BF_MISC splash (Blast Mine) against every offensive
  target in range.

  Mirrors `execute_magic_splash/4` but routes each target through
  `MiscDamageCalculator` with the caller-supplied `:base_damage`. Returns the
  list of hit target ids.

  ## Options
    - `:skill_id` / `:skill_level` - identify the skill for the damage packet
    - `:base_damage` - the skill's per-level base damage (required)
    - `:element` - the skill's attack element (default `:neutral`)
  """
  @spec execute_misc_splash(struct(), {integer(), integer()}, non_neg_integer(), keyword()) ::
          [integer()]
  def execute_misc_splash(caster_state, center, radius, opts) do
    attacker = caster_state.__struct__.to_combatant(caster_state)
    skill_id = Keyword.fetch!(opts, :skill_id)
    skill_level = Keyword.fetch!(opts, :skill_level)
    base_damage = Keyword.fetch!(opts, :base_damage)
    element = Keyword.get(opts, :element, :neutral)

    targets = splash_targets(attacker.map_name, center, radius, attacker)

    Enum.flat_map(targets, fn {_unit_type, target_id} ->
      apply_misc_splash_hit(attacker, target_id, skill_id, skill_level, element, base_damage)
    end)
  end

  defp apply_misc_splash_hit(attacker, target_id, skill_id, skill_level, element, base_damage) do
    with {:ok, target_pid, target_state, target_type} <- get_target_unit_state(target_id),
         :ok <- ensure_targetable(target_state, target_type),
         target <- target_state.__struct__.to_combatant(target_state),
         :ok <- Targeting.validate_enemy(attacker, target),
         {:ok, %{damage: damage}} <-
           MiscDamageCalculator.calculate_misc_damage(attacker, target,
             base_damage: base_damage,
             element: element
           ) do
      {tx, ty} = target.position

      packet =
        PacketFactory.build_splash_damage_packet(
          attacker.unit_id,
          target_id,
          skill_id,
          skill_level,
          damage
        )

      Broadcast.to_in_range(target.map_name, tx, ty, Config.view_range(), packet)

      hit_info = %{
        dmg_type: :misc,
        is_short: false,
        element: element,
        skill_id: skill_id,
        skill_level: skill_level
      }

      apply_unit_damage(target_type, target_pid, target_id, damage, hit_info, attacker.unit_id)
      [target_id]
    else
      _ -> []
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
    - `:hit_count` - number of hits to deliver, each rolling its own damage (default `1`)
    - `:element` - forces the attack element for this hit, overriding the
      weapon element (e.g. Envenom's poison, Sand Attack's earth)

  ## Returns
    - :ok if the skill connected
    - {:error, reason} if the target was invalid, friendly, dead, or out of range
  """
  @spec execute_skill_attack(struct(), integer(), keyword()) :: :ok | {:error, atom()}
  def execute_skill_attack(caster_state, target_id, opts) do
    attacker = caster_state.__struct__.to_combatant(caster_state)
    skill_id = Keyword.fetch!(opts, :skill_id)
    skill_level = Keyword.fetch!(opts, :skill_level)
    hits = Keyword.get(opts, :hit_count, 1)

    calc_opts =
      Keyword.take(opts, [:skill_ratio, :skip_crit, :bonus_atk, :fixed_damage, :element])

    # NOTE: skills always connect here; skill miss/flee isn't modeled yet.
    with {:ok, target_pid, target_state, target_type} <- get_target_unit_state(target_id),
         :ok <- ensure_targetable(target_state, target_type),
         target <- target_state.__struct__.to_combatant(target_state),
         :ok <- validate_attack_with_combatants(attacker, target, projectile?: true),
         :ok <- Targeting.validate_enemy(attacker, target) do
      Enum.each(1..hits//1, fn _ ->
        apply_skill_damage(
          attacker,
          target_type,
          target_pid,
          target,
          skill_id,
          skill_level,
          calc_opts
        )
      end)

      :ok
    end
  end

  @doc """
  Executes a self/ground-centered splash skill against every offensive target in
  `radius` cells of `{x, y}`.

  Resolves units via the spatial index, filters to living enemies (excluding
  the caster and same-party/guild players), then runs each through the shared
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
    |> splash_targets(center, radius, attacker)
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

  See `Aesir.ZoneServer.Mmo.Combat.SplashTargets.select/4`.
  """
  defdelegate splash_targets(map_name, center, radius, caster), to: SplashTargets, as: :select

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

      hit_info = %{
        dmg_type: :physical,
        is_short: attacker.attack_range <= 3,
        element: :neutral,
        skill_id: skill_id,
        skill_level: skill_level
      }

      apply_unit_damage(
        target_type,
        target_pid,
        target.unit_id,
        damage_result.damage,
        hit_info,
        attacker.unit_id
      )

      :ok
    end
  end

  # Transitional wrappers over DamageApplication; removed as the attack paths
  # move into their own modules.
  defp apply_unit_damage(target_type, target_pid, target_id, damage, hit_info, attacker_id),
    do:
      DamageApplication.apply_unit_damage(
        target_type,
        target_pid,
        target_id,
        damage,
        hit_info,
        attacker_id
      )

  @doc """
  Knocks a unit back away from `{from_x, from_y}`, collision-aware.

  See `Aesir.ZoneServer.Mmo.Combat.Knockback.knockback/5`.
  """
  defdelegate knockback(unit_type, unit_id, from_x, from_y, distance), to: Knockback

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

    # NOTE: no equipment-break roll on the mob path — mob attackers carry no break
    # bonuses and natural break is player-only; this is the future hook for
    # mob-skill-driven breaks (rAthena `skill_break_equip`) once those exist.
    hit_info = %{
      dmg_type: :physical,
      is_short: attacker_combatant.attack_range <= 3,
      element: attacker_combatant.weapon.element,
      skill_id: nil,
      skill_level: nil,
      from_caster?: true
    }

    apply_unit_damage(
      :player,
      target_pid,
      target_id,
      damage,
      hit_info,
      attacker_combatant.unit_id
    )
  end

  # Transitional wrappers over TargetResolver; removed as the attack paths move
  # into their own modules.
  defp get_target_unit_state(target_id), do: TargetResolver.resolve(target_id)

  defp ensure_targetable(target_state, target_type),
    do: TargetResolver.ensure_targetable(target_state, target_type)

  # Transitional wrappers over AttackValidator; removed as the attack paths move
  # into their own modules.
  defp validate_attack_with_combatants(attacker_combatant, target_combatant, opts),
    do: AttackValidator.validate(attacker_combatant, target_combatant, opts)

  defp validate_mob_attack_with_combatants(attacker_combatant, target_combatant),
    do: AttackValidator.validate_mob_attack(attacker_combatant, target_combatant)

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

  defp broadcast_to_nearby_players(target, packet),
    do: DamageApplication.broadcast_nearby(target, packet)
end
