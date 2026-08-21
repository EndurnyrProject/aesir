defmodule Aesir.ZoneServer.Mmo.SkillTreeTest do
  use ExUnit.Case, async: false

  @moduletag :capture_log

  import ExUnit.CaptureLog
  import Mimic

  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.SkillTree
  alias Aesir.ZoneServer.Mmo.SkillTree.Entry
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression

  {:ok, swordman_id} = AvailableJobs.job_name_to_id(:swordman)
  @swordman_id swordman_id
  {:ok, hunter_id} = AvailableJobs.job_name_to_id(:hunter)
  @hunter_id hunter_id
  @quest_skill_id 99_022
  @hunter_quest_skill_id 99_023
  @quest_definition Definition.build!(
                      [
                        id: @quest_skill_id,
                        name: :fixture_archer_quest,
                        display_name: "Fixture Archer Quest",
                        max_level: 1,
                        quest_skill: true,
                        quest_owner_job: :archer
                      ],
                      __MODULE__
                    )
  @hunter_quest_definition Definition.build!(
                             [
                               id: @hunter_quest_skill_id,
                               name: :fixture_hunter_quest,
                               display_name: "Fixture Hunter Quest",
                               max_level: 1,
                               quest_skill: true,
                               quest_owner_job: :hunter
                             ],
                             __MODULE__
                           )
  @taekwon_quest_definition Definition.build!(
                              [
                                id: 99_024,
                                name: :fixture_taekwon_quest,
                                display_name: "Fixture Taekwon Quest",
                                max_level: 1,
                                quest_skill: true,
                                quest_owner_job: :taekwon
                              ],
                              __MODULE__
                            )

  defp stub_quest_definitions(definitions \\ [@quest_definition]) do
    definitions_by_id = Map.new(definitions, &{&1.id, &1})

    stub(Catalog, :by_id, fn skill_id ->
      case Map.fetch(definitions_by_id, skill_id) do
        {:ok, definition} -> {:ok, definition}
        :error -> call_original(Catalog, :by_id, [skill_id])
      end
    end)
  end

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

  describe "import overlay" do
    setup context do
      on_exit(&SkillTree.reload/0)
      Aesir.ZoneServer.DbTestSetup.configure_root(context, "skill_tree")
    end

    @tag :tmp_dir
    test "reload replaces a job tree with its imported definition", %{tmp_dir: dir} do
      base = Path.join(dir, "novice.yml")
      File.write!(base, "- job: novice\n  tree:\n    - name: NV_BASIC\n      max_level: 9\n")

      import = Path.join([dir, "..", "..", "import", "skill_tree", "custom.yml"])
      File.mkdir_p!(Path.dirname(import))
      File.write!(import, "- job: novice\n  tree:\n    - name: NV_FIRSTAID\n      max_level: 1\n")

      assert :ok = SkillTree.reload()
      assert {:ok, %Entry{max_level: 1}} = SkillTree.entry(0, catalog_id(:nv_firstaid))
      assert :error = SkillTree.entry(0, catalog_id(:nv_basic))
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

    test "covers every non-quest entry in the job tree and hides unlearned quest skills" do
      progression = swordman_progression([])
      view = SkillTree.available_for(progression)
      view_ids = MapSet.new(view, & &1.skill_id)

      {quest_ids, normal_ids} =
        @swordman_id
        |> SkillTree.tree_for()
        |> Map.keys()
        |> Enum.split_with(fn id ->
          match?({:ok, %Definition{quest_skill: true}}, Catalog.by_id(id))
        end)

      assert Enum.all?(normal_ids, &(&1 in view_ids))
      refute Enum.any?(quest_ids, &(&1 in view_ids))
    end

    test "annotates each entry with the job that owns the skill" do
      {:ok, novice_id} = AvailableJobs.job_name_to_id(:novice)
      first_aid_id = catalog_id(:nv_firstaid)
      view = SkillTree.available_for(swordman_progression(learned_skills: %{first_aid_id => 1}))

      sword = Enum.find(view, &(&1.skill_id == catalog_id(:sm_sword)))
      assert sword.owner_job_id == @swordman_id

      first_aid = Enum.find(view, &(&1.skill_id == first_aid_id))
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
      # Driven off a hidden catalog entry rather than a real gap in the tree:
      # every name the YAML uses today resolves, and the last one that did not
      # was removed from the tree instead of being implemented.
      hidden = catalog_id(:sm_sword)

      stub(Catalog, :all, fn ->
        Enum.reject(call_original(Catalog, :all, []), &(&1.id == hidden))
      end)

      on_exit(&SkillTree.reload/0)

      log = capture_log(fn -> SkillTree.reload() end)

      assert log =~ "references unimplemented skill \"SM_SWORD\""
      assert SkillTree.entry(@swordman_id, hidden) == :error
    end
  end

  describe "quest skill lineage" do
    test "Assassin quest skills stay outside point spending and on the Assassin branch" do
      {:ok, assassin_id} = AvailableJobs.job_name_to_id(:assassin)
      progression = swordman_progression(job_id: assassin_id, learned_skills: %{})

      for skill_id <- [1003, 1004] do
        assert {:ok, %Definition{} = definition} = Catalog.by_id(skill_id)
        assert definition.quest_skill
        assert definition.quest_owner_job == :assassin
        refute Map.has_key?(SkillTree.tree_for(assassin_id), skill_id)
        refute Enum.any?(SkillTree.available_for(progression), &(&1.skill_id == skill_id))
        assert {:error, :not_in_tree} = SkillTree.learn(progression, skill_id)

        for job <- [
              :assassin,
              :assassin_cross,
              :baby_assassin,
              :guillotine_cross,
              :guillotine_cross_t,
              :baby_guillotine_cross,
              :shadow_cross
            ] do
          {:ok, job_id} = AvailableJobs.job_name_to_id(job)
          assert SkillTree.quest_skill_available?(job_id, definition)
        end

        for job <- [:thief, :rogue] do
          {:ok, job_id} = AvailableJobs.job_name_to_id(job)
          refute SkillTree.quest_skill_available?(job_id, definition)
        end
      end
    end

    test "adds a learned grant-only quest skill for an eligible lineage with its owner job id" do
      stub_quest_definitions()

      [quest] =
        swordman_progression(
          job_id: @hunter_id,
          learned_skills: %{@quest_skill_id => 1}
        )
        |> SkillTree.available_for()
        |> Enum.filter(&(&1.skill_id == @quest_skill_id))

      {:ok, archer_id} = AvailableJobs.job_name_to_id(:archer)
      assert quest.owner_job_id == archer_id
      assert quest.level == 1
      refute quest.upgradable
    end

    test "covers every Archer descendant across normal, trans, baby, third, fourth, and mounted jobs" do
      eligible_job_ids = [
        3,
        11,
        19,
        20,
        4004,
        4012,
        4020,
        4021,
        4026,
        4034,
        4042,
        4043,
        4056,
        4062,
        4068,
        4069,
        4075,
        4076,
        4084,
        4085,
        4098,
        4104,
        4105,
        4111,
        4257,
        4263,
        4264,
        4278
      ]

      assert Enum.all?(eligible_job_ids, &SkillTree.quest_skill_available?(&1, @quest_definition))
    end

    test "rejects cross-lineage and unknown jobs for an Archer-owned quest skill" do
      invalid_job_ids = [1, 2, 4, 5, 6, 7, 12, 14, 15, 16, 17, 18, 999_999]

      refute Enum.any?(invalid_job_ids, &SkillTree.quest_skill_available?(&1, @quest_definition))
    end

    test "covers expanded, baby-expanded, advanced, fourth, and mounted descendants" do
      eligible_job_ids = [
        4046,
        4047,
        4048,
        4049,
        4225,
        4226,
        4227,
        4238,
        4239,
        4240,
        4241,
        4242,
        4243,
        4244,
        4302,
        4303,
        4316
      ]

      assert Enum.all?(
               eligible_job_ids,
               &SkillTree.quest_skill_available?(&1, @taekwon_quest_definition)
             )

      refute Enum.any?(
               [24, 25, 4211, 4212, 4215, 999_999],
               &SkillTree.quest_skill_available?(&1, @taekwon_quest_definition)
             )
    end

    test "a Hunter-owned quest such as HT_PHANTASMIC stays on the Hunter branch only" do
      eligible_job_ids = [11, 4012, 4034, 4056, 4062, 4084, 4085, 4098, 4111, 4257, 4278]

      sibling_or_pre_owner_job_ids = [
        3,
        19,
        20,
        4004,
        4020,
        4021,
        4026,
        4042,
        4043,
        4068,
        4069,
        4075,
        4076,
        4104,
        4105,
        4263,
        4264,
        999_999
      ]

      assert Enum.all?(
               eligible_job_ids,
               &SkillTree.quest_skill_available?(&1, @hunter_quest_definition)
             )

      refute Enum.any?(
               sibling_or_pre_owner_job_ids,
               &SkillTree.quest_skill_available?(&1, @hunter_quest_definition)
             )
    end

    test "hides the retained quest skill off-lineage and restores it on return" do
      stub_quest_definitions()

      off_lineage =
        swordman_progression(learned_skills: %{@quest_skill_id => 1})
        |> SkillTree.available_for()

      eligible =
        swordman_progression(job_id: @hunter_id, learned_skills: %{@quest_skill_id => 1})
        |> SkillTree.available_for()

      refute Enum.any?(off_lineage, &(&1.skill_id == @quest_skill_id))
      assert Enum.any?(eligible, &(&1.skill_id == @quest_skill_id))
    end

    test "reports the exact Hunter owner id for a retained Hunter quest skill" do
      stub_quest_definitions([@hunter_quest_definition])

      [quest] =
        swordman_progression(
          job_id: 4257,
          learned_skills: %{@hunter_quest_skill_id => 1}
        )
        |> SkillTree.available_for()
        |> Enum.filter(&(&1.skill_id == @hunter_quest_skill_id))

      assert quest.owner_job_id == @hunter_id
    end
  end

  describe "reset_skills/1" do
    test "keeps quest skills without refunding their levels" do
      stub_quest_definitions()

      progression =
        swordman_progression(
          skill_point: 2,
          learned_skills: %{@quest_skill_id => 1, catalog_id(:sm_bash) => 5}
        )

      reset = SkillTree.reset_skills(progression)

      assert reset.skill_point == 7
      assert reset.learned_skills == %{@quest_skill_id => 1}
    end

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
