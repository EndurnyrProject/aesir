defmodule Aesir.ZoneServer.Mmo.SkillTreeAssassinTest do
  use ExUnit.Case, async: false

  alias Aesir.ZoneServer.Mmo.DataLoader
  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.SkillTree
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression

  @assassin_entries MapSet.new([
                      {"AS_RIGHT", 5, []},
                      {"AS_LEFT", 5, [{"AS_RIGHT", 2}]},
                      {"AS_KATAR", 10, []},
                      {"AS_CLOAKING", 10, [{"TF_HIDING", 2}]},
                      {"AS_SONICBLOW", 10, [{"AS_KATAR", 4}]},
                      {"AS_GRIMTOOTH", 5, [{"AS_CLOAKING", 2}, {"AS_SONICBLOW", 5}]},
                      {"AS_ENCHANTPOISON", 10, [{"TF_POISON", 1}]},
                      {"AS_POISONREACT", 10, [{"AS_ENCHANTPOISON", 3}]},
                      {"AS_VENOMDUST", 10, [{"AS_ENCHANTPOISON", 5}]},
                      {"AS_SPLASHER", 10, [{"AS_POISONREACT", 5}, {"AS_VENOMDUST", 5}]}
                    ])

  test "Assassin YAML declares exactly the approved ordinary entries" do
    assert normalized_entry_set(normalized_entries()) == normalized_entry_set(@assassin_entries)
  end

  test "resolved tree contains each Novice and Thief entry once plus IDs 132 through 141" do
    assassin_id = job_id(:assassin)
    assassin_tree = SkillTree.tree_for(assassin_id)

    inherited_ids =
      [:novice, :thief]
      |> Enum.flat_map(fn job ->
        for {skill_id, parent_entry} <- SkillTree.tree_for(job_id(job)) do
          assert assassin_tree[skill_id] == parent_entry
          skill_id
        end
      end)

    owned_ids =
      assassin_tree
      |> Map.values()
      |> Enum.filter(&(&1.owner_job_id == assassin_id))
      |> MapSet.new(& &1.skill_id)

    assert owned_ids == MapSet.new(132..141)
    assert map_size(assassin_tree) == 10 + length(Enum.uniq(inherited_ids))
  end

  test "every Assassin skill opens exactly at its complete prerequisite boundary" do
    progression = progression()

    for {name, _max_level, requires} <- @assassin_entries do
      skill_id = catalog_id(atomize(name))

      satisfied =
        Map.new(requires, fn {required, level} -> {catalog_id(atomize(required)), level} end)

      assert :ok = SkillTree.can_learn(%{progression | learned_skills: satisfied}, skill_id)

      for required_id <- Map.keys(satisfied) do
        assert {:error, :missing_prerequisite} =
                 SkillTree.can_learn(
                   %{progression | learned_skills: Map.delete(satisfied, required_id)},
                   skill_id
                 )
      end
    end
  end

  test "ordinary availability contains all ten Assassin skills but neither quest skill" do
    available_ids = progression() |> SkillTree.available_for() |> MapSet.new(& &1.skill_id)

    assert MapSet.subset?(MapSet.new(132..141), available_ids)
    refute MapSet.member?(available_ids, 1003)
    refute MapSet.member?(available_ids, 1004)
  end

  test "learning spends one point at the prerequisite and max-level boundaries" do
    right = catalog_id(:as_right)
    left = catalog_id(:as_left)

    assert {:error, :missing_prerequisite} =
             SkillTree.learn(progression(learned_skills: %{right => 1}), left)

    assert {:ok, learned_left} =
             SkillTree.learn(progression(learned_skills: %{right => 2}), left)

    assert learned_left.learned_skills[left] == 1
    assert learned_left.skill_point == 98

    capped = progression(learned_skills: %{right => 5})
    assert {:error, :max_level} = SkillTree.learn(capped, right)
  end

  defp normalized_entry_set(entries) do
    entries
    |> Enum.map(fn {name, max_level, requires} -> {name, max_level, MapSet.new(requires)} end)
    |> MapSet.new()
  end

  defp normalized_entries do
    path = Path.join(Application.app_dir(:zone_server, "priv/db/re/skill_tree"), "assassin.yml")

    [%{"job" => "assassin", "inherit" => ["novice", "thief"], "tree" => tree}] =
      DataLoader.parse_file(path)

    Enum.map(tree, fn entry ->
      requires = Enum.map(Map.get(entry, "requires", []), &{&1["name"], &1["level"]})
      {entry["name"], entry["max_level"], requires}
    end)
  end

  defp progression(attrs \\ []) do
    Map.merge(
      %PlayerProgression{
        base_level: 99,
        job_level: 50,
        base_exp: 0,
        job_exp: 0,
        job_id: job_id(:assassin),
        skill_point: 99,
        status_point: 0,
        learned_skills: %{}
      },
      Map.new(attrs)
    )
  end

  defp catalog_id(name) do
    {:ok, definition} = Catalog.by_name(name)
    definition.id
  end

  defp job_id(name) do
    {:ok, id} = AvailableJobs.job_name_to_id(name)
    id
  end

  defp atomize(name), do: name |> String.downcase() |> String.to_atom()
end
