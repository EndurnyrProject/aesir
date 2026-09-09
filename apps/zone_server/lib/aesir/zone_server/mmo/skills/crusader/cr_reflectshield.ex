defmodule Aesir.ZoneServer.Mmo.Skills.Crusader.CrReflectshield do
  @moduledoc """
  Reflect Shield (CR_REFLECTSHIELD). A shield-gated toggle for 35 to 80 SP that
  reflects 10% plus 3% per level of every short-range physical hit back to the
  attacker. A player caster needs a shield; a mob caster skips the check. Re-casting
  turns it off, and Devotion mirrors it to devotees. A mob-skill row may target the
  caster by id; either shape toggles the caster.

  Renewal and pre-renewal agree.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 252,
    name: :cr_reflectshield,
    requires: [],
    status: :sc_reflectshield,
    display_name: "Reflect Shield",
    max_level: 10,
    target_type: :self,
    damage_type: :no_damage,
    range: 0,
    sp_cost: [35, 40, 45, 50, 55, 60, 65, 70, 75, 80]

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.DevotionMirror
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
  def cast(caster, :self, level, definition), do: toggle(caster, level, definition)
  def cast(caster, {:unit, _id}, level, definition), do: toggle(caster, level, definition)

  @spec toggle(Active.caster(), pos_integer(), Definition.t()) ::
          {:ok, Active.caster()} | {:error, atom()}
  defp toggle(caster, level, _definition) do
    unit_type = caster.__struct__.get_unit_type(caster)
    unit_id = caster.__struct__.get_unit_id(caster)

    case StatusInterpreter.toggle_status(unit_type, unit_id, :sc_reflectshield, val1: level) do
      {:ok, action} ->
        DevotionMirror.fan_toggle(unit_type, unit_id, :sc_reflectshield, action, level)
        {:ok, caster}

      {:error, _reason} = error ->
        error
    end
  end
end
