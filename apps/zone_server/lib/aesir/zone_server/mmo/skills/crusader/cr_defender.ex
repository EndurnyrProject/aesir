defmodule Aesir.ZoneServer.Mmo.Skills.Crusader.CrDefender do
  @moduledoc """
  Defender (CR_DEFENDER). Toggles SC_DEFENDER on the caster.

  Requires a shield equipped; a player caster without one is refused, a mob
  caster skips the check entirely (mirrors the other shield-gated skills).
  Re-casting removes the status. SC_DEFENDER has no duration (persistent
  toggle) so only the skill level is carried as `val1`.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 257,
    name: :cr_defender,
    status: :sc_defender,
    display_name: "Defending Aura",
    max_level: 5,
    target_type: :self,
    sp_cost: [30, 30, 30, 30, 30]

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

    case StatusInterpreter.toggle_status(unit_type, unit_id, :sc_defender, val1: level) do
      {:ok, _} -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end
end
