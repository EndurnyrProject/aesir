defmodule Aesir.ZoneServer.Mmo.SkillTreeSageTest do
  use ExUnit.Case, async: false

  alias Aesir.ZoneServer.Mmo.DataLoader
  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.SkillTree
  alias Aesir.ZoneServer.Mmo.SkillTree.Entry

  # The Sage tree's canonical membership, transcribed from rAthena
  # db/re/skill_tree.yml:1017-1141 minus SA_ABRACADABRA (deferred).
  #
  # This list is FIXED: it describes what the Sage tree *is*, not what is
  # implemented yet. Landing a skill must never require editing it. An earlier
  # version tracked an implemented/not-yet-implemented frontier instead, which
  # made this file a merge conflict for all twelve SA_* skill tasks — the same
  # serialization the Wave 0 registry refactor existed to delete.
  @sage_tree_skills ~w(
    WZ_ESTIMATION WZ_EARTHSPIKE WZ_HEAVENDRIVE
    SA_ADVANCEDBOOK SA_CASTCANCEL SA_MAGICROD SA_SPELLBREAKER SA_FREECAST
    SA_AUTOSPELL SA_FLAMELAUNCHER SA_FROSTWEAPON SA_LIGHTNINGLOADER
    SA_SEISMICWEAPON SA_DRAGONOLOGY SA_VOLCANO SA_DELUGE SA_VIOLENTGALE
    SA_LANDPROTECTOR SA_DISPELL SA_CREATECON SA_ELEMENTWATER SA_ELEMENTGROUND
    SA_ELEMENTFIRE SA_ELEMENTWIND
  )

  test "boots without an unknown job warning for sage" do
    assert {:ok, _job_id} = AvailableJobs.job_name_to_id(:sage)
  end

  test "sage.yml lists exactly the canonical sage tree skills" do
    assert MapSet.new(tree_entry_names()) == MapSet.new(@sage_tree_skills)
  end

  test "no sage tree entry is silently dropped by a typo" do
    for name <- tree_entry_names() do
      resolves? = match?({:ok, _}, Catalog.by_name(atomize(name)))

      assert resolves? or name in @sage_tree_skills,
             "#{name} neither resolves in the catalog nor is a canonical sage skill - " <>
               "the tree loader silently filters unknown names, so this is almost " <>
               "certainly a typo in sage.yml"
    end
  end

  test "every sage tree entry that resolves keeps its own name" do
    {:ok, sage_id} = AvailableJobs.job_name_to_id(:sage)

    resolved =
      sage_id
      |> SkillTree.tree_for()
      |> Map.values()
      |> Enum.filter(&(&1.owner_job_id == sage_id))
      |> Enum.map(fn %Entry{skill_id: skill_id} ->
        {:ok, definition} = Catalog.by_id(skill_id)
        definition.name |> Atom.to_string() |> String.upcase()
      end)

    assert resolved != [], "the sage tree resolved nothing at all"
    assert Enum.all?(resolved, &(&1 in @sage_tree_skills))
    assert length(Enum.uniq(resolved)) == length(resolved)
  end

  defp tree_entry_names do
    path = Path.join(Application.app_dir(:zone_server, "priv/db/re/skill_tree"), "sage.yml")
    [%{"tree" => tree}] = DataLoader.parse_file(path)
    Enum.map(tree, & &1["name"])
  end

  defp atomize(name), do: name |> String.downcase() |> String.to_atom()
end
