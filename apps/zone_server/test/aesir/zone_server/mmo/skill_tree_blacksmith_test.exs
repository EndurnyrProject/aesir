defmodule Aesir.ZoneServer.Mmo.SkillTreeBlacksmithTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.SkillTree

  test "Blacksmith tree loads all 24 nodes and inherits Merchant without pruning" do
    log = capture_log(&SkillTree.reload/0)

    {:ok, blacksmith_id} = AvailableJobs.job_name_to_id(:blacksmith)
    tree = SkillTree.tree_for(blacksmith_id)
    owned_entries = Enum.filter(Map.values(tree), &(&1.owner_job_id == blacksmith_id))

    assert length(owned_entries) == 24

    {:ok, finding_ore} = Catalog.by_name(:bs_findingore)
    {:ok, hilt_binding} = Catalog.by_name(:bs_hiltbinding)
    assert {hilt_binding.id, 1} in tree[finding_ore.id].requires

    {:ok, pushcart} = Catalog.by_name(:mc_pushcart)
    assert Map.has_key?(tree, pushcart.id)

    assert log == ""
  end
end
