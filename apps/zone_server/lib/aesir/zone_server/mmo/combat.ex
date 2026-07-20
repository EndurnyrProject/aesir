defmodule Aesir.ZoneServer.Mmo.Combat do
  @moduledoc """
  Facade for the combat system: the stable public API every caller (skills,
  mob AI, status effects, GM commands) goes through.

  The implementation lives in focused submodules:

  - `Combat.AutoAttack` - basic player/mob attacks, multi-hit passives,
    equipment breaks, dealt-damage procs
  - `Combat.MagicAttack` - direct nukes, magic splashes, ground skill-unit
    ticks, status DoT damage
  - `Combat.SkillAttack` - physical (BF_WEAPON) and misc/trap (BF_MISC)
    skill paths
  - `Combat.Knockback` - collision-aware knockback resolution
  - `Combat.TargetResolver` - target id to live unit state/combatant/position
  - `Combat.AttackValidator` - same-map, range, and projectile line-of-sight
    checks
  - `Combat.SplashTargets` - center+radius offensive target selection
  - `Combat.DamageApplication` - absorption hook, session routing, heals,
    combat broadcasts
  """

  alias Aesir.ZoneServer.Mmo.Combat.AutoAttack
  alias Aesir.ZoneServer.Mmo.Combat.DamageApplication
  alias Aesir.ZoneServer.Mmo.Combat.Knockback
  alias Aesir.ZoneServer.Mmo.Combat.MagicAttack
  alias Aesir.ZoneServer.Mmo.Combat.SkillAttack
  alias Aesir.ZoneServer.Mmo.Combat.SplashTargets
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver

  @doc """
  Executes a basic attack from player to target.

  See `Aesir.ZoneServer.Mmo.Combat.AutoAttack.execute_attack/3`.
  """
  defdelegate execute_attack(stats, player_state, target_id), to: AutoAttack

  @doc """
  Executes a basic attack from mob to player.

  See `Aesir.ZoneServer.Mmo.Combat.AutoAttack.execute_mob_attack/2`.
  """
  defdelegate execute_mob_attack(mob_state, target_id), to: AutoAttack

  @doc """
  Executes a single-target offensive skill from a caster against a target.

  See `Aesir.ZoneServer.Mmo.Combat.SkillAttack.execute_skill_attack/3`.
  """
  defdelegate execute_skill_attack(caster_state, target_id, opts), to: SkillAttack

  @doc """
  Executes a self/ground-centered splash skill against every offensive target
  in range.

  See `Aesir.ZoneServer.Mmo.Combat.SkillAttack.execute_splash_attack/4`.
  """
  defdelegate execute_splash_attack(caster_state, center, radius, opts), to: SkillAttack

  @doc """
  Executes a single-target BF_MISC skill (trap) from a caster against a target.

  See `Aesir.ZoneServer.Mmo.Combat.SkillAttack.execute_misc_attack/3`.
  """
  defdelegate execute_misc_attack(caster_state, target_id, opts), to: SkillAttack

  @doc """
  Executes a center+radius BF_MISC splash (Blast Mine) against every offensive
  target in range.

  See `Aesir.ZoneServer.Mmo.Combat.SkillAttack.execute_misc_splash/4`.
  """
  defdelegate execute_misc_splash(caster_state, center, radius, opts), to: SkillAttack

  @doc """
  Executes a direct single-target magic skill from a caster against a target.

  See `Aesir.ZoneServer.Mmo.Combat.MagicAttack.execute_magic_attack/3`.
  """
  defdelegate execute_magic_attack(caster_state, target_id, opts), to: MagicAttack

  @doc """
  Applies an explicit damage amount as a single magic hit of the given element,
  bypassing MATK and MDEF.

  See `Aesir.ZoneServer.Mmo.Combat.MagicAttack.execute_magic_damage/4`.
  """
  defdelegate execute_magic_damage(caster_state, target_id, amount, opts), to: MagicAttack

  @doc """
  Executes a center+radius magic splash against every offensive target in range.

  See `Aesir.ZoneServer.Mmo.Combat.MagicAttack.execute_magic_splash/4`.
  """
  defdelegate execute_magic_splash(caster_state, center, radius, opts), to: MagicAttack

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
  Deals damage to a target entity (used by status effects).

  See `Aesir.ZoneServer.Mmo.Combat.MagicAttack.deal_damage/4`.
  """
  defdelegate deal_damage(target_id, damage, element \\ :neutral, source_type \\ :status_effect),
    to: MagicAttack

  @doc """
  Broadcasts a heal to a player session via PubSub.

  See `Aesir.ZoneServer.Mmo.Combat.DamageApplication.apply_heal/3`.
  """
  defdelegate apply_heal(target_id, amount, source_id \\ nil), to: DamageApplication

  @doc """
  Knocks a unit back away from `{from_x, from_y}`, collision-aware.

  See `Aesir.ZoneServer.Mmo.Combat.Knockback.knockback/5`.
  """
  defdelegate knockback(unit_type, unit_id, from_x, from_y, distance), to: Knockback

  @doc """
  Resolves a target's type and authoritative spatial position.

  See `Aesir.ZoneServer.Mmo.Combat.TargetResolver.resolve_target_position/1`.
  """
  defdelegate resolve_target_position(target_id), to: TargetResolver

  @doc """
  Resolves a unit id to its combatant struct.

  See `Aesir.ZoneServer.Mmo.Combat.TargetResolver.resolve_combatant/1`.
  """
  defdelegate resolve_combatant(unit_id), to: TargetResolver

  @doc "Resolves a known unit type and id to its live combatant."
  defdelegate resolve_combatant(unit_type, unit_id), to: TargetResolver

  @doc """
  Selects the valid offensive targets for a center+radius splash/footprint.

  See `Aesir.ZoneServer.Mmo.Combat.SplashTargets.select/4`.
  """
  defdelegate splash_targets(map_name, center, radius, caster), to: SplashTargets, as: :select
end
