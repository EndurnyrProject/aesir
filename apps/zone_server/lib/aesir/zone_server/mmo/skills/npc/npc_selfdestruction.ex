defmodule Aesir.ZoneServer.Mmo.Skills.Npc.NpcSelfdestruction do
  @moduledoc """
  NPC Self Destruction (NPC_SELFDESTRUCTION).

  The caster blows itself up: every unit and trap it can see within five cells
  takes the caster's current HP as Fire misc damage (the shared misc tail: no
  target cards, the skill rates and each target's element; it never misses), a
  hidden one is skipped, and a survivor is knocked back three cells. The caster
  then loses all of its HP without a hit, so it dies with no killer and a
  monster still drops its items and grants its experience.

  Who is struck depends on the caster. A monster's blast reaches every unit,
  other monsters included, except a Marine Sphere's off versus ground. A
  Marine Sphere (off versus ground) and a player (off versus ground) strike the
  player's enemies plus the player's own Homunculus and summons; another
  player's summons are no enemies there. On a versus map both strike every unit.
  A summon's damage counts for its owner.

  Renewal and pre-renewal agree, at all ten levels.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 173,
    name: :npc_selfdestruction,
    requires: [],
    display_name: "NPC Self Destruction",
    max_level: 10,
    target_type: :self,
    damage_type: :damage,
    ignore_def_card: true,
    ignore_flee: true,
    damage_kind: :misc,
    element: :fire,
    range: 0,
    knockback: 3,
    splash_radius: 5,
    is_npc: true,
    damage_splash: true

  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.SkillAttack
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active

  @impl Active
  def cast(caster, _target, level, definition)
      when is_struct(caster, MobState) or is_struct(caster, PlayerState) do
    hp = current_hp(caster)

    SkillAttack.execute_misc_splash(
      caster,
      {caster.x, caster.y},
      definition.splash_radius,
      skill_id: definition.id,
      skill_level: level,
      base_damage: hp,
      element: definition.element,
      target_skill_units: true,
      shoot_range_los: true,
      authorize: target_rule(caster),
      damage_source: damage_source(caster),
      base_distance: definition.knockback,
      native_requires_survival: true
    )

    zap(caster, hp)
    {:ok, caster}
  end

  defp current_hp(%MobState{hp: hp}), do: hp
  defp current_hp(%PlayerState{stats: %{current_state: %{hp: hp}}}), do: hp

  # Everyone on versus ground; elsewhere a player or a Marine Sphere strikes the
  # player's enemies and own summons, and any other monster strikes everyone.
  defp target_rule(%PlayerState{character_id: owner_id, map_name: map_name}) do
    if MapFlags.versus?(map_name),
      do: &everyone/2,
      else: fn attacker, target -> enemy_or_own_summon?(attacker, target, owner_id) end
  end

  defp target_rule(%MobState{summon_kind: :sphere, owner_player_id: owner_id} = caster)
       when is_integer(owner_id) do
    if MapFlags.versus?(caster.map_name) do
      &everyone/2
    else
      owner = owner_combatant(owner_id)
      fn _attacker, target -> enemy_or_own_summon?(owner, target, owner_id) end
    end
  end

  defp target_rule(%MobState{}), do: &everyone/2

  defp everyone(_attacker, target), do: not hiding?(target)

  defp enemy_or_own_summon?(relation, target, owner_id) do
    not hiding?(target) and
      (target.unit_type == :skill_unit or own_summon?(target, owner_id) or
         (Targeting.validate_enemy(relation, target) == :ok and
            not foreign_summon?(target, owner_id)))
  end

  defp owner_combatant(owner_id) do
    case Combat.resolve_combatant(:player, owner_id) do
      {:ok, combatant} -> combatant
      {:error, _reason} -> %{unit_type: :player, unit_id: owner_id}
    end
  end

  defp hiding?(%{unit_type: :skill_unit}), do: false

  defp hiding?(%{unit_type: unit_type, unit_id: unit_id}),
    do: StatusStorage.has_status?(unit_type, unit_id, :sc_hiding)

  defp own_summon?(%{unit_type: :homunculus, social_root: {:player, owner_id}}, owner_id),
    do: true

  defp own_summon?(%{unit_type: :mob, unit_id: mob_id}, owner_id),
    do: mob_owner(mob_id) == owner_id

  defp own_summon?(_target, _owner_id), do: false

  defp foreign_summon?(%{unit_type: :mob, unit_id: mob_id}, owner_id) do
    case mob_owner(mob_id) do
      nil -> false
      ^owner_id -> false
      _other -> true
    end
  end

  defp foreign_summon?(_target, _owner_id), do: false

  defp mob_owner(mob_id) do
    case UnitRegistry.get_unit(:mob, mob_id) do
      {:ok, {_module, %MobState{owner_player_id: owner_id}, _pid}} -> owner_id
      _missing -> nil
    end
  end

  # The caster is gone by the time its victims log the damage, so a monster
  # names itself (or, as a summon, its owner) explicitly.
  defp damage_source(%MobState{owner_player_id: owner_id}) when is_integer(owner_id) do
    fn
      :player -> {:player, owner_id}
      _target_type -> owner_id
    end
  end

  defp damage_source(%MobState{instance_id: id}), do: fn _target_type -> {:mob, id} end
  defp damage_source(%PlayerState{}), do: nil

  defp zap(caster, hp) when hp > 0 do
    case UnitRegistry.get_unit(unit_type(caster), Active.caster_unit_id(caster)) do
      {:ok, {_module, _state, pid}} -> zap_session(caster, pid, hp)
      {:error, :not_found} -> :ok
    end
  end

  defp zap(_caster, _hp), do: :ok

  defp zap_session(%MobState{}, pid, hp),
    do: MobSession.apply_damage(pid, hp, nil, %{passive?: true})

  defp zap_session(%PlayerState{}, pid, hp),
    do: PlayerSession.apply_damage(pid, hp, nil, %{passive?: true})

  defp unit_type(%MobState{}), do: :mob
  defp unit_type(%PlayerState{}), do: :player
end
