defmodule Aesir.ZoneServer.Mmo.Skills.Npc.NpcSelfdestruction do
  @moduledoc """
  NPC Self Destruction (NPC_SELFDESTRUCTION).

  Deals the mob caster's current HP as Fire misc damage in a five-cell radius
  (through the shared misc tail: no target cards, the skill rates and each
  target's element; it never misses), knocks enemies back three
  cells, then routes lethal damage through the caster's normal mob death path.
  Player-owned casters use their owner's PvM faction and never damage players or
  other player-owned summons.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 173,
    name: :npc_selfdestruction,
    requires: [],
    display_name: "NPC Self Destruction",
    max_level: 1,
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

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.BattleFlags
  alias Aesir.ZoneServer.Mmo.Combat.DamageApplication
  alias Aesir.ZoneServer.Mmo.Combat.EquipProcDispatch
  alias Aesir.ZoneServer.Mmo.Combat.MiscDamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.OnHitEffects
  alias Aesir.ZoneServer.Mmo.Combat.SkillRange
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active

  @impl Active
  def cast(%MobState{} = caster, _target, _level, definition) do
    caster
    |> targets(definition.splash_radius)
    |> Enum.each(&damage_target(caster, definition, &1))

    kill_caster(caster)
    {:ok, caster}
  end

  defp targets(caster, radius) do
    combatant = faction_combatant(caster)

    caster.map_name
    |> Combat.splash_targets({caster.x, caster.y}, radius, combatant)
    |> Enum.filter(&enemy_of_owned_caster?(caster, &1))
  end

  defp faction_combatant(%MobState{owner_player_id: nil} = caster) do
    case Combat.resolve_combatant(:mob, caster.instance_id) do
      {:ok, combatant} -> combatant
      {:error, _reason} -> %{unit_type: :mob, unit_id: caster.instance_id}
    end
  end

  defp faction_combatant(%MobState{owner_player_id: owner_player_id}) do
    case Combat.resolve_combatant(:player, owner_player_id) do
      {:ok, combatant} -> combatant
      {:error, _reason} -> %{unit_type: :player, unit_id: owner_player_id}
    end
  end

  defp enemy_of_owned_caster?(%MobState{owner_player_id: nil}, _target), do: true

  defp enemy_of_owned_caster?(%MobState{}, {:player, _target_id}), do: false

  defp enemy_of_owned_caster?(%MobState{}, {:mob, target_id}) do
    case UnitRegistry.get_unit(:mob, target_id) do
      {:ok, {_module, %MobState{owner_player_id: owner_player_id}, _pid}} ->
        owner_player_id == nil

      {:error, :not_found} ->
        false
    end
  end

  defp damage_target(caster, definition, {unit_type, target_id}) do
    with {:ok, target_pid, target_state, ^unit_type} <-
           TargetResolver.resolve(unit_type, target_id),
         range = hit_range(caster, target_state, definition.id),
         {:ok, %{damage: damage}} <- misc_damage(caster, target_state, definition, range),
         hit_info = %{
           dmg_type: :misc,
           is_short: range == :short,
           element: definition.element,
           skill_id: definition.id,
           skill_level: 1,
           from_caster?: true,
           div: 1,
           proc: proc_spec(caster, {unit_type, target_id}, target_state, {definition.id, range})
         },
         :ok <-
           DamageApplication.apply_unit_damage(
             unit_type,
             target_pid,
             target_id,
             damage,
             hit_info,
             damage_source(caster, unit_type)
           ) do
      OnHitEffects.counter_stage(hit_info, damage)
      Combat.knockback(unit_type, target_id, caster.x, caster.y, definition.knockback)
    end
  end

  defp misc_damage(caster, target_state, definition, range) do
    MiscDamageCalculator.calculate_misc_damage(
      MobState.to_combatant(caster),
      target_state.__struct__.to_combatant(target_state),
      base_damage: caster.hp,
      element: definition.element,
      skill_id: definition.id,
      attack_flag: BattleFlags.build(:misc, range, true)
    )
  end

  # The monster's distance to each victim decides the hit's range class.
  defp hit_range(caster, target_state, skill_id) do
    target = %{position: position(target_state)}
    SkillRange.classify(%{unit_type: :mob, position: {caster.x, caster.y}}, target, skill_id, 1)
  end

  defp position(%{x: x, y: y}) when is_integer(x) and is_integer(y), do: {x, y}
  defp position(_target_state), do: nil

  # Self Destruction is a misc skill: its victims' when-hit procs see a misc hit.
  # A monster wears nothing, so the hit's parties are needed only by identity.
  defp proc_spec(caster, {unit_type, target_id}, target_state, {skill_id, range}) do
    EquipProcDispatch.spec(
      %{unit_type: :mob, unit_id: caster.instance_id},
      %{unit_type: unit_type, unit_id: target_id},
      target_state,
      BattleFlags.build(:misc, range, true),
      skill_id: skill_id
    )
  end

  defp kill_caster(caster) do
    case UnitRegistry.get_unit(:mob, caster.instance_id) do
      {:ok, {_module, _state, pid}} ->
        MobSession.apply_damage(pid, caster.hp, source_id(caster))

      {:error, :not_found} ->
        :ok
    end
  end

  defp damage_source(%MobState{owner_player_id: nil, instance_id: instance_id}, _target_type),
    do: {:mob, instance_id}

  defp damage_source(%MobState{owner_player_id: owner_player_id}, :player),
    do: {:player, owner_player_id}

  defp damage_source(%MobState{owner_player_id: owner_player_id}, _target_type),
    do: owner_player_id

  defp source_id(%MobState{owner_player_id: nil, instance_id: instance_id}), do: instance_id
  defp source_id(%MobState{owner_player_id: owner_player_id}), do: owner_player_id
end
