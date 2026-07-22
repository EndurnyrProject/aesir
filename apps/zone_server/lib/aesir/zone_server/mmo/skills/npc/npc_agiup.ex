defmodule Aesir.ZoneServer.Mmo.Skills.Npc.NpcAgiup do
  @moduledoc """
  NPC Increase AGI (NPC_AGIUP). Self-targeted mob buff, applying
  `:sc_increaseagi` to the casting mob.

  A self-target row is resolved and adapted by the Executor to
  `{:unit, caster_instance_id}`, never bare `:self`, so `cast/4` matches on
  the unit tuple. `val1`/`val2` both scale with the row's skill level, mirroring
  the `val1 = skill_level` convention player self-buffs use (`AlIncagi`).
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 350,
    name: :npc_agiup,
    status: :sc_increaseagi,
    display_name: "Increase AGI (NPC)",
    max_level: 50,
    target_type: :self,
    damage_type: :no_damage

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  @behaviour Active

  @impl Active
  @spec cast(Active.caster(), {:unit, integer()}, pos_integer(), struct()) ::
          {:ok, Active.caster()} | {:error, atom()}
  def cast(caster, {:unit, id}, level, _definition) do
    case StatusInterpreter.apply_status(:mob, id, :sc_increaseagi,
           val1: level,
           val2: level,
           caster_id: id,
           source_id: id
         ) do
      :ok -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end
end
