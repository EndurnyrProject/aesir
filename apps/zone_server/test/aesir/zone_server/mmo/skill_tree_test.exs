defmodule Aesir.ZoneServer.Mmo.SkillTreeTest do
  use ExUnit.Case, async: false

  @moduletag :capture_log

  import ExUnit.CaptureLog

  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.SkillTree
  alias Aesir.ZoneServer.Mmo.SkillTree.Entry
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression

  {:ok, swordman_id} = AvailableJobs.job_name_to_id(:swordman)
  @swordman_id swordman_id

  defp catalog_id(name) do
    {:ok, definition} = Catalog.by_name(name)
    definition.id
  end

  defp swordman_progression(attrs) do
    Map.merge(
      %PlayerProgression{
        base_level: 99,
        job_level: 50,
        base_exp: 0,
        job_exp: 0,
        job_id: @swordman_id,
        skill_point: 1,
        status_point: 0,
        learned_skills: %{}
      },
      Map.new(attrs)
    )
  end

  describe "tree_for/1 (real data)" do
    test "Swordman tree contains all implemented sm_* entries" do
      tree = SkillTree.tree_for(@swordman_id)

      for name <- [
            :sm_sword,
            :sm_twohand,
            :sm_recovery,
            :sm_bash,
            :sm_provoke,
            :sm_magnum,
            :sm_endure,
            :sm_movingrecovery,
            :sm_fatalblow,
            :sm_autoberserk
          ] do
        assert Map.has_key?(tree, catalog_id(name)), "expected #{name} in Swordman tree"
      end
    end

    test "sm_twohand requires sm_sword at level 1" do
      {:ok, %Entry{requires: requires}} =
        SkillTree.entry(@swordman_id, catalog_id(:sm_twohand))

      assert requires == [{catalog_id(:sm_sword), 1}]
    end

    test "sm_sword caps at the rAthena max level of 10" do
      {:ok, %Entry{max_level: max_level}} =
        SkillTree.entry(@swordman_id, catalog_id(:sm_sword))

      assert max_level == 10
    end

    test "inherited Novice skills are kept when implemented, unimplemented ones filtered out" do
      tree = SkillTree.tree_for(@swordman_id)

      assert Map.has_key?(tree, catalog_id(:nv_firstaid))
      assert Map.has_key?(tree, catalog_id(:nv_trickdead))
      assert Map.has_key?(tree, catalog_id(:nv_basic))
      assert map_size(tree) == 13
    end

    test "entry/2 returns :error for a skill not in the job tree" do
      assert :error = SkillTree.entry(@swordman_id, 999_999)
    end

    test "tree_for/1 returns an empty map for an unknown job" do
      assert SkillTree.tree_for(999_999) == %{}
    end
  end

  describe "reload/0" do
    test "rebuilds the index" do
      assert :ok = SkillTree.reload()
      assert map_size(SkillTree.tree_for(@swordman_id)) == 13
    end
  end

  describe "flatten_inherit/1 (pure, fixture data)" do
    test "child inherits a parent's entry" do
      raw = %{
        "parent" => [%{"name" => "P_SKILL", "max_level" => 5}],
        "child" => %{
          inherit: ["parent"],
          tree: [%{"name" => "C_SKILL", "max_level" => 3}]
        }
      }

      flattened = SkillTree.flatten_inherit(raw)

      names = flattened |> Map.fetch!("child") |> Enum.map(& &1["name"]) |> Enum.sort()
      assert names == ["C_SKILL", "P_SKILL"]
    end

    test "child override of an inherited skill wins" do
      raw = %{
        "parent" => [%{"name" => "P_SKILL", "max_level" => 5}],
        "child" => %{
          inherit: ["parent"],
          tree: [%{"name" => "P_SKILL", "max_level" => 1}]
        }
      }

      flattened = SkillTree.flatten_inherit(raw)
      [entry] = Map.fetch!(flattened, "child")

      assert entry["name"] == "P_SKILL"
      assert entry["max_level"] == 1
    end

    test "child excludes an inherited skill" do
      raw = %{
        "parent" => [
          %{"name" => "P_KEEP", "max_level" => 5},
          %{"name" => "P_DROP", "max_level" => 5}
        ],
        "child" => %{
          inherit: ["parent"],
          tree: [%{"name" => "P_DROP", "max_level" => 1, "exclude" => true}]
        }
      }

      flattened = SkillTree.flatten_inherit(raw)
      names = flattened |> Map.fetch!("child") |> Enum.map(& &1["name"])

      assert names == ["P_KEEP"]
    end

    test "inheritance is transitive across chains" do
      raw = %{
        "grandparent" => [%{"name" => "G_SKILL", "max_level" => 5}],
        "parent" => %{
          inherit: ["grandparent"],
          tree: [%{"name" => "P_SKILL", "max_level" => 5}]
        },
        "child" => %{
          inherit: ["parent"],
          tree: [%{"name" => "C_SKILL", "max_level" => 5}]
        }
      }

      flattened = SkillTree.flatten_inherit(raw)
      names = flattened |> Map.fetch!("child") |> Enum.map(& &1["name"]) |> Enum.sort()

      assert names == ["C_SKILL", "G_SKILL", "P_SKILL"]
    end
  end

  describe "can_learn/2" do
    test "returns :ok for a learnable tree skill with a point and met levels" do
      progression = swordman_progression(skill_point: 1)
      assert :ok = SkillTree.can_learn(progression, catalog_id(:sm_sword))
    end

    test "returns :not_in_tree for a skill absent from the job tree" do
      progression = swordman_progression([])
      assert {:error, :not_in_tree} = SkillTree.can_learn(progression, 999_999)
    end

    test "returns :no_skill_points when no points remain" do
      progression = swordman_progression(skill_point: 0)
      assert {:error, :no_skill_points} = SkillTree.can_learn(progression, catalog_id(:sm_sword))
    end

    test "returns :max_level when the skill is already at its cap" do
      sword_id = catalog_id(:sm_sword)
      progression = swordman_progression(learned_skills: %{sword_id => 10})
      assert {:error, :max_level} = SkillTree.can_learn(progression, sword_id)
    end

    test "returns :missing_prerequisite when a required skill is not high enough" do
      progression = swordman_progression(learned_skills: %{})

      assert {:error, :missing_prerequisite} =
               SkillTree.can_learn(progression, catalog_id(:sm_twohand))
    end

    test "returns :level_too_low when base/job minimums are not met" do
      entry = %Entry{
        skill_id: catalog_id(:sm_sword),
        owner_job_id: @swordman_id,
        max_level: 10,
        base_level: 50,
        job_level: 10
      }

      progression = swordman_progression(base_level: 10, job_level: 1)

      assert {:error, :level_too_low} = SkillTree.can_learn_entry(progression, entry)
    end

    test "a satisfied prerequisite unlocks the dependent skill" do
      sword_id = catalog_id(:sm_sword)
      progression = swordman_progression(learned_skills: %{sword_id => 1})
      assert :ok = SkillTree.can_learn(progression, catalog_id(:sm_twohand))
    end
  end

  describe "learn/2" do
    test "valid request bumps the level by one and spends a point" do
      sword_id = catalog_id(:sm_sword)
      progression = swordman_progression(skill_point: 3, learned_skills: %{sword_id => 2})

      {:ok, updated} = SkillTree.learn(progression, sword_id)

      assert updated.learned_skills[sword_id] == 3
      assert updated.skill_point == 2
    end

    test "learning an unlearned skill sets it to level 1" do
      bash_id = catalog_id(:sm_bash)
      progression = swordman_progression(skill_point: 1)

      {:ok, updated} = SkillTree.learn(progression, bash_id)

      assert updated.learned_skills[bash_id] == 1
      assert updated.skill_point == 0
    end

    test "invalid request returns the error and leaves progression unchanged" do
      progression = swordman_progression(skill_point: 0)

      assert {:error, :no_skill_points} = SkillTree.learn(progression, catalog_id(:sm_sword))
    end
  end

  describe "available_for/1" do
    test "annotates a learnable level-0 skill as upgradable" do
      progression = swordman_progression(skill_point: 1)
      view = SkillTree.available_for(progression)

      entry = Enum.find(view, &(&1.skill_id == catalog_id(:sm_sword)))
      assert entry.level == 0
      assert entry.upgradable == true
    end

    test "annotates a level-0 skill with an unmet prerequisite as not upgradable" do
      progression = swordman_progression(skill_point: 1, learned_skills: %{})
      view = SkillTree.available_for(progression)

      entry = Enum.find(view, &(&1.skill_id == catalog_id(:sm_twohand)))
      assert entry.level == 0
      assert entry.upgradable == false
      assert entry.requires == [{catalog_id(:sm_sword), 1}]
    end

    test "covers every entry in the job tree" do
      progression = swordman_progression([])
      view = SkillTree.available_for(progression)
      assert length(view) == map_size(SkillTree.tree_for(@swordman_id))
    end

    test "annotates each entry with the job that owns the skill" do
      {:ok, novice_id} = AvailableJobs.job_name_to_id(:novice)
      view = SkillTree.available_for(swordman_progression([]))

      sword = Enum.find(view, &(&1.skill_id == catalog_id(:sm_sword)))
      assert sword.owner_job_id == @swordman_id

      first_aid = Enum.find(view, &(&1.skill_id == catalog_id(:nv_firstaid)))
      assert first_aid.owner_job_id == novice_id
    end
  end

  describe "Catalog filtering" do
    test "AL_INCAGI keeps its AL_HEAL prerequisite now that it is implemented" do
      {:ok, acolyte_id} = AvailableJobs.job_name_to_id(:acolyte)

      {:ok, %Entry{requires: requires}} =
        SkillTree.entry(acolyte_id, catalog_id(:al_incagi))

      assert requires == [{catalog_id(:al_heal), 3}]
    end

    test "warns when a tree entry names an unimplemented skill" do
      log =
        capture_log(fn ->
          SkillTree.reload()
        end)

      assert log =~ "WE_CALLBABY"
    end
  end

  describe "reset_skills/1" do
    test "refunds the sum of learned levels into skill_point and clears them" do
      progression =
        swordman_progression(
          skill_point: 2,
          learned_skills: %{catalog_id(:sm_bash) => 5, catalog_id(:sm_endure) => 3}
        )

      reset = SkillTree.reset_skills(progression)

      assert reset.skill_point == 2 + 5 + 3
      assert reset.learned_skills == %{}
    end

    test "keeps NV_BASIC (not refunded) for a non-Novice player" do
      nv_basic = catalog_id(:nv_basic)

      progression =
        swordman_progression(
          skill_point: 0,
          learned_skills: %{nv_basic => 9, catalog_id(:sm_bash) => 4}
        )

      reset = SkillTree.reset_skills(progression)

      assert reset.skill_point == 4
      assert reset.learned_skills == %{nv_basic => 9}
    end

    test "refunds NV_BASIC too for a Novice player" do
      {:ok, novice_id} = AvailableJobs.job_name_to_id(:novice)
      nv_basic = catalog_id(:nv_basic)

      progression =
        swordman_progression(
          job_id: novice_id,
          skill_point: 1,
          learned_skills: %{nv_basic => 9}
        )

      reset = SkillTree.reset_skills(progression)

      assert reset.skill_point == 1 + 9
      assert reset.learned_skills == %{}
    end
  end
end
