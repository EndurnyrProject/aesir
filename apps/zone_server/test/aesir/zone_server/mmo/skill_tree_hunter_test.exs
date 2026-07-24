defmodule Aesir.ZoneServer.Mmo.SkillTreeHunterTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias Aesir.ZoneServer.Mmo.DataLoader
  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.SkillTree
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression

  @hunter_entries MapSet.new([
                    {"HT_LANDMINE", 5, []},
                    {"HT_BEASTBANE", 10, []},
                    {"HT_FALCON", 1, [{"HT_BEASTBANE", 1}]},
                    {"HT_BLITZBEAT", 5, [{"HT_FALCON", 1}]},
                    {"HT_STEELCROW", 10, [{"HT_BLITZBEAT", 5}]},
                    {"HT_DETECTING", 4, [{"AC_CONCENTRATION", 1}, {"HT_FALCON", 1}]},
                    {"HT_REMOVETRAP", 1, [{"HT_LANDMINE", 1}]},
                    {"HT_SPRINGTRAP", 5, [{"HT_REMOVETRAP", 1}, {"HT_FALCON", 1}]}
                  ])

  test "Hunter YAML declares only the approved canonical entries" do
    assert normalized_entry_set(normalized_entries()) == normalized_entry_set(@hunter_entries)
  end

  test "Hunter resolves its selected skills and inherits Novice and Archer entries" do
    {:ok, hunter_id} = AvailableJobs.job_name_to_id(:hunter)
    {:ok, novice_id} = AvailableJobs.job_name_to_id(:novice)
    {:ok, archer_id} = AvailableJobs.job_name_to_id(:archer)
    hunter_tree = SkillTree.tree_for(hunter_id)

    for parent_id <- [novice_id, archer_id],
        {skill_id, parent_entry} <- SkillTree.tree_for(parent_id) do
      assert hunter_tree[skill_id].owner_job_id == parent_entry.owner_job_id
    end

    assert normalized_entry_set(hunter_owned_entries(hunter_id)) ==
             normalized_entry_set(@hunter_entries)

    log = capture_log(&SkillTree.reload/0)

    for {name, _max_level, _requires} <- @hunter_entries do
      assert {:ok, _definition} = Catalog.by_name(atomize(name))
      refute log =~ ~s(references unimplemented skill "#{name}")
    end
  end

  test "Hunter prerequisite gates match the approved branch" do
    {:ok, hunter_id} = AvailableJobs.job_name_to_id(:hunter)
    progression = hunter_progression(hunter_id, learned_skills: %{})

    assert :ok = SkillTree.can_learn(progression, catalog_id(:ht_landmine))
    assert :ok = SkillTree.can_learn(progression, catalog_id(:ht_beastbane))

    assert {:error, :missing_prerequisite} =
             SkillTree.can_learn(progression, catalog_id(:ht_falcon))

    assert :ok =
             SkillTree.can_learn(
               %{progression | learned_skills: %{catalog_id(:ht_beastbane) => 1}},
               catalog_id(:ht_falcon)
             )

    assert {:error, :missing_prerequisite} =
             SkillTree.can_learn(progression, catalog_id(:ht_blitzbeat))

    assert {:error, :missing_prerequisite} =
             SkillTree.can_learn(
               progression,
               catalog_id(:ht_steelcrow)
             )

    assert :ok =
             SkillTree.can_learn(
               %{progression | learned_skills: %{catalog_id(:ht_blitzbeat) => 5}},
               catalog_id(:ht_steelcrow)
             )

    assert {:error, :missing_prerequisite} =
             SkillTree.can_learn(
               %{progression | learned_skills: %{catalog_id(:ac_concentration) => 1}},
               catalog_id(:ht_detecting)
             )

    assert :ok =
             SkillTree.can_learn(
               %{
                 progression
                 | learned_skills: %{
                     catalog_id(:ac_concentration) => 1,
                     catalog_id(:ht_falcon) => 1
                   }
               },
               catalog_id(:ht_detecting)
             )

    assert {:error, :missing_prerequisite} =
             SkillTree.can_learn(progression, catalog_id(:ht_removetrap))

    assert :ok =
             SkillTree.can_learn(
               %{progression | learned_skills: %{catalog_id(:ht_landmine) => 1}},
               catalog_id(:ht_removetrap)
             )

    assert {:error, :missing_prerequisite} =
             SkillTree.can_learn(
               %{progression | learned_skills: %{catalog_id(:ht_removetrap) => 1}},
               catalog_id(:ht_springtrap)
             )

    assert :ok =
             SkillTree.can_learn(
               %{
                 progression
                 | learned_skills: %{
                     catalog_id(:ht_removetrap) => 1,
                     catalog_id(:ht_falcon) => 1
                   }
               },
               catalog_id(:ht_springtrap)
             )
  end

  test "Blast Mine is catalogued but excluded from ordinary Hunter learning" do
    {:ok, hunter_id} = AvailableJobs.job_name_to_id(:hunter)
    blast_mine = catalog_id(:ht_blastmine)
    tree = SkillTree.tree_for(hunter_id)

    refute Map.has_key?(tree, blast_mine)
    assert {:error, :not_in_tree} = SkillTree.can_learn(hunter_progression(hunter_id), blast_mine)
  end

  defp normalized_entry_set(entries) do
    entries
    |> Enum.map(fn {name, max_level, requires} ->
      {name, max_level, MapSet.new(requires)}
    end)
    |> MapSet.new()
  end

  defp normalized_entries do
    path = Path.join(Application.app_dir(:zone_server, "priv/db/skill_tree"), "hunter.yml")

    [%{"job" => "hunter", "inherit" => ["novice", "archer"], "tree" => tree}] =
      DataLoader.parse_file(path)

    Enum.map(tree, fn entry ->
      requires = Enum.map(Map.get(entry, "requires", []), &{&1["name"], &1["level"]})
      {entry["name"], entry["max_level"], requires}
    end)
  end

  defp hunter_owned_entries(hunter_id) do
    hunter_id
    |> SkillTree.tree_for()
    |> Map.values()
    |> Enum.filter(&(&1.owner_job_id == hunter_id))
    |> Enum.map(fn entry ->
      requires =
        Enum.map(entry.requires, fn {skill_id, level} -> {catalog_name(skill_id), level} end)

      {catalog_name(entry.skill_id), entry.max_level, requires}
    end)
  end

  defp hunter_progression(hunter_id, attrs \\ []) do
    Map.merge(
      %PlayerProgression{
        base_level: 99,
        job_level: 50,
        base_exp: 0,
        job_exp: 0,
        job_id: hunter_id,
        skill_point: 99,
        status_point: 0,
        learned_skills: %{}
      },
      Map.new(attrs)
    )
  end

  defp catalog_name(skill_id) do
    {:ok, definition} = Catalog.by_id(skill_id)
    definition.name |> Atom.to_string() |> String.upcase()
  end

  defp catalog_id(name) do
    {:ok, definition} = Catalog.by_name(name)
    definition.id
  end

  defp atomize(name), do: name |> String.downcase() |> String.to_atom()
end
