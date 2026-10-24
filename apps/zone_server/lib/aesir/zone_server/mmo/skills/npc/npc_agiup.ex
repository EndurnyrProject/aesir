defmodule Aesir.ZoneServer.Mmo.Skills.Npc.NpcAgiup do
  @moduledoc """
  NPC Increase AGI (NPC_AGIUP). A self buff starting SC_AGIUP on its caster:
  a 50% movement haste and 100% more FLEE, for ten seconds per level.

  Renewal and pre-renewal agree on every value. Any caster may use it, and it
  always lands on the caster (a monster's row arrives as `{:unit, id}`, a
  player's request as `:self`).
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 350,
    name: :npc_agiup,
    requires: [],
    status: :sc_agiup,
    display_name: "Increase AGI (NPC)",
    max_level: 10,
    target_type: :self,
    damage_type: :no_damage,
    is_npc: true,
    damage_kind: :none,
    duration: Enum.map(1..10, &(&1 * 10_000))

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  @behaviour Active

  @move_haste 50
  @flee_rate 100

  @impl Active
  @spec cast(Active.caster(), Active.target(), pos_integer(), struct()) ::
          {:ok, Active.caster()} | {:error, atom()}
  def cast(caster, _target, level, definition) do
    {unit_type, caster_id} = Active.target_unit_ref(caster, :self)

    case StatusInterpreter.apply_status(unit_type, caster_id, :sc_agiup,
           val1: @move_haste,
           val2: @flee_rate,
           duration: Enum.at(definition.duration, level - 1),
           caster_id: caster_id,
           source_id: caster_id
         ) do
      :ok -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end
end
