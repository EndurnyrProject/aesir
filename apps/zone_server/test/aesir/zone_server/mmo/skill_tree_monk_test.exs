defmodule Aesir.ZoneServer.Mmo.SkillTreeMonkTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias Aesir.ZoneServer.Mmo.DataLoader
  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.SkillTree
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression

  @canonical_entries MapSet.new([
                       {"MO_IRONHAND", 10, [{"AL_DEMONBANE", 10}, {"AL_DP", 10}]},
                       {"MO_SPIRITSRECOVERY", 5, [{"MO_BLADESTOP", 2}]},
                       {"MO_CALLSPIRITS", 5, [{"MO_IRONHAND", 2}]},
                       {"MO_ABSORBSPIRITS", 1, [{"MO_CALLSPIRITS", 5}]},
                       {"MO_TRIPLEATTACK", 10, [{"MO_DODGE", 5}]},
                       {"MO_BODYRELOCATION", 1,
                        [
                          {"MO_EXTREMITYFIST", 3},
                          {"MO_SPIRITSRECOVERY", 2},
                          {"MO_STEELBODY", 3}
                        ]},
                       {"MO_DODGE", 10, [{"MO_IRONHAND", 5}, {"MO_CALLSPIRITS", 5}]},
                       {"MO_INVESTIGATE", 5, [{"MO_CALLSPIRITS", 5}]},
                       {"MO_FINGEROFFENSIVE", 5, [{"MO_INVESTIGATE", 3}]},
                       {"MO_STEELBODY", 5, [{"MO_COMBOFINISH", 3}]},
                       {"MO_BLADESTOP", 5, [{"MO_DODGE", 5}]},
                       {"MO_EXPLOSIONSPIRITS", 5, [{"MO_ABSORBSPIRITS", 1}]},
                       {"MO_EXTREMITYFIST", 5,
                        [{"MO_EXPLOSIONSPIRITS", 3}, {"MO_FINGEROFFENSIVE", 3}]},
                       {"MO_CHAINCOMBO", 5, [{"MO_TRIPLEATTACK", 5}]},
                       {"MO_COMBOFINISH", 5, [{"MO_CHAINCOMBO", 3}]}
                     ])

  @learning_order [
    {:mo_ironhand, 10},
    {:mo_callspirits, 5},
    {:mo_dodge, 10},
    {:mo_tripleattack, 10},
    {:mo_bladestop, 5},
    {:mo_spiritsrecovery, 5},
    {:mo_absorbspirits, 1},
    {:mo_explosionspirits, 5},
    {:mo_investigate, 5},
    {:mo_fingeroffensive, 5},
    {:mo_extremityfist, 5},
    {:mo_chaincombo, 5},
    {:mo_combofinish, 5},
    {:mo_steelbody, 5},
    {:mo_bodyrelocation, 1}
  ]

  test "monk.yml contains exactly the normal Renewal Monk entries" do
    assert MapSet.new(normalized_entries()) == @canonical_entries
  end

  test "every Monk entry and prerequisite resolves without a loader drop" do
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

    {:ok, monk_id} = AvailableJobs.job_name_to_id(:monk)
    assert length(monk_owned_entries(monk_id)) == MapSet.size(@canonical_entries)
  end

  test "runtime entries preserve every canonical maximum and prerequisite edge" do
    {:ok, monk_id} = AvailableJobs.job_name_to_id(:monk)

    resolved =
      monk_id
      |> monk_owned_entries()
      |> Enum.map(fn entry ->
        requires =
          Enum.map(entry.requires, fn {skill_id, level} -> {catalog_name(skill_id), level} end)

        {catalog_name(entry.skill_id), entry.max_level, requires}
      end)
      |> MapSet.new()

    assert resolved == @canonical_entries
  end

  test "Monk inherits every resolved Novice and Acolyte entry" do
    {:ok, monk_id} = AvailableJobs.job_name_to_id(:monk)
    {:ok, novice_id} = AvailableJobs.job_name_to_id(:novice)
    {:ok, acolyte_id} = AvailableJobs.job_name_to_id(:acolyte)
    monk_tree = SkillTree.tree_for(monk_id)

    for parent_id <- [novice_id, acolyte_id],
        {skill_id, parent_entry} <- SkillTree.tree_for(parent_id) do
      assert monk_tree[skill_id].owner_job_id == parent_entry.owner_job_id
    end

    for {name, _max_level} <- @learning_order do
      assert monk_tree[catalog_id(name)].owner_job_id == monk_id
    end
  end

  test "Ki Translation and Ki Explosion are catalogued but not ordinarily learnable" do
    {:ok, monk_id} = AvailableJobs.job_name_to_id(:monk)
    tree = SkillTree.tree_for(monk_id)

    kitranslation_id = catalog_id(:mo_kitranslation)
    balkyoung_id = catalog_id(:mo_balkyoung)

    refute Map.has_key?(tree, kitranslation_id)
    refute Map.has_key?(tree, balkyoung_id)

    progression = monk_progression(monk_id, skill_point: 1)

    assert {:error, :not_in_tree} = SkillTree.can_learn(progression, kitranslation_id)
    assert {:error, :not_in_tree} = SkillTree.can_learn(progression, balkyoung_id)

    names = MapSet.new(tree, fn {skill_id, _entry} -> catalog_name(skill_id) end)
    assert MapSet.disjoint?(names, MapSet.new(~w(MO_KITRANSLATION MO_BALKYOUNG)))
  end

  test "a Monk can learn exactly the 15 normal skills after canonical prerequisites and cannot exceed any max level" do
    {:ok, monk_id} = AvailableJobs.job_name_to_id(:monk)
    total_points = @learning_order |> Enum.map(&elem(&1, 1)) |> Enum.sum()

    progression =
      monk_progression(monk_id,
        skill_point: total_points,
        learned_skills: %{catalog_id(:al_demonbane) => 10, catalog_id(:al_dp) => 10}
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
    assert map_size(final.learned_skills) == length(@learning_order) + 2

    for {name, max_level} <- @learning_order do
      assert final.learned_skills[catalog_id(name)] == max_level

      over_cap = %{final | skill_point: final.skill_point + 1}
      assert {:error, :max_level} = SkillTree.learn(over_cap, catalog_id(name))
    end
  end

  defp normalized_entries do
    path = Path.join(Application.app_dir(:zone_server, "priv/db/re/skill_tree"), "monk.yml")

    [%{"job" => "monk", "inherit" => ["novice", "acolyte"], "tree" => tree}] =
      DataLoader.parse_file(path)

    Enum.map(tree, fn entry ->
      requires = Enum.map(Map.get(entry, "requires", []), &{&1["name"], &1["level"]})
      {entry["name"], entry["max_level"], requires}
    end)
  end

  defp monk_owned_entries(monk_id) do
    monk_id
    |> SkillTree.tree_for()
    |> Map.values()
    |> Enum.filter(&(&1.owner_job_id == monk_id))
  end

  defp monk_progression(monk_id, attrs) do
    Map.merge(
      %PlayerProgression{
        base_level: 99,
        job_level: 50,
        base_exp: 0,
        job_exp: 0,
        job_id: monk_id,
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
