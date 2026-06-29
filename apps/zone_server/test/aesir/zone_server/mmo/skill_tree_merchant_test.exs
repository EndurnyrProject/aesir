defmodule Aesir.ZoneServer.Mmo.SkillTreeMerchantTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.McChangecart
  alias Aesir.ZoneServer.Mmo.Skills.McPushcart
  alias Aesir.ZoneServer.Mmo.SkillTree
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression

  {:ok, merchant_id} = AvailableJobs.job_name_to_id(:merchant)
  @merchant_id merchant_id

  defp catalog_id(name) do
    {:ok, definition} = Catalog.by_name(name)
    definition.id
  end

  defp merchant_progression(attrs) do
    Map.merge(
      %PlayerProgression{
        base_level: 99,
        job_level: 50,
        base_exp: 0,
        job_exp: 0,
        job_id: @merchant_id,
        skill_point: 1,
        status_point: 0,
        learned_skills: %{}
      },
      Map.new(attrs)
    )
  end

  describe "catalog registration" do
    test "Pushcart resolves by name and by id 39" do
      assert {:ok, definition} = Catalog.by_name(:mc_pushcart)
      assert definition.id == 39
      assert {:ok, ^definition} = Catalog.by_id(39)
    end

    test "Pushcart exposes the passive capability" do
      assert :passive in McPushcart.__skill_capabilities__()
    end

    test "Change Cart resolves by name and by id 154" do
      assert {:ok, definition} = Catalog.by_name(:mc_changecart)
      assert definition.id == 154
      assert {:ok, ^definition} = Catalog.by_id(154)
    end

    test "Change Cart exposes the active capability" do
      assert :active in McChangecart.__skill_capabilities__()
    end
  end

  describe "tree_for/1 (real data)" do
    test "Pushcart resolves into the Merchant tree at max level 10" do
      tree = SkillTree.tree_for(@merchant_id)

      assert Map.has_key?(tree, catalog_id(:mc_pushcart)), "expected mc_pushcart in Merchant tree"
      assert tree[catalog_id(:mc_pushcart)].max_level == 10
    end

    test "Pushcart is not dropped as unimplemented when reloading the tree" do
      log = capture_log(fn -> SkillTree.reload() end)

      refute log =~ ~r/references unimplemented skill "MC_PUSHCART"/
    end

    test "Change Cart resolves into the Merchant tree at max level 1" do
      tree = SkillTree.tree_for(@merchant_id)

      assert Map.has_key?(tree, catalog_id(:mc_changecart)),
             "expected mc_changecart in Merchant tree"

      assert tree[catalog_id(:mc_changecart)].max_level == 1
    end

    test "Change Cart is not dropped as unimplemented when reloading the tree" do
      log = capture_log(fn -> SkillTree.reload() end)

      refute log =~ ~r/references unimplemented skill "MC_CHANGECART"/
    end
  end

  describe "prerequisite gating" do
    test "Pushcart is learnable with no prerequisites" do
      assert :ok =
               SkillTree.can_learn(
                 merchant_progression(learned_skills: %{}),
                 catalog_id(:mc_pushcart)
               )
    end

    test "Change Cart requires MC_PUSHCART learned" do
      learned = %{catalog_id(:mc_pushcart) => 1}

      assert :ok =
               SkillTree.can_learn(
                 merchant_progression(learned_skills: learned),
                 catalog_id(:mc_changecart)
               )

      assert {:error, :missing_prerequisite} =
               SkillTree.can_learn(
                 merchant_progression(learned_skills: %{}),
                 catalog_id(:mc_changecart)
               )
    end
  end
end
