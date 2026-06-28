defmodule Aesir.ZoneServer.Mmo.SkillTreeArcherTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.SkillTree
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression

  {:ok, archer_id} = AvailableJobs.job_name_to_id(:archer)
  @archer_id archer_id

  @archer_skills [
    :ac_owl,
    :ac_vulture,
    :ac_concentration,
    :ac_double,
    :ac_shower
  ]

  defp catalog_id(name) do
    {:ok, definition} = Catalog.by_name(name)
    definition.id
  end

  defp archer_progression(attrs) do
    Map.merge(
      %PlayerProgression{
        base_level: 99,
        job_level: 50,
        base_exp: 0,
        job_exp: 0,
        job_id: @archer_id,
        skill_point: 1,
        status_point: 0,
        learned_skills: %{}
      },
      Map.new(attrs)
    )
  end

  describe "tree_for/1 (real data)" do
    test "all 5 Archer skills resolve into the tree" do
      tree = SkillTree.tree_for(@archer_id)

      for name <- @archer_skills do
        assert Map.has_key?(tree, catalog_id(name)), "expected #{name} in Archer tree"
      end
    end

    test "max_level values match rAthena" do
      tree = SkillTree.tree_for(@archer_id)

      assert tree[catalog_id(:ac_owl)].max_level == 10
      assert tree[catalog_id(:ac_vulture)].max_level == 10
      assert tree[catalog_id(:ac_concentration)].max_level == 10
      assert tree[catalog_id(:ac_double)].max_level == 10
      assert tree[catalog_id(:ac_shower)].max_level == 10
    end

    test "no Archer skill is dropped as unimplemented when reloading the tree" do
      log = capture_log(fn -> SkillTree.reload() end)

      for name <- Enum.map(@archer_skills, &(&1 |> Atom.to_string() |> String.upcase())) do
        refute log =~ ~r/references unimplemented skill "#{name}"/
      end
    end
  end

  describe "prerequisite gating" do
    test "Owl's Eye is learnable with no prerequisites" do
      assert :ok =
               SkillTree.can_learn(
                 archer_progression(learned_skills: %{}),
                 catalog_id(:ac_owl)
               )
    end

    test "Double Strafe is learnable with no prerequisites" do
      assert :ok =
               SkillTree.can_learn(
                 archer_progression(learned_skills: %{}),
                 catalog_id(:ac_double)
               )
    end

    test "Vulture's Eye requires Owl's Eye level 3" do
      vulture = catalog_id(:ac_vulture)
      owl = catalog_id(:ac_owl)

      assert {:error, :missing_prerequisite} =
               SkillTree.can_learn(archer_progression(learned_skills: %{owl => 2}), vulture)

      assert :ok =
               SkillTree.can_learn(archer_progression(learned_skills: %{owl => 3}), vulture)
    end

    test "Improve Concentration requires Vulture's Eye level 1" do
      concentration = catalog_id(:ac_concentration)
      vulture = catalog_id(:ac_vulture)
      owl = catalog_id(:ac_owl)

      assert {:error, :missing_prerequisite} =
               SkillTree.can_learn(
                 archer_progression(learned_skills: %{owl => 3}),
                 concentration
               )

      assert :ok =
               SkillTree.can_learn(
                 archer_progression(learned_skills: %{owl => 3, vulture => 1}),
                 concentration
               )
    end

    test "Arrow Shower requires Double Strafe level 5" do
      shower = catalog_id(:ac_shower)
      double = catalog_id(:ac_double)

      assert {:error, :missing_prerequisite} =
               SkillTree.can_learn(archer_progression(learned_skills: %{double => 4}), shower)

      assert :ok =
               SkillTree.can_learn(archer_progression(learned_skills: %{double => 5}), shower)
    end
  end
end
