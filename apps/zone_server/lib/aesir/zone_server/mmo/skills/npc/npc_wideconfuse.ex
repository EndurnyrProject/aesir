defmodule Aesir.ZoneServer.Mmo.Skills.Npc.NpcWideconfuse do
  @moduledoc """
  Wide Confusion applies its ailment to enemies around the targeted unit.

  Both modes use radii 2, 5, 8, 11 and 14 with ordinary status defense.
  Renewal starts from 18 seconds; pre-renewal 30 seconds.
  Equipment autocasts and monster casts use the same effect.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 667,
    name: :npc_wideconfuse,
    display_name: "Wide Confusion",
    max_level: 5,
    requires: [],
    target_type: :self,
    damage_type: :no_damage,
    damage_kind: :none,
    is_npc: true,
    damage_splash: true,
    splash_radius: [2, 5, 8, 11, 14],
    duration: [renewal: List.duplicate(18_000, 5), pre_renewal: List.duplicate(30_000, 5)],
    status: :sc_confusion

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skills.Npc.WideAilment

  @behaviour Active

  @impl Active
  @spec cast(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, Active.caster()} | {:error, atom()}
  defdelegate cast(caster, target, level, definition), to: WideAilment
end
