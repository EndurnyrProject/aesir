defmodule Aesir.ZoneServer.Mmo.Skills.Npc.NpcCallslave do
  @moduledoc """
  Call Slave (NPC_CALLSLAVE). Mob-only summon behavior.

  rAthena mob_skill id 352. Identical semantics to `NPC_SUMMONSLAVE`: both map
  to the same `mob_summonslave` behavior in rAthena, so this module shares the
  `Npc.SlaveSummon` logic (slave ids from `condition.val1..val5`, 5-slave
  living cap, id cycling).

  Not learnable by players: `cast/4` is a stub, the mob executor always
  dispatches through `mob_cast/5`.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 352,
    name: :npc_callslave,
    display_name: "Call Slave",
    max_level: 1,
    target_type: :self,
    damage_type: :no_damage

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skills.Npc.SlaveSummon
  alias Aesir.ZoneServer.Unit.Mob.MobState

  @behaviour Active

  @doc "Mob-only skill; a player can never learn or cast it."
  @impl Active
  @spec cast(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          {:error, :mob_only}
  def cast(_caster, _target, _level, _definition), do: {:error, :mob_only}

  @impl Active
  @spec mob_cast(MobState.t(), term(), pos_integer(), Definition.t(), map()) ::
          :ok | {:error, term()}
  def mob_cast(%MobState{} = caster, _raw_target, level, _definition, row) do
    SlaveSummon.summon(caster, level, row)
  end
end
