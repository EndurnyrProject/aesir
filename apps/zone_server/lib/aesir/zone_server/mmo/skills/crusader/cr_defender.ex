defmodule Aesir.ZoneServer.Mmo.Skills.Crusader.CrDefender do
  @moduledoc """
  Defending Aura (CR_DEFENDER). A shield-gated toggle for 30 SP with a 0.8 s
  delay that cuts long-range weapon damage taken by 5% plus 15% per level while
  slowing the holder: walking drops to a 200 ms cell delay at best, and attack speed
  falls by 25 minus 5 per level. A player caster needs a shield; a mob caster skips
  the check. Re-casting removes the stance.

  Renewal takes the attack-speed loss as flat points; pre-renewal as a percentage
  rate. The reduction and walk penalty agree in both modes.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 257,
    name: :cr_defender,
    # Caster-generic: has an explicit `validate(%MobState{})` clause and a generic
    # `cast/4`, so a mob casts it fine (shield check is player-only). Not denylisted.
    requires: [],
    status: :sc_defender,
    display_name: "Defending Aura",
    max_level: 5,
    target_type: :self,
    sp_cost: [30, 30, 30, 30, 30],
    after_cast_delay: List.duplicate(800, 5)

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

    case StatusInterpreter.toggle_status(unit_type, unit_id, :sc_defender, val1: level) do
      {:ok, action} ->
        DevotionMirror.fan_toggle(unit_type, unit_id, :sc_defender, action, level)
        {:ok, caster}

      {:error, _reason} = error ->
        error
    end
  end
end
