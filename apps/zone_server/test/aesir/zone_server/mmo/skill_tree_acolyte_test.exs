defmodule Aesir.ZoneServer.Mmo.SkillTreeAcolyteTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.SkillTree
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression

  {:ok, acolyte_id} = AvailableJobs.job_name_to_id(:acolyte)
  @acolyte_id acolyte_id

  @tier1_skills [
    :al_heal,
    :al_incagi,
    :al_decagi,
    :al_blessing,
    :al_angelus,
    :al_cure,
    :al_crucis,
    :al_ruwach
  ]

  defp catalog_id(name) do
    {:ok, definition} = Catalog.by_name(name)
    definition.id
  end

  defp acolyte_progression(attrs) do
    Map.merge(
      %PlayerProgression{
        base_level: 99,
        job_level: 50,
        base_exp: 0,
        job_exp: 0,
        job_id: @acolyte_id,
        skill_point: 1,
        status_point: 0,
        learned_skills: %{}
      },
      Map.new(attrs)
    )
  end

  describe "tree_for/1 (real data)" do
    test "all 8 Tier 1 Acolyte skills resolve into the tree" do
      tree = SkillTree.tree_for(@acolyte_id)

      for name <- @tier1_skills do
        assert Map.has_key?(tree, catalog_id(name)), "expected #{name} in Acolyte tree"
      end
    end

    test "max_level values match rAthena" do
      tree = SkillTree.tree_for(@acolyte_id)

      assert tree[catalog_id(:al_heal)].max_level == 10
      assert tree[catalog_id(:al_incagi)].max_level == 10
      assert tree[catalog_id(:al_decagi)].max_level == 10
      assert tree[catalog_id(:al_blessing)].max_level == 10
      assert tree[catalog_id(:al_angelus)].max_level == 10
      assert tree[catalog_id(:al_cure)].max_level == 1
      assert tree[catalog_id(:al_crucis)].max_level == 10
      assert tree[catalog_id(:al_ruwach)].max_level == 1
    end

    test "no Tier 1 Acolyte skill is dropped as unimplemented when reloading the tree" do
      log = capture_log(fn -> SkillTree.reload() end)

      for name <- Enum.map(@tier1_skills, &(&1 |> Atom.to_string() |> String.upcase())) do
        refute log =~ ~r/references unimplemented skill "#{name}"/
      end
    end
  end

  describe "prerequisite gating" do
    test "Inc AGI requires Heal level 3" do
      incagi = catalog_id(:al_incagi)
      heal = catalog_id(:al_heal)

      assert {:error, :missing_prerequisite} =
               SkillTree.can_learn(acolyte_progression(learned_skills: %{heal => 2}), incagi)

      assert :ok =
               SkillTree.can_learn(acolyte_progression(learned_skills: %{heal => 3}), incagi)
    end

    test "Dec AGI requires Inc AGI level 1" do
      decagi = catalog_id(:al_decagi)
      incagi = catalog_id(:al_incagi)
      heal = catalog_id(:al_heal)

      assert {:error, :missing_prerequisite} =
               SkillTree.can_learn(acolyte_progression(learned_skills: %{heal => 3}), decagi)

      assert :ok =
               SkillTree.can_learn(
                 acolyte_progression(learned_skills: %{heal => 3, incagi => 1}),
                 decagi
               )
    end

    test "Cure requires Heal level 2" do
      cure = catalog_id(:al_cure)
      heal = catalog_id(:al_heal)

      assert {:error, :missing_prerequisite} =
               SkillTree.can_learn(acolyte_progression(learned_skills: %{heal => 1}), cure)

      assert :ok =
               SkillTree.can_learn(acolyte_progression(learned_skills: %{heal => 2}), cure)
    end

    test "Heal is learnable with no prerequisites" do
      assert :ok =
               SkillTree.can_learn(
                 acolyte_progression(learned_skills: %{}),
                 catalog_id(:al_heal)
               )
    end

    test "Ruwach is learnable with no prerequisites" do
      assert :ok =
               SkillTree.can_learn(
                 acolyte_progression(learned_skills: %{}),
                 catalog_id(:al_ruwach)
               )
    end

    test "Blessing, Angelus and Signum Crucis are learnable immediately (deferred prereqs dropped)" do
      base = acolyte_progression(learned_skills: %{})

      assert :ok = SkillTree.can_learn(base, catalog_id(:al_blessing))
      assert :ok = SkillTree.can_learn(base, catalog_id(:al_angelus))
      assert :ok = SkillTree.can_learn(base, catalog_id(:al_crucis))
    end
  end
end
