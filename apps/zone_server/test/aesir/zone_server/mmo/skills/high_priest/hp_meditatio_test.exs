defmodule Aesir.ZoneServer.Mmo.Skills.HighPriest.HpMeditatioTest do
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

  test "the catalog resolves Meditatio by id" do
    assert {:ok, %{name: :hp_meditatio, max_level: 10}} = Catalog.by_id(363)
  end

  test "Meditatio 10 adds 10% max SP and 30% base SP regen" do
    learned = stats(%{363 => 10})

    assert Passives.max_sp_rate_bonus(learned) == 10
    assert Passives.sp_regen_rate(learned) == 30
    assert Passives.sp_cost_rate(learned) == 0
  end

  test "Meditatio is a High Priest tree row" do
    {:ok, high_priest_id} = AvailableJobs.job_name_to_id(:high_priest)

    assert SkillTree.tree_for(high_priest_id)[363].owner_job_id == high_priest_id
  end
end
