defmodule Aesir.ZoneServer.Mmo.SkillTreeThiefTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.SkillTree
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression

  {:ok, thief_id} = AvailableJobs.job_name_to_id(:thief)
  @thief_id thief_id

  @thief_skills [
    :tf_double,
    :tf_miss,
    :tf_steal,
    :tf_hiding,
    :tf_poison,
    :tf_detoxify,
    :tf_sprinklesand,
    :tf_backsliding,
    :tf_pickstone,
    :tf_throwstone
  ]

  defp catalog_id(name) do
    {:ok, definition} = Catalog.by_name(name)
    definition.id
  end

  defp thief_progression(attrs) do
    Map.merge(
      %PlayerProgression{
        base_level: 99,
        job_level: 50,
        base_exp: 0,
        job_exp: 0,
        job_id: @thief_id,
        skill_point: 1,
        status_point: 0,
        learned_skills: %{}
      },
      Map.new(attrs)
    )
  end

  describe "tree_for/1 (real data)" do
    test "all 10 Thief skills resolve into the tree" do
      tree = SkillTree.tree_for(@thief_id)

      for name <- @thief_skills do
        assert Map.has_key?(tree, catalog_id(name)), "expected #{name} in Thief tree"
      end
    end

    test "max_level values match rAthena" do
      tree = SkillTree.tree_for(@thief_id)

      assert tree[catalog_id(:tf_double)].max_level == 10
      assert tree[catalog_id(:tf_miss)].max_level == 10
      assert tree[catalog_id(:tf_steal)].max_level == 10
      assert tree[catalog_id(:tf_hiding)].max_level == 10
      assert tree[catalog_id(:tf_poison)].max_level == 10
      assert tree[catalog_id(:tf_detoxify)].max_level == 1
      assert tree[catalog_id(:tf_sprinklesand)].max_level == 1
      assert tree[catalog_id(:tf_backsliding)].max_level == 1
      assert tree[catalog_id(:tf_pickstone)].max_level == 1
      assert tree[catalog_id(:tf_throwstone)].max_level == 1
    end

    test "no Thief skill is dropped as unimplemented when reloading the tree" do
      log = capture_log(fn -> SkillTree.reload() end)

      for name <- Enum.map(@thief_skills, &(&1 |> Atom.to_string() |> String.upcase())) do
        refute log =~ ~r/references unimplemented skill "#{name}"/
      end
    end
  end

  describe "prerequisite gating" do
    test "Double Attack and Steal are learnable with no prerequisites" do
      assert :ok =
               SkillTree.can_learn(
                 thief_progression(learned_skills: %{}),
                 catalog_id(:tf_double)
               )

      assert :ok =
               SkillTree.can_learn(
                 thief_progression(learned_skills: %{}),
                 catalog_id(:tf_steal)
               )
    end

    test "Hiding requires Steal level 5" do
      hiding = catalog_id(:tf_hiding)
      steal = catalog_id(:tf_steal)

      assert {:error, :missing_prerequisite} =
               SkillTree.can_learn(thief_progression(learned_skills: %{steal => 4}), hiding)

      assert :ok = SkillTree.can_learn(thief_progression(learned_skills: %{steal => 5}), hiding)
    end

    test "Detoxify requires Envenom level 3" do
      detoxify = catalog_id(:tf_detoxify)
      poison = catalog_id(:tf_poison)

      assert {:error, :missing_prerequisite} =
               SkillTree.can_learn(thief_progression(learned_skills: %{poison => 2}), detoxify)

      assert :ok =
               SkillTree.can_learn(thief_progression(learned_skills: %{poison => 3}), detoxify)
    end

    test "the four quest skills are learnable with no prerequisites" do
      for name <- [:tf_sprinklesand, :tf_backsliding, :tf_pickstone, :tf_throwstone] do
        assert :ok =
                 SkillTree.can_learn(thief_progression(learned_skills: %{}), catalog_id(name))
      end
    end
  end
end
