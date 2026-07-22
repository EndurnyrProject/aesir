defmodule Aesir.ZoneServer.Mmo.MobSkill.Archetype.Heal do
  @moduledoc """
  Restores HP to a friendly mob — the caster itself or the lowest-HP friend the
  Executor already resolved (`AL_HEAL`, `NPC_ALLHEAL`).

  Healing routes through the mob's own HP path (`MobSession.heal/2`, which
  clamps at `max_hp` and broadcasts the HP update), **not**
  `Combat.apply_heal/3`, which is player-oriented; mobs are never healed
  through the player pipeline.

  ## Heal amount (approximation)

      heal = (caster_level + caster_int) * skill_level

  This is a deliberate, design-accepted approximation of rAthena's `AL_HEAL`
  (which scales roughly with `(base_level + int) * skill_level`, minus the
  renewal MATK/divisor tuning we do not reproduce). `caster_level >= 1`, so the
  amount is always positive.

  No `SkillEffect` heal visual is broadcast: the HP-update packet emitted by
  `MobSession.heal/2` already shows the restored HP to nearby players, so a
  separate visual would be redundant.
  """

  @behaviour Aesir.ZoneServer.Mmo.MobSkill.Archetype

  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @impl true
  def apply(%MobState{} = caster, {:unit, :mob, target_mob_id}, _params, level) do
    amount = (caster.mob_data.level + caster.mob_data.stats.int) * level

    case UnitRegistry.get_unit(:mob, target_mob_id) do
      {:ok, {_module, _state, pid}} -> MobSession.heal(pid, amount)
      {:error, :not_found} -> {:error, :target_gone}
    end
  end

  def apply(%MobState{}, _target, _params, _level), do: {:error, :invalid_target}
end
