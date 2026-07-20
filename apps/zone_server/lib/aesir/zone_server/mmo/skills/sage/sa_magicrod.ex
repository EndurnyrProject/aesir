defmodule Aesir.ZoneServer.Mmo.Skills.Sage.SaMagicrod do
  @moduledoc """
  Magic Rod (SA_MAGICROD). Instant self-buff applying SC_MAGICROD.

  The buff lasts `400 + 200 * level` ms — a sub-second reaction window at low
  levels — during which a single-target magic spell aimed at the caster is
  absorbed and converted to SP. The absorption itself lives in the status
  (`StatusEffect.Effects.MagicRod`).

  rAthena (`status.cpp:10911`): val2 = 20 * level, the percent of the absorbed
  spell's SP cost the caster gains.
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
    after_cast_delay: [1_000, 1_000, 1_000, 1_000, 1_000]

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
