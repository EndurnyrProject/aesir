defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.FogWallTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.FogWall

  test "cuts skill damage 25% and normal ranged damage 75%, and spoils normal ranged aim" do
    assert FogWall.modifiers(%{}, %{}) == %{
             skill_damage_taken_rate: -25,
             normal_ranged_damage_taken_rate: -75,
             normal_ranged_hit_taken_flat: 50
           }
  end
end
