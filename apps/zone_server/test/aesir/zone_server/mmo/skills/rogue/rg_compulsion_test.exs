defmodule Aesir.ZoneServer.Mmo.Skills.Rogue.RgCompulsionTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Passives
  alias Aesir.ZoneServer.Mmo.Skills.Rogue.RgCompulsion
  alias Aesir.ZoneServer.PlayerStateFixture

  setup do
    Catalog.reload()
  end

  test "grants its shop discount through the passive" do
    player =
      PlayerStateFixture.build(%{
        stats: %{progression: %{learned_skills: %{224 => 5}}}
      })

    assert Passives.shop_discount_pct(player) == 25
  end

  test "scales shop discount from 9% at level 1 to 25% at level 5" do
    assert RgCompulsion.shop_discount_pct(1, %{}) == 9
    assert RgCompulsion.shop_discount_pct(5, %{}) == 25
  end
end
