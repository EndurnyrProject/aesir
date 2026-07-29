defmodule Aesir.ZoneServer.Mmo.SkillTreeDancerTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias Aesir.ZoneServer.Mmo.DataLoader
  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.SkillTree
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression

  @dancer_entries MapSet.new([
                    {"DC_DANCINGLESSON", 10, []},
                    {"DC_THROWARROW", 5, [{"DC_DANCINGLESSON", 3}]},
                    {"BD_ADAPTATION", 1, []},
                    {"BD_ENCORE", 1, [{"BD_ADAPTATION", 1}]},
                    {"DC_UGLYDANCE", 5, [{"DC_DANCINGLESSON", 1}, {"BD_ADAPTATION", 1}]},
                    {"DC_SCREAM", 5, [{"BD_ENCORE", 1}]},
                    {"DC_HUMMING", 10, [{"DC_UGLYDANCE", 3}]},
                    {"DC_DONTFORGETME", 10, [{"DC_UGLYDANCE", 3}]},
                    {"DC_FORTUNEKISS", 10, [{"DC_UGLYDANCE", 3}]},
                    {"DC_SERVICEFORYOU", 10, [{"DC_UGLYDANCE", 3}]},
                    {"DC_WINKCHARM", 1, []}
                  ])

  @ensemble_entries MapSet.new([
                      "BD_LULLABY",
                      "BD_RICHMANKIM",
                      "BD_ETERNALCHAOS",
                      "BD_DRUMBATTLEFIELD",
                      "BD_RINGNIBELUNGEN",
                      "BD_ROKISWEIL",
                      "BD_INTOABYSS",
                      "BD_SIEGFRIED",
                      "BD_RAGNAROK"
                    ])

  test "Dancer YAML pins every solo skill and no ensemble skill" do
    assert MapSet.size(@dancer_entries) == 11
    assert normalized_entry_set(normalized_entries()) == normalized_entry_set(@dancer_entries)
  end

  test "Dancer entries resolve through the catalog and retain inherited trees" do
    {:ok, dancer_id} = AvailableJobs.job_name_to_id(:dancer)
    {:ok, novice_id} = AvailableJobs.job_name_to_id(:novice)
    {:ok, archer_id} = AvailableJobs.job_name_to_id(:archer)
    dancer_tree = SkillTree.tree_for(dancer_id)

    inherited_ids =
      for parent_id <- [novice_id, archer_id],
          {skill_id, parent_entry} <- SkillTree.tree_for(parent_id) do
        assert dancer_tree[skill_id] == parent_entry
        assert dancer_tree[skill_id].owner_job_id == parent_entry.owner_job_id
        skill_id
      end

    owned = dancer_owned_entries(dancer_id)

    assert normalized_entry_set(owned) == normalized_entry_set(@dancer_entries)
    assert length(owned) == 11
    assert map_size(dancer_tree) == 11 + length(Enum.uniq(inherited_ids))

    log = capture_log(&SkillTree.reload/0)

    for {name, max_level, _requires} <- @dancer_entries do
      lowercase_name = atomize(name)
      assert Atom.to_string(lowercase_name) == String.downcase(name)
      assert {:ok, definition} = Catalog.by_name(lowercase_name)
      assert definition.max_level == max_level
      refute log =~ ~s(references unimplemented skill "#{name}")
    end
  end

  test "every ordinary Dancer entry opens exactly on its own prerequisite set" do
    {:ok, dancer_id} = AvailableJobs.job_name_to_id(:dancer)
    progression = progression(dancer_id)

    for {name, _max_level, requires} <- @dancer_entries,
        name != "DC_WINKCHARM" do
      skill_id = catalog_id(atomize(name))
      satisfied = Map.new(requires, fn {req, level} -> {catalog_id(atomize(req)), level} end)

      assert SkillTree.can_learn(%{progression | learned_skills: satisfied}, skill_id) == :ok,
             "#{name} should be learnable with its full prerequisite set"

      for dropped <- Map.keys(satisfied) do
        assert SkillTree.can_learn(
                 %{progression | learned_skills: Map.delete(satisfied, dropped)},
                 skill_id
               ) == {:error, :missing_prerequisite},
               "#{name} should stay gated without every prerequisite"
      end
    end
  end

  test "Dancer tree contains no ensemble entry" do
    {:ok, dancer_id} = AvailableJobs.job_name_to_id(:dancer)

    dancer_id
    |> SkillTree.tree_for()
    |> Map.keys()
    |> Enum.map(&catalog_name/1)
    |> MapSet.new()
    |> then(&MapSet.disjoint?(&1, @ensemble_entries))
    |> assert()
  end

  defp normalized_entry_set(entries) do
    entries
    |> Enum.map(fn {name, max_level, requires} ->
      {name, max_level, MapSet.new(requires)}
    end)
    |> MapSet.new()
  end

  defp normalized_entries do
    path = Path.join(Application.app_dir(:zone_server, "priv/db/skill_tree"), "dancer.yml")

    [%{"job" => "dancer", "inherit" => ["novice", "archer"], "tree" => tree}] =
      DataLoader.parse_file(path)

    Enum.map(tree, fn entry ->
      requires = Enum.map(Map.get(entry, "requires", []), &{&1["name"], &1["level"]})
      {entry["name"], entry["max_level"], requires}
    end)
  end

  defp dancer_owned_entries(dancer_id) do
    dancer_id
    |> SkillTree.tree_for()
    |> Map.values()
    |> Enum.filter(&(&1.owner_job_id == dancer_id))
    |> Enum.map(fn entry ->
      requires =
        Enum.map(entry.requires, fn {skill_id, level} -> {catalog_name(skill_id), level} end)

      {catalog_name(entry.skill_id), entry.max_level, requires}
    end)
  end

  defp progression(job_id) do
    %PlayerProgression{
      base_level: 99,
      job_level: 50,
      base_exp: 0,
      job_exp: 0,
      job_id: job_id,
      skill_point: 99,
      status_point: 0,
      learned_skills: %{}
    }
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
