defmodule Aesir.ZoneServer.Mmo.SkillTreeBlacksmithTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.SkillTree

  @expected_skills [
    :bs_adrenaline,
    :bs_adrenaline2,
    :bs_axe,
    :bs_dagger,
    :bs_enchantedstone,
    :bs_findingore,
    :bs_greed,
    :bs_hammerfall,
    :bs_hiltbinding,
    :bs_iron,
    :bs_knuckle,
    :bs_mace,
    :bs_maximize,
    :bs_orideocon,
    :bs_overthrust,
    :bs_repairweapon,
    :bs_skintemper,
    :bs_spear,
    :bs_steel,
    :bs_sword,
    :bs_twohandsword,
    :bs_unfairlytrick,
    :bs_weaponperfect,
    :bs_weaponresearch
  ]

  test "Blacksmith tree loads all 24 nodes and inherits Merchant without pruning" do
    log = capture_log(&SkillTree.reload/0)

    {:ok, blacksmith_id} = AvailableJobs.job_name_to_id(:blacksmith)
    tree = SkillTree.tree_for(blacksmith_id)
    owned_entries = Enum.filter(Map.values(tree), &(&1.owner_job_id == blacksmith_id))

    expected_ids =
      MapSet.new(@expected_skills, fn name ->
        {:ok, definition} = Catalog.by_name(name)

        refute log =~
                 ~s(references unimplemented skill "#{name |> Atom.to_string() |> String.upcase()}")

        definition.id
      end)

    assert MapSet.new(owned_entries, & &1.skill_id) == expected_ids

    {:ok, finding_ore} = Catalog.by_name(:bs_findingore)
    {:ok, hilt_binding} = Catalog.by_name(:bs_hiltbinding)
    assert {hilt_binding.id, 1} in tree[finding_ore.id].requires

    {:ok, pushcart} = Catalog.by_name(:mc_pushcart)
    assert Map.has_key?(tree, pushcart.id)
  end
end
