defmodule Aesir.ZoneServer.Mmo.Skills.Homunculus.HlifAvoid do
  @moduledoc """
  Urgent Escape (HLIF_AVOID). Increases movement speed for Lif and its owner,
  with the larger bonus applying to Lif.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 8_002,
    name: :hlif_avoid,
    display_name: "Urgent Escape",
    max_level: 5,
    target_type: :self,
    damage_type: :no_damage,
    sp_cost: [20, 25, 30, 35, 40],
    cooldown: List.duplicate(35_000, 5),
    duration: [40_000, 35_000, 30_000, 25_000, 20_000],
    status: :sc_avoid

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState

  @behaviour Active

  @impl Active
  def cast(%HomunculusState{} = caster, :self, level, definition) do
    duration = Enum.fetch!(definition.duration, level - 1)

    common = [
      val1: level,
      caster_id: caster.world_gid,
      source_type: :homunculus,
      duration: duration
    ]

    with :ok <-
           StatusInterpreter.apply_status(
             :player,
             caster.owner_character_id,
             :sc_avoid,
             common |> Keyword.put(:val2, 10 * level) |> Keyword.put(:owner_refresh, :notify)
           ),
         :ok <-
           StatusInterpreter.apply_status(
             :homunculus,
             caster.world_gid,
             :sc_avoid,
             Keyword.put(common, :val2, 40 * level)
           ) do
      {:ok, caster}
    end
  end
end
