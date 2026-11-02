defmodule Aesir.ZoneServer.Mmo.Skills.Other.AllPartyflee do
  @moduledoc """
  Party Flee, used by Huge Spray of Flowers.

  In both modes a player needs a party at effect time, after the item is spent
  and the five-minute cooldown begins. Eligible party members receive an
  ordinary zero-duration status, defended to one millisecond. Its empty stat
  selection does not automatically publish the nominal FLEE bonus.

  The renewal item authorizes level five despite the skill's maximum of one;
  pre-renewal uses level one. Non-player casters apply directly to their target.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 693,
    name: :all_partyflee,
    display_name: "Party Flee",
    max_level: 1,
    target_type: :self,
    damage_type: :no_damage,
    damage_kind: :magic,
    is_npc: true,
    damage_splash: true,
    splash_radius: 14,
    requires: [],
    status: :sc_partyflee,
    duration: [0],
    cooldown: [300_000]

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.PartyBuff

  @behaviour Active

  @impl Active
  @spec cast(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, Active.caster()}
          | {:local_effects, Active.caster(), [Active.effect()]}
          | {:error, atom()}
  def cast(caster, target, level, definition),
    do: PartyBuff.cast_cash(caster, target, level, definition)
end
