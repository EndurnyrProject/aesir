defmodule Aesir.ZoneServer.Mmo.Skills.MgEnergycoat do
  @moduledoc """
  Energy Coat (MG_ENERGYCOAT). Toggles SC_ENERGYCOAT on the caster.

  Re-casting removes the buff. The status carries its own 5-minute duration, so
  no params are passed; SP reduction and per-hit SP drain live in the status.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 157,
    name: :mg_energycoat,
    status: :sc_energycoat,
    display_name: "Energy Coat",
    max_level: 1,
    target_type: :self,
    damage_type: :no_damage,
    range: 0,
    sp_cost: [30],
    fixed_cast_time: [5_000]

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
