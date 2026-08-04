defmodule Aesir.ZoneServer.Mmo.Skills.Homunculus.HfliFleet do
  @moduledoc "Fleeting Move, Filir's ranked ASPD and ATK buff."

  use Aesir.ZoneServer.Mmo.Skill,
    id: 8010,
    name: :hfli_fleet,
    status: :sc_fleet,
    display_name: "Fleeting Move",
    max_level: 5,
    target_type: :self,
    damage_type: :no_damage,
    sp_cost: [30, 40, 50, 60, 70],
    duration: [60_000, 55_000, 50_000, 45_000, 40_000],
    cooldown: [60_000, 75_000, 90_000, 105_000, 120_000]

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  @behaviour Active

  @impl Active
  def cast(caster, :self, level, definition) do
    params = [
      val1: level,
      val2: 30 * level,
      val3: 5 + 5 * level,
      caster_id: caster.world_gid,
      source_type: :homunculus,
      duration: Enum.at(definition.duration, level - 1)
    ]

    case StatusInterpreter.apply_status(:homunculus, caster.world_gid, :sc_fleet, params) do
      :ok -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end
end
