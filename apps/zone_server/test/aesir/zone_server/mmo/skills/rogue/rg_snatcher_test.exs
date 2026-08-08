defmodule Aesir.ZoneServer.Mmo.Skills.Rogue.RgSnatcherTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Passives
  alias Aesir.ZoneServer.Mmo.Skills.Rogue.RgSnatcher
  alias Aesir.ZoneServer.PlayerStateFixture

  setup do
    Catalog.reload()
  end

  test "is discovered as a passive and includes TF_STEAL in its proc chance" do
    player =
      PlayerStateFixture.build(%{
        stats: %{progression: %{learned_skills: %{50 => 6, 210 => 4}}}
      })

    assert {:ok, RgSnatcher} = Catalog.passive_module_for(:rg_snatcher)
    assert Passives.steal_proc(player) == 175
  end
end
