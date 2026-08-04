defmodule Aesir.ZoneServer.Mmo.Skills.Homunculus.HamiBloodlust do
  @moduledoc "Blood Lust (HAMI_BLOODLUST)."

  use Aesir.ZoneServer.Mmo.Skill,
    id: 8008,
    name: :hami_bloodlust,
    display_name: "Blood Lust",
    max_level: 3,
    target_type: :self,
    damage_type: :no_damage,
    sp_cost: List.duplicate(120, 3),
    duration: [60_000, 180_000, 300_000],
    cooldown: [300_000, 600_000, 900_000],
    status: :sc_bloodlust

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState

  @behaviour Active

  @impl Active
  @spec cast(HomunculusState.t(), :self, 1..3, map()) ::
          {:ok, HomunculusState.t()} | {:error, atom()}
  def cast(%HomunculusState{} = caster, :self, level, definition) do
    case StatusInterpreter.apply_status(
           :homunculus,
           caster.world_gid,
           :sc_bloodlust,
           duration: Enum.fetch!(definition.duration, level - 1),
           caster_id: caster.world_gid,
           source_type: :homunculus,
           val1: level,
           val2: 20 + 10 * level,
           val3: 9 * level,
           val4: 20
         ) do
      :ok -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end
end
