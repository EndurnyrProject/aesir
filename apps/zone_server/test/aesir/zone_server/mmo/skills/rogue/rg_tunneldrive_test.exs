defmodule Aesir.ZoneServer.Mmo.Skills.Rogue.RgTunneldriveTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Passives
  alias Aesir.ZoneServer.Mmo.Skills.Rogue.RgTunneldrive
  alias Aesir.ZoneServer.PlayerStateFixture

  setup do
    Catalog.reload()
  end

  test "provides its hiding movement penalty through the passive" do
    player =
      PlayerStateFixture.build(%{
        stats: %{progression: %{learned_skills: %{213 => 5}}}
      })

    assert Passives.hidden_move_speed(player) == 90
  end

  test "scales the hiding movement penalty from 114% to 90%" do
    assert RgTunneldrive.hidden_move_speed(1, %{}) == 114
    assert RgTunneldrive.hidden_move_speed(5, %{}) == 90
  end
end
