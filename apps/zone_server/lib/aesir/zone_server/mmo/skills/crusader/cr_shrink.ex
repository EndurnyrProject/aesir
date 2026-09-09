defmodule Aesir.ZoneServer.Mmo.Skills.Crusader.CrShrink do
  @moduledoc """
  Shrink (CR_SHRINK). A shield-gated toggle that augments the Guard stance; a
  player caster needs a shield, a mob caster skips the check, and re-casting turns
  it off. Granted by quest, not by the skill tree.

  Renewal: 100 SP; every weapon hit blocked by Guard has a 50% chance to stun the
  attacker for 5 s. Pre-renewal: 15 SP; every blocked hit has a 5% per Guard level
  chance to push the attacker back 2 cells instead.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 1002,
    name: :cr_shrink,
    status: :sc_shrink,
    display_name: "Shrink",
    max_level: 1,
    target_type: :self,
    sp_cost: [renewal: [100], pre_renewal: [15]],
    knockback: [renewal: 0, pre_renewal: 2],
    quest_skill: true,
    quest_owner_job: :crusader

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats

  @behaviour Active

  @impl Active
  @spec validate(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, :requires_shield}
  def validate(%PlayerState{} = caster, _target, _level, _definition) do
    PlayerStats.validate_shield(caster.stats.equipment)
  end

  def validate(%MobState{}, _target, _level, _definition), do: :ok

  @impl Active
  @spec cast(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, Active.caster()} | {:error, atom()}
  def cast(caster, :self, level, _definition), do: toggle(caster, level)
  def cast(caster, {:unit, _id}, level, _definition), do: toggle(caster, level)

  @spec toggle(Active.caster(), pos_integer()) :: {:ok, Active.caster()} | {:error, atom()}
  defp toggle(caster, level) do
    unit_type = caster.__struct__.get_unit_type(caster)
    unit_id = caster.__struct__.get_unit_id(caster)

    case StatusInterpreter.toggle_status(unit_type, unit_id, :sc_shrink, val1: level) do
      {:ok, _action} -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end
end
