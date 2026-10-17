defmodule Aesir.ZoneServer.Mmo.Skills.Npc.NpcSummonslave do
  @moduledoc """
  Summon Slave (NPC_SUMMONSLAVE). Creates the requested number of followers
  from the row's consecutive valid species IDs, cycling among them. Followers
  start near their master with the shared slave movement and attack modes and
  inherit its base walk speed. Both modes agree.

  Not learnable by players: `cast/4` is a stub, the mob executor always
  dispatches through `mob_cast/5`.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 196,
    name: :npc_summonslave,
    requires: [],
    display_name: "Summon Slave",
    max_level: 16,
    target_type: :self,
    damage_kind: :magic,
    damage_type: :no_damage,
    is_npc: true

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
          :ok | {:ok, MobState.t()} | {:error, term()}
  def mob_cast(%MobState{} = caster, _raw_target, level, _definition, row) do
    SlaveSummon.summon(caster, level, row)
  end
end
