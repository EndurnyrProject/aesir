defmodule Aesir.ZoneServer.Mmo.SkillTreeKnightTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias Aesir.ZoneServer.Mmo.DataLoader
  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.SkillTree
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression

  @canonical_entries MapSet.new([
                       {"KN_SPEARMASTERY", 10, []},
                       {"KN_PIERCE", 10, [{"KN_SPEARMASTERY", 1}]},
                       {"KN_SPEARSTAB", 10, [{"KN_PIERCE", 5}]},
                       {"KN_SPEARBOOMERANG", 5, [{"KN_PIERCE", 3}]},
                       {"KN_RIDING", 1, [{"SM_ENDURE", 1}]},
                       {"KN_CAVALIERMASTERY", 5, [{"KN_RIDING", 1}]},
                       {"KN_BRANDISHSPEAR", 10, [{"KN_RIDING", 1}, {"KN_SPEARSTAB", 3}]},
                       {"KN_TWOHANDQUICKEN", 10, [{"SM_TWOHAND", 1}]},
                       {"KN_AUTOCOUNTER", 5, [{"SM_TWOHAND", 1}]},
                       {"KN_BOWLINGBASH", 10,
                        [
                          {"SM_BASH", 10},
                          {"SM_MAGNUM", 3},
                          {"SM_TWOHAND", 5},
                          {"KN_TWOHANDQUICKEN", 10},
                          {"KN_AUTOCOUNTER", 5}
                        ]}
                     ])

  @learning_order [
    {:kn_spearmastery, 10},
    {:kn_pierce, 10},
    {:kn_spearstab, 10},
    {:kn_spearboomerang, 5},
    {:kn_riding, 1},
    {:kn_cavaliermastery, 5},
    {:kn_brandishspear, 10},
    {:kn_twohandquicken, 10},
    {:kn_autocounter, 5},
    {:kn_bowlingbash, 10}
  ]

  test "knight.yml contains exactly the normal Renewal Knight entries" do
    assert MapSet.new(normalized_entries()) == @canonical_entries
  end

  test "every Knight entry and prerequisite resolves without a loader drop" do
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

    {:ok, knight_id} = AvailableJobs.job_name_to_id(:knight)
    assert length(knight_owned_entries(knight_id)) == MapSet.size(@canonical_entries)
  end

  test "runtime entries preserve every canonical maximum and prerequisite edge" do
    {:ok, knight_id} = AvailableJobs.job_name_to_id(:knight)

    resolved =
      knight_id
      |> knight_owned_entries()
      |> Enum.map(fn entry ->
        requires =
          Enum.map(entry.requires, fn {skill_id, level} -> {catalog_name(skill_id), level} end)

        {catalog_name(entry.skill_id), entry.max_level, requires}
      end)
      |> MapSet.new()

    assert resolved == @canonical_entries
  end

  test "Knight inherits every resolved Swordman entry" do
    {:ok, knight_id} = AvailableJobs.job_name_to_id(:knight)
    {:ok, swordman_id} = AvailableJobs.job_name_to_id(:swordman)
    knight_tree = SkillTree.tree_for(knight_id)

    for {skill_id, parent_entry} <- SkillTree.tree_for(swordman_id) do
      assert knight_tree[skill_id].owner_job_id == parent_entry.owner_job_id
    end

    for {name, _max_level} <- @learning_order do
      assert knight_tree[catalog_id(name)].owner_job_id == knight_id
    end
  end

  test "Charge Attack is catalogued but not ordinarily learnable" do
    {:ok, knight_id} = AvailableJobs.job_name_to_id(:knight)
    tree = SkillTree.tree_for(knight_id)

    chargeatk_id = catalog_id(:kn_chargeatk)

    refute Map.has_key?(tree, chargeatk_id)

    progression = knight_progression(knight_id, skill_point: 1)

    assert {:error, :not_in_tree} = SkillTree.can_learn(progression, chargeatk_id)

    names = MapSet.new(tree, fn {skill_id, _entry} -> catalog_name(skill_id) end)
    refute MapSet.member?(names, "KN_CHARGEATK")
  end

  test "a Knight can learn exactly the 10 tree skills after canonical prerequisites and cannot exceed any max level" do
    {:ok, knight_id} = AvailableJobs.job_name_to_id(:knight)
    total_points = @learning_order |> Enum.map(&elem(&1, 1)) |> Enum.sum()

    progression =
      knight_progression(knight_id,
        skill_point: total_points,
        learned_skills: %{
          catalog_id(:sm_bash) => 10,
          catalog_id(:sm_magnum) => 3,
          catalog_id(:sm_twohand) => 5,
          catalog_id(:sm_endure) => 1
        }
      )

    final =
      Enum.reduce(@learning_order, progression, fn {name, max_level}, acc ->
        Enum.reduce(1..max_level, acc, fn expected_level, inner ->
          assert {:ok, updated} = SkillTree.learn(inner, catalog_id(name))
          assert updated.learned_skills[catalog_id(name)] == expected_level
          updated
        end)
      end)

    assert final.skill_point == 0
    assert map_size(final.learned_skills) == length(@learning_order) + 4

    for {name, max_level} <- @learning_order do
      assert final.learned_skills[catalog_id(name)] == max_level

      over_cap = %{final | skill_point: final.skill_point + 1}
      assert {:error, :max_level} = SkillTree.learn(over_cap, catalog_id(name))
    end
  end

  test "cannot learn KN_PIERCE without KN_SPEARMASTERY" do
    {:ok, knight_id} = AvailableJobs.job_name_to_id(:knight)
    progression = knight_progression(knight_id, skill_point: 1)

    assert {:error, :missing_prerequisite} =
             SkillTree.can_learn(progression, catalog_id(:kn_pierce))
  end

  test "cannot learn KN_BOWLINGBASH missing any single one of its five prerequisites" do
    {:ok, knight_id} = AvailableJobs.job_name_to_id(:knight)
    bowlingbash_id = catalog_id(:kn_bowlingbash)

    full_prereqs = %{
      catalog_id(:sm_bash) => 10,
      catalog_id(:sm_magnum) => 3,
      catalog_id(:sm_twohand) => 5,
      catalog_id(:kn_twohandquicken) => 10,
      catalog_id(:kn_autocounter) => 5
    }

    for {dropped_id, _level} <- full_prereqs do
      partial = Map.delete(full_prereqs, dropped_id)
      progression = knight_progression(knight_id, skill_point: 1, learned_skills: partial)

      assert {:error, :missing_prerequisite} = SkillTree.can_learn(progression, bowlingbash_id)
    end

    progression = knight_progression(knight_id, skill_point: 1, learned_skills: full_prereqs)
    assert :ok = SkillTree.can_learn(progression, bowlingbash_id)
  end

  test "SM_BASH remains learnable as a Knight (inheritance intact)" do
    {:ok, knight_id} = AvailableJobs.job_name_to_id(:knight)
    progression = knight_progression(knight_id, skill_point: 1)

    assert :ok = SkillTree.can_learn(progression, catalog_id(:sm_bash))
  end

  defp normalized_entries do
    path = Path.join(Application.app_dir(:zone_server, "priv/db/skill_tree"), "knight.yml")

    [%{"job" => "knight", "inherit" => ["swordman"], "tree" => tree}] =
      DataLoader.parse_file(path)

    Enum.map(tree, fn entry ->
      requires = Enum.map(Map.get(entry, "requires", []), &{&1["name"], &1["level"]})
      {entry["name"], entry["max_level"], requires}
    end)
  end

  defp knight_owned_entries(knight_id) do
    knight_id
    |> SkillTree.tree_for()
    |> Map.values()
    |> Enum.filter(&(&1.owner_job_id == knight_id))
  end

  defp knight_progression(knight_id, attrs) do
    Map.merge(
      %PlayerProgression{
        base_level: 99,
        job_level: 50,
        base_exp: 0,
        job_exp: 0,
        job_id: knight_id,
        skill_point: 0,
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
