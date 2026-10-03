defmodule Aesir.ZoneServer.Mmo.Skills.HighPriest.HpManarechargeTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Passives
  alias Aesir.ZoneServer.Mmo.SkillTree
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.Stats.BaseStats
  alias Aesir.ZoneServer.Unit.Stats.DerivedStats

  defp stats(learned) do
    %PlayerStats{
      base_stats: %BaseStats{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
      derived_stats: %DerivedStats{max_hp: 1000, max_sp: 100},
      progression: %PlayerProgression{base_level: 99, job_level: 50, learned_skills: learned}
    }
  end

  test "the catalog resolves Mana Recharge by id" do
    assert {:ok, %{name: :hp_manarecharge, max_level: 5}} = Catalog.by_id(481)
  end

  test "Mana Recharge 5 cuts skill SP cost by 20%" do
    learned = stats(%{481 => 5})

    assert Passives.sp_cost_rate(learned) == -20
    assert Passives.max_sp_rate_bonus(learned) == 0
  end

  test "Mana Recharge is a High Priest tree row" do
    {:ok, high_priest_id} = AvailableJobs.job_name_to_id(:high_priest)

    assert SkillTree.tree_for(high_priest_id)[481].owner_job_id == high_priest_id
  end
end
