defmodule Aesir.ZoneServer.Mmo.Skills.Rogue.RgTunneldriveTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Passives
  alias Aesir.ZoneServer.Mmo.Skills.Rogue.RgTunneldrive
  alias Aesir.ZoneServer.PlayerStateFixture

  setup do
    Catalog.reload()
  end

  test "is discovered as a passive and provides its hiding movement penalty" do
    player =
      PlayerStateFixture.build(%{
        stats: %{progression: %{learned_skills: %{213 => 5}}}
      })

    assert {:ok, definition} = Catalog.by_id(213)
    assert definition.name == :rg_tunneldrive
    assert definition.display_name == "Stalk"
    assert definition.max_level == 5
    assert {:ok, RgTunneldrive} = Catalog.passive_module_for(:rg_tunneldrive)
    assert Passives.hidden_move_speed(player) == 90
  end

  test "scales the hiding movement penalty from 114% to 90%" do
    assert RgTunneldrive.hidden_move_speed(1, %{}) == 114
    assert RgTunneldrive.hidden_move_speed(5, %{}) == 90
  end
end
