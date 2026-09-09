defmodule Aesir.ZoneServer.Mmo.Skills.Mage.MgEnergycoat do
  @moduledoc """
  Energy Coat (MG_ENERGYCOAT). Toggles the energy coat buff on the caster.

  Re-casting removes the buff. The status carries its own 5-minute duration, so
  no params are passed; the damage reduction and the per-hit SP drain live in the
  status, including which kinds of damage the coat covers in each mode.

  Renewal spends the five second cast as a fixed cast: DEX cannot shorten it, but
  it also cannot be interrupted by the caster taking damage.

  Pre-renewal has no fixed cast at all, so the same five seconds are variable -
  DEX shortens them, and the cast is interruptible like any other.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 157,
    name: :mg_energycoat,
    status: :sc_energycoat,
    display_name: "Energy Coat",
    max_level: 1,
    target_type: :self,
    damage_type: :no_damage,
    damage_kind: :magic,
    range: 0,
    sp_cost: [30],
    cast_time: [renewal: [], pre_renewal: [5_000]],
    fixed_cast_time: [5_000],
    quest_skill: true,
    quest_owner_job: :mage

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  @behaviour Active

  @impl Active
  def cast(%{character_id: caster_id} = caster, :self, _level, _definition) do
    case StatusInterpreter.toggle_status(:player, caster_id, :sc_energycoat, []) do
      {:ok, _} -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end
end
