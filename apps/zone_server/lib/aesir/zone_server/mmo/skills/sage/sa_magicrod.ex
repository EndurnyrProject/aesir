defmodule Aesir.ZoneServer.Mmo.Skills.Sage.SaMagicrod do
  @moduledoc """
  Magic Rod (SA_MAGICROD). An instant self buff for 2 SP lasting 400 ms plus 200 ms per
  level above one, during which a single-target spell aimed at the caster is absorbed and
  20% per level of its SP cost is gained instead (the absorption lives in the
  status).

  Renewal adds a 1 s delay after the cast; pre-renewal has none.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 276,
    name: :sa_magicrod,
    status: :sc_magicrod,
    display_name: "Magic Rod",
    max_level: 5,
    target_type: :self,
    damage_type: :no_damage,
    damage_kind: :magic,
    range: 0,
    sp_cost: [2, 2, 2, 2, 2],
    duration: [400, 600, 800, 1_000, 1_200],
    after_cast_delay: [renewal: List.duplicate(1_000, 5), pre_renewal: []]

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  @behaviour Active

  @impl Active
  def cast(%{character_id: caster_id} = caster, :self, level, definition) do
    params = [
      val1: level,
      val2: 20 * level,
      caster_id: caster_id,
      duration: Enum.at(definition.duration, level - 1)
    ]

    with :ok <- StatusInterpreter.apply_status(:player, caster_id, :sc_magicrod, params) do
      {:ok, caster}
    end
  end
end
