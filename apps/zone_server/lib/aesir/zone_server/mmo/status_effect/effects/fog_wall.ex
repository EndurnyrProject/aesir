defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.FogWall do
  @moduledoc """
  Blinding Mist (SC_FOGWALL), held by every unit standing in the fog. Skill
  damage taken drops by 25%, normal ranged damage taken by 75%, and normal
  ranged attacks against the holder lose 50 points of hit rate. Identical in
  both modes.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_fogwall,
    no_dispel: true,
    no_save: true,
    properties: [:debuff],
    immunity: [:boss],
    icon: :fogwall

  @modifiers %{
    skill_damage_taken_rate: -25,
    normal_ranged_damage_taken_rate: -75,
    normal_ranged_hit_taken_flat: 50
  }

  @impl true
  def modifiers(_instance, _context), do: @modifiers
end
