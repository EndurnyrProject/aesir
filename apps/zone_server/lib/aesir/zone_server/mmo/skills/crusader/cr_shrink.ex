defmodule Aesir.ZoneServer.Mmo.Skills.Crusader.CrShrink do
  @moduledoc """
  Shrink (CR_SHRINK). Shield-gated toggle that turns SC_SHRINK on the caster on
  or off.

  While active it augments the Guard stance: every weapon hit the caster blocks
  with Guard has a fixed 50% chance to Stun the blocked attacker (the proc lives
  in the Shrink status). A player caster must have a shield equipped; a mob caster
  carries no equipment and skips the check, mirroring the other shield-gated
  Crusader skills. Casting while active toggles it off; casting while inactive
  applies it.

  This module ships without a skill-tree entry or grant mechanism: it is a quest
  skill wired up separately.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 1002,
    name: :cr_shrink,
    status: :sc_shrink,
    display_name: "Shrink",
    max_level: 1,
    target_type: :self,
    sp_cost: [100],
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
