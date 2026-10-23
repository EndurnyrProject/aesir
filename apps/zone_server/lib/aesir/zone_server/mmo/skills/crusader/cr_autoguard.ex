defmodule Aesir.ZoneServer.Mmo.Skills.Crusader.CrAutoguard do
  @moduledoc """
  Guard (CR_AUTOGUARD). A shield-gated toggle for 12 to 30 SP that blocks weapon
  hits 5% to 30% of the time by level (5, 10, 14, 18, 21, 24, 26, 28, 29, 30),
  freezing the holder briefly on each block. A player caster needs a shield; a mob
  caster skips the check. Re-casting turns it off, and Devotion mirrors it to
  devotees.

  Renewal and pre-renewal agree.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 249,
    name: :cr_autoguard,
    requires: [],
    status: :sc_autoguard,
    toggleable: true,
    display_name: "Guard",
    max_level: 10,
    target_type: :self,
    sp_cost: [12, 14, 16, 18, 20, 22, 24, 26, 28, 30]

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats

  @behaviour Active

  @doc "A player's cast starts only with a shield equipped, the generic failure otherwise."
  @impl Active
  @spec begin_attempt(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, Active.caster()} | {:error, :requires_shield}
  def begin_attempt(%PlayerState{} = caster, _target, _level, _definition) do
    with :ok <- PlayerStats.validate_shield(caster.stats.equipment), do: {:ok, caster}
  end

  def begin_attempt(%MobState{} = caster, _target, _level, _definition), do: {:ok, caster}

  @impl Active
  @spec cast(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, Active.caster()} | {:error, atom()}
  def cast(caster, :self, level, _definition), do: toggle(caster, level)
  def cast(caster, {:unit, _id}, level, _definition), do: toggle(caster, level)

  @spec toggle(Active.caster(), pos_integer()) :: {:ok, Active.caster()} | {:error, atom()}
  defp toggle(caster, level) do
    unit_type = caster.__struct__.get_unit_type(caster)
    unit_id = caster.__struct__.get_unit_id(caster)

    StatusInterpreter.toggle_status(unit_type, unit_id, :sc_autoguard, val1: level)
    {:ok, caster}
  end
end
