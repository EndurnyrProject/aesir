defmodule Aesir.ZoneServer.Mmo.SkillTreeAlchemistTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.SkillTree

  test "Alchemist tree loads all Phase 1 skills and inherits Merchant without pruning" do
    log = capture_log(&SkillTree.reload/0)

    {:ok, alchemist_id} = AvailableJobs.job_name_to_id(:alchemist)
    tree = SkillTree.tree_for(alchemist_id)
    owned_entries = Enum.filter(Map.values(tree), &(&1.owner_job_id == alchemist_id))

    assert length(owned_entries) == 15

    for {name, max_level, requires} <- [
          {:am_axemastery, 10, []},
          {:am_learningpotion, 10, []},
          {:am_pharmacy, 10, [{:am_learningpotion, 5}]},
          {:am_demonstration, 5, [{:am_pharmacy, 4}]},
          {:am_acidterror, 5, [{:am_pharmacy, 5}]},
          {:am_potionpitcher, 5, [{:am_pharmacy, 3}]},
          {:am_cannibalize, 5, [{:am_pharmacy, 6}]},
          {:am_spheremine, 5, [{:am_pharmacy, 2}]},
          {:am_cp_helm, 5, [{:am_pharmacy, 2}]},
          {:am_cp_shield, 5, [{:am_cp_helm, 3}]},
          {:am_cp_armor, 5, [{:am_cp_shield, 3}]},
          {:am_cp_weapon, 5, [{:am_cp_armor, 3}]},
          {:am_rest, 1, [{:am_bioethics, 1}]},
          {:am_callhomun, 1, [{:am_rest, 1}]},
          {:am_resurrecthomun, 5, [{:am_callhomun, 1}]}
        ] do
      {:ok, definition} = Catalog.by_name(name)
      entry = tree[definition.id]

      assert entry.max_level == max_level

      assert entry.requires ==
               Enum.map(requires, fn {required_name, level} ->
                 {:ok, required_definition} = Catalog.by_name(required_name)
                 {required_definition.id, level}
               end)
    end

    {:ok, discount} = Catalog.by_name(:mc_discount)
    assert Map.has_key?(tree, discount.id)

    {:ok, bioethics} = Catalog.by_name(:am_bioethics)
    refute Map.has_key?(tree, bioethics.id)

    assert log == ""
  end
end
