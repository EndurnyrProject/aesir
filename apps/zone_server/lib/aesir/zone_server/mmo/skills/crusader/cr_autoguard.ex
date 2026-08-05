defmodule Aesir.ZoneServer.Mmo.Skills.Crusader.CrAutoguard do
  @moduledoc """
  Guard (CR_AUTOGUARD). Shield-gated toggle that turns SC_AUTOGUARD on the
  caster on or off.

  A player caster must have a shield equipped (the shared shield gate); a mob
  caster carries no equipment and skips the check, mirroring the other
  shield-gated Crusader skills. Casting while the stance is active toggles it
  off; casting while inactive applies it at the cast level, which drives the
  per-level block chance in the status.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 249,
    name: :cr_autoguard,
    requires: [],
    status: :sc_autoguard,
    display_name: "Guard",
    max_level: 10,
    target_type: :self,
    sp_cost: [12, 14, 16, 18, 20, 22, 24, 26, 28, 30]

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
  def cast(caster, :self, level, _definition), do: toggle(caster, level)
  def cast(caster, {:unit, _id}, level, _definition), do: toggle(caster, level)

  @spec toggle(Active.caster(), pos_integer()) :: {:ok, Active.caster()} | {:error, atom()}
  defp toggle(caster, level) do
    unit_type = caster.__struct__.get_unit_type(caster)
    unit_id = caster.__struct__.get_unit_id(caster)

    case StatusInterpreter.toggle_status(unit_type, unit_id, :sc_autoguard, val1: level) do
      {:ok, action} ->
        DevotionMirror.fan_toggle(unit_type, unit_id, :sc_autoguard, action, level)
        {:ok, caster}

      {:error, _reason} = error ->
        error
    end
  end
end
