defmodule Aesir.ZoneServer.Mmo.Skills.Bard.BdAdaptation do
  @moduledoc """
  Adaptation to Circumstances (BD_ADAPTATION). Lets the performer leave a song
  early.

  Renewal: requires 10 SP (spends none), a 0.3 s delay, a 5-minute cooldown, and a
  5-minute status that discounts song SP by 20%. Pre-renewal: requires 1 SP with no
  delay or cooldown; the classic effect (leaving a song after it has played for
  5 s) belongs to the deferred ground-song subsystem, so the status is applied
  without any cost effect.
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
    sp_cost: [renewal: [10], pre_renewal: [1]],
    duration: [300_000],
    cast_time: [0],
    fixed_cast_time: [0],
    after_cast_delay: [renewal: [300], pre_renewal: []],
    cooldown: [renewal: [300_000], pre_renewal: []]

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Cost
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  @behaviour Active

  @impl Active
  def dynamic_cost(game_state, _target, level, definition) do
    game_state
    |> Cost.from_definition(definition, level, sp: 0)
    |> Map.put(:sp_requirement, hd(definition.sp_cost))
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
