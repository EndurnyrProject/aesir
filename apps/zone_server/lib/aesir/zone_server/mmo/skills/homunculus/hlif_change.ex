defmodule Aesir.ZoneServer.Mmo.Skills.Homunculus.HlifChange do
  @moduledoc """
  Mental Change (HLIF_CHANGE). Temporarily increases evolved Lif's VIT and INT.
  Natural expiration is handled by the Homunculus status lifecycle.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 8_004,
    name: :hlif_change,
    display_name: "Mental Change",
    max_level: 3,
    target_type: :self,
    damage_type: :no_damage,
    sp_cost: List.duplicate(100, 3),
    duration: [60_000, 180_000, 300_000],
    cooldown: [600_000, 900_000, 1_200_000],
    status: :sc_change

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState

  @behaviour Active

  @impl Active
  def cast(%HomunculusState{} = caster, :self, level, definition) do
    params = [
      val1: level,
      val2: 30 * level,
      val3: 20 * level,
      caster_id: caster.world_gid,
      source_type: :homunculus,
      duration: Enum.fetch!(definition.duration, level - 1)
    ]

    case StatusInterpreter.apply_status(:homunculus, caster.world_gid, :sc_change, params) do
      :ok -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end
end
