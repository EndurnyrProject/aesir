defmodule Aesir.ZoneServer.Mmo.Skills.Mage.MgSight do
  @moduledoc """
  Sight (MG_SIGHT). Applies SC_SIGHT to the caster, a 10-second marker buff whose
  `on_apply` reveals concealed enemies in radius 3.

  rAthena renewal: self-cast, no damage, fire element, max level 1, SP 10.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 10,
    name: :mg_sight,
    display_name: "Sight",
    max_level: 1,
    target_type: :self,
    damage_type: :no_damage,
    element: :fire,
    range: 0,
    splash_radius: 3,
    sp_cost: [10]

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  @behaviour Active

  @duration 10_000

  @impl Active
  def cast(%{character_id: caster_id} = caster, :self, _level, _definition) do
    params = [caster_id: caster_id, duration: @duration]

    case StatusInterpreter.apply_status(:player, caster_id, :sc_sight, params) do
      :ok -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end
end
