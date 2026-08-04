defmodule Aesir.ZoneServer.Mmo.Skills.Homunculus.HamiDefence do
  @moduledoc "Defence (HAMI_DEFENCE)."

  use Aesir.ZoneServer.Mmo.Skill,
    id: 8006,
    name: :hami_defence,
    display_name: "Defence",
    max_level: 5,
    target_type: :self,
    damage_type: :no_damage,
    sp_cost: [20, 25, 30, 35, 40],
    duration: [40_000, 35_000, 30_000, 25_000, 20_000],
    cooldown: List.duplicate(30_000, 5),
    status: :sc_defence

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState

  @behaviour Active

  @impl Active
  @spec cast(HomunculusState.t(), :self, 1..5, map()) ::
          {:ok, HomunculusState.t()} | {:error, atom()}
  def cast(%HomunculusState{} = caster, :self, level, definition) do
    params = [
      duration: Enum.fetch!(definition.duration, level - 1),
      caster_id: caster.world_gid,
      source_type: :homunculus,
      val1: level,
      val2: 5 + 5 * level,
      owner_refresh: :notify
    ]

    with :ok <-
           StatusInterpreter.apply_status(
             :player,
             caster.owner_character_id,
             :sc_defence,
             params
           ),
         :ok <-
           StatusInterpreter.apply_status(
             :homunculus,
             caster.world_gid,
             :sc_defence,
             params
           ) do
      {:ok, caster}
    end
  end
end
