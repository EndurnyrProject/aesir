defmodule Aesir.ZoneServer.Mmo.Skills.Npc.NpcAllheal do
  @moduledoc """
  NPC Heal (NPC_ALLHEAL). Fully restores the target mob's HP.

  Mob-only skill: rows target `self` or `friend`, both of which the Executor
  resolves and adapts to `{:unit, mob_instance_id}` before calling `cast/4`.
  Unlike `AL_HEAL`, this is a flat full-heal with no stat-derived amount - the
  heal restores exactly the target's missing HP (`max_hp - hp`) through the
  shared `Combat.apply_heal/4` path, the same pipeline every other heal (player
  or mob) uses.

  The caster's own unit id is read generically via `to_combatant/1` (mirroring
  `AlHeal`), so a non-mob caster would still resolve correctly, though in
  practice the mob-skill Executor is the only caller.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 687,
    name: :npc_allheal,
    requires: [],
    display_name: "Heal (NPC)",
    max_level: 50,
    target_type: :target_ally,
    damage_type: :no_damage

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active

  @impl Active
  @doc """
  Fully heals the target mob, or errors with `:target_gone` when it no longer
  exists (e.g. it died between the Executor resolving the target and this call).
  """
  @spec cast(Active.caster(), {:unit, integer()}, pos_integer(), struct()) ::
          {:ok, Active.caster()} | {:error, :target_gone}
  def cast(caster, {:unit, target_id}, _level, _definition) do
    combatant = caster.__struct__.to_combatant(caster)

    case UnitRegistry.get_unit(:mob, target_id) do
      {:ok, {_module, %MobState{hp: hp, max_hp: max_hp}, _pid}} ->
        Combat.apply_heal(:mob, target_id, max_hp - hp, combatant.unit_id)
        {:ok, caster}

      {:error, :not_found} ->
        {:error, :target_gone}
    end
  end
end
