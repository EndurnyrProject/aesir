defmodule Aesir.ZoneServer.Mmo.Skills.Npc.NpcSelfdestruction do
  @moduledoc """
  NPC Self Destruction (NPC_SELFDESTRUCTION).

  Deals the mob caster's current HP as fixed Fire damage in a five-cell radius,
  knocks enemies back three cells, then routes lethal damage through the
  caster's normal mob death path. Player-owned casters use their owner's PvM
  faction and never damage players or other player-owned summons.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 173,
    name: :npc_selfdestruction,
    requires: [],
    display_name: "NPC Self Destruction",
    max_level: 1,
    target_type: :self,
    damage_type: :damage,
    damage_kind: :magic,
    element: :fire,
    range: 0,
    knockback: 3,
    splash_radius: 5

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.DamageApplication
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
    with {:ok, target_pid, _target_state, ^unit_type} <-
           TargetResolver.resolve(unit_type, target_id) do
      hit_info = %{
        element: definition.element,
        skill_id: definition.id,
        skill_level: 1,
        damage_kind: :magic,
        pre_delivery_prepared?: true
      }

      DamageApplication.apply_unit_damage(
        unit_type,
        target_pid,
        target_id,
        caster.hp,
        hit_info,
        source_id(caster)
      )

      Combat.knockback(unit_type, target_id, caster.x, caster.y, definition.knockback)
    end
  end

  defp kill_caster(caster) do
    case UnitRegistry.get_unit(:mob, caster.instance_id) do
      {:ok, {_module, _state, pid}} ->
        MobSession.apply_damage(pid, caster.hp, source_id(caster))

      {:error, :not_found} ->
        :ok
    end
  end

  defp source_id(%MobState{owner_player_id: nil, instance_id: instance_id}), do: instance_id
  defp source_id(%MobState{owner_player_id: owner_player_id}), do: owner_player_id
end
