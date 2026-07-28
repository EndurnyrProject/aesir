defmodule Aesir.ZoneServer.Mmo.Skills.Bard.BdAdaptation do
  @moduledoc """
  Adaptation to Circumstances (BD_ADAPTATION).
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 304,
    name: :bd_adaptation,
    status: :sc_adaptation,
    display_name: "Adaptation to Circumstances",
    max_level: 1,
    target_type: :self,
    damage_type: :no_damage,
    range: 0,
    sp_cost: [10],
    duration: [300_000],
    cast_time: [0],
    fixed_cast_time: [0],
    after_cast_delay: [300],
    cooldown: [300_000]

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Cost
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  @behaviour Active

  @impl Active
  def dynamic_cost(game_state, _target, level, definition) do
    game_state
    |> Cost.from_definition(definition, level, sp: 0)
    |> Map.put(:sp_requirement, 10)
  end

  @impl Active
  def cast(%{character_id: caster_id} = caster, :self, level, definition) do
    with :ok <-
           StatusInterpreter.apply_status(:player, caster_id, :sc_adaptation,
             caster_id: caster_id,
             duration: Enum.at(definition.duration, level - 1),
             owner_refresh: :defer
           ) do
      {:ok, caster}
    end
  end
end
