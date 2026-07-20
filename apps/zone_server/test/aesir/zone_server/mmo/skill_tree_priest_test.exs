defmodule Aesir.ZoneServer.Mmo.SkillTreePriestTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias Aesir.ZoneServer.Mmo.DataLoader
  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.SkillTree
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression

  @canonical_entries MapSet.new([
                       {"MG_SRECOVERY", 10, []},
                       {"MG_SAFETYWALL", 10, [{"PR_ASPERSIO", 4}, {"PR_SANCTUARY", 3}]},
                       {"ALL_RESURRECTION", 4, [{"PR_STRECOVERY", 1}, {"MG_SRECOVERY", 4}]},
                       {"PR_MACEMASTERY", 10, []},
                       {"PR_IMPOSITIO", 5, []},
                       {"PR_SUFFRAGIUM", 3, [{"PR_IMPOSITIO", 2}]},
                       {"PR_ASPERSIO", 5, [{"AL_HOLYWATER", 1}, {"PR_IMPOSITIO", 3}]},
                       {"PR_BENEDICTIO", 5, [{"PR_GLORIA", 3}, {"PR_ASPERSIO", 5}]},
                       {"PR_SANCTUARY", 10, [{"AL_HEAL", 1}]},
                       {"PR_SLOWPOISON", 4, []},
                       {"PR_STRECOVERY", 1, []},
                       {"PR_KYRIE", 10, [{"AL_ANGELUS", 2}]},
                       {"PR_MAGNIFICAT", 5, []},
                       {"PR_GLORIA", 5, [{"PR_KYRIE", 4}, {"PR_MAGNIFICAT", 3}]},
                       {"PR_LEXDIVINA", 10, [{"AL_RUWACH", 1}]},
                       {"PR_TURNUNDEAD", 10, [{"ALL_RESURRECTION", 1}, {"PR_LEXDIVINA", 3}]},
                       {"PR_LEXAETERNA", 1, [{"PR_LEXDIVINA", 5}]},
                       {"PR_MAGNUS", 10,
                        [
                          {"MG_SAFETYWALL", 1},
                          {"PR_LEXAETERNA", 1},
                          {"PR_TURNUNDEAD", 3}
                        ]}
                     ])

  test "priest.yml contains exactly the normal Renewal Priest entries" do
    assert MapSet.new(normalized_entries()) == @canonical_entries
  end

  test "every Priest entry and prerequisite resolves without a loader drop" do
    names =
      @canonical_entries
      |> Enum.flat_map(fn {name, _max_level, requires} ->
        [name | Enum.map(requires, &elem(&1, 0))]
      end)
      |> Enum.uniq()

    for name <- names do
      assert {:ok, _definition} = Catalog.by_name(atomize(name)), "#{name} is not catalogued"
    end

    log = capture_log(&SkillTree.reload/0)

    for {name, _max_level, _requires} <- @canonical_entries do
      refute log =~ ~s(references unimplemented skill "#{name}")
    end

    {:ok, priest_id} = AvailableJobs.job_name_to_id(:priest)
    assert length(priest_owned_entries(priest_id)) == MapSet.size(@canonical_entries)
  end

  test "runtime entries preserve every canonical maximum and prerequisite edge" do
    {:ok, priest_id} = AvailableJobs.job_name_to_id(:priest)

    resolved =
      priest_id
      |> priest_owned_entries()
      |> Enum.map(fn entry ->
        requires =
          Enum.map(entry.requires, fn {skill_id, level} -> {catalog_name(skill_id), level} end)

        {catalog_name(entry.skill_id), entry.max_level, requires}
      end)
      |> MapSet.new()

    assert resolved == @canonical_entries
  end

  test "Priest inherits every resolved Novice and Acolyte entry" do
    {:ok, priest_id} = AvailableJobs.job_name_to_id(:priest)
    {:ok, novice_id} = AvailableJobs.job_name_to_id(:novice)
    {:ok, acolyte_id} = AvailableJobs.job_name_to_id(:acolyte)
    priest_tree = SkillTree.tree_for(priest_id)

    for parent_id <- [novice_id, acolyte_id],
        {skill_id, parent_entry} <- SkillTree.tree_for(parent_id) do
      assert priest_tree[skill_id].owner_job_id == parent_entry.owner_job_id
    end

    for name <- [:mg_srecovery, :mg_safetywall, :all_resurrection] do
      assert priest_tree[catalog_id(name)].owner_job_id == priest_id
    end
  end

  test "Redemptio is catalogued but not ordinarily learnable and High Priest is excluded" do
    {:ok, priest_id} = AvailableJobs.job_name_to_id(:priest)
    redemptio_id = catalog_id(:pr_redemptio)
    tree = SkillTree.tree_for(priest_id)

    refute Map.has_key?(tree, redemptio_id)

    progression = %PlayerProgression{
      base_level: 99,
      job_level: 50,
      base_exp: 0,
      job_exp: 0,
      job_id: priest_id,
      skill_point: 1,
      status_point: 0,
      learned_skills: %{}
    }

    assert {:error, :not_in_tree} = SkillTree.can_learn(progression, redemptio_id)

    names = MapSet.new(tree, fn {skill_id, _entry} -> catalog_name(skill_id) end)
    assert MapSet.disjoint?(names, MapSet.new(~w(HP_ASSUMPTIO HP_BASILICA HP_MEDITATIO)))
  end

  defp normalized_entries do
    path = Path.join(Application.app_dir(:zone_server, "priv/db/skill_tree"), "priest.yml")

    [%{"job" => "priest", "inherit" => ["novice", "acolyte"], "tree" => tree}] =
      DataLoader.parse_file(path)

    Enum.map(tree, fn entry ->
      requires = Enum.map(Map.get(entry, "requires", []), &{&1["name"], &1["level"]})
      {entry["name"], entry["max_level"], requires}
    end)
  end

  defp priest_owned_entries(priest_id) do
    priest_id
    |> SkillTree.tree_for()
    |> Map.values()
    |> Enum.filter(&(&1.owner_job_id == priest_id))
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
