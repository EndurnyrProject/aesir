defmodule Aesir.ZoneServer.Mmo.SkillTreeCrusaderTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias Aesir.ZoneServer.Mmo.DataLoader
  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.SkillTree
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression

  @canonical_entries MapSet.new([
                       {"KN_RIDING", 1, [{"SM_ENDURE", 1}]},
                       {"KN_CAVALIERMASTERY", 5, [{"KN_RIDING", 1}]},
                       {"KN_SPEARMASTERY", 10, []},
                       {"AL_CURE", 1, [{"CR_TRUST", 5}]},
                       {"AL_DP", 10, [{"AL_CURE", 1}]},
                       {"AL_DEMONBANE", 10, [{"AL_DP", 3}]},
                       {"AL_HEAL", 10, [{"AL_DEMONBANE", 5}, {"CR_TRUST", 10}]},
                       {"CR_TRUST", 10, []},
                       {"CR_AUTOGUARD", 10, []},
                       {"CR_SHIELDCHARGE", 5, [{"CR_AUTOGUARD", 5}]},
                       {"CR_SHIELDBOOMERANG", 5, [{"CR_SHIELDCHARGE", 3}]},
                       {"CR_REFLECTSHIELD", 10, [{"CR_SHIELDBOOMERANG", 3}]},
                       {"CR_HOLYCROSS", 10, [{"CR_TRUST", 7}]},
                       {"CR_GRANDCROSS", 10, [{"CR_HOLYCROSS", 6}, {"CR_TRUST", 10}]},
                       {"CR_DEVOTION", 5, [{"CR_REFLECTSHIELD", 5}, {"CR_GRANDCROSS", 4}]},
                       {"CR_PROVIDENCE", 5, [{"AL_DP", 5}, {"AL_HEAL", 5}]},
                       {"CR_DEFENDER", 5, [{"CR_SHIELDBOOMERANG", 1}]},
                       {"CR_SPEARQUICKEN", 10, [{"KN_SPEARMASTERY", 10}]}
                     ])

  @learning_order [
    {:kn_spearmastery, 10},
    {:cr_trust, 10},
    {:kn_riding, 1},
    {:kn_cavaliermastery, 5},
    {:cr_autoguard, 10},
    {:cr_shieldcharge, 5},
    {:cr_shieldboomerang, 5},
    {:cr_reflectshield, 10},
    {:cr_defender, 5},
    {:cr_holycross, 10},
    {:cr_grandcross, 10},
    {:cr_devotion, 5},
    {:al_cure, 1},
    {:al_dp, 10},
    {:al_demonbane, 10},
    {:al_heal, 10},
    {:cr_providence, 5},
    {:cr_spearquicken, 10}
  ]

  test "crusader.yml contains exactly the normal Renewal Crusader entries" do
    assert MapSet.new(normalized_entries()) == @canonical_entries
  end

  test "every Crusader entry and prerequisite resolves without a loader drop" do
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

    {:ok, crusader_id} = AvailableJobs.job_name_to_id(:crusader)
    assert length(crusader_owned_entries(crusader_id)) == MapSet.size(@canonical_entries)
  end

  test "runtime entries preserve every canonical maximum and prerequisite edge" do
    {:ok, crusader_id} = AvailableJobs.job_name_to_id(:crusader)

    resolved =
      crusader_id
      |> crusader_owned_entries()
      |> Enum.map(fn entry ->
        requires =
          Enum.map(entry.requires, fn {skill_id, level} -> {catalog_name(skill_id), level} end)

        {catalog_name(entry.skill_id), entry.max_level, requires}
      end)
      |> MapSet.new()

    assert resolved == @canonical_entries
  end

  test "Crusader inherits every resolved Swordman entry" do
    {:ok, crusader_id} = AvailableJobs.job_name_to_id(:crusader)
    {:ok, swordman_id} = AvailableJobs.job_name_to_id(:swordman)
    crusader_tree = SkillTree.tree_for(crusader_id)

    for {skill_id, parent_entry} <- SkillTree.tree_for(swordman_id) do
      assert crusader_tree[skill_id].owner_job_id == parent_entry.owner_job_id
    end
  end

  test "the resolved Crusader tree is exactly Swordman's inheritance plus its own entries" do
    {:ok, crusader_id} = AvailableJobs.job_name_to_id(:crusader)
    {:ok, swordman_id} = AvailableJobs.job_name_to_id(:swordman)

    resolved_names =
      crusader_id |> SkillTree.tree_for() |> Map.keys() |> MapSet.new(&catalog_name/1)

    inherited_names =
      swordman_id |> SkillTree.tree_for() |> Map.keys() |> MapSet.new(&catalog_name/1)

    own_names = MapSet.new(@canonical_entries, fn {name, _max, _reqs} -> name end)

    assert resolved_names == MapSet.union(inherited_names, own_names)

    for name <- ~w(AL_BLESSING AL_INCAGI AL_DECAGI AL_ANGELUS AL_PNEUMA AL_RUWACH
                   AL_TELEPORT AL_WARP AL_HOLYWATER AL_HOLYLIGHT AL_CRUCIS) do
      refute MapSet.member?(resolved_names, name), "#{name} must not leak into the Crusader tree"
    end
  end

  test "Crusader owns every entry of its own tree" do
    {:ok, crusader_id} = AvailableJobs.job_name_to_id(:crusader)
    crusader_tree = SkillTree.tree_for(crusader_id)

    for {name, _max_level} <- @learning_order do
      assert crusader_tree[catalog_id(name)].owner_job_id == crusader_id
    end
  end

  test "a Crusader can learn riding, Peco Mastery and all 11 CR_ skills through the tree" do
    {:ok, crusader_id} = AvailableJobs.job_name_to_id(:crusader)
    total_points = @learning_order |> Enum.map(&elem(&1, 1)) |> Enum.sum()

    progression =
      crusader_progression(crusader_id,
        skill_point: total_points,
        learned_skills: %{catalog_id(:sm_endure) => 1}
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
    assert map_size(final.learned_skills) == length(@learning_order) + 1

    for {name, max_level} <- @learning_order do
      assert final.learned_skills[catalog_id(name)] == max_level

      over_cap = %{final | skill_point: final.skill_point + 1}
      assert {:error, :max_level} = SkillTree.learn(over_cap, catalog_id(name))
    end
  end

  test "cannot learn KN_CAVALIERMASTERY without KN_RIDING" do
    {:ok, crusader_id} = AvailableJobs.job_name_to_id(:crusader)
    progression = crusader_progression(crusader_id, skill_point: 1)

    assert {:error, :missing_prerequisite} =
             SkillTree.can_learn(progression, catalog_id(:kn_cavaliermastery))
  end

  test "cannot learn CR_GRANDCROSS missing either of its two prerequisites" do
    {:ok, crusader_id} = AvailableJobs.job_name_to_id(:crusader)
    grandcross_id = catalog_id(:cr_grandcross)

    full_prereqs = %{
      catalog_id(:cr_holycross) => 6,
      catalog_id(:cr_trust) => 10
    }

    for {dropped_id, _level} <- full_prereqs do
      partial = Map.delete(full_prereqs, dropped_id)
      progression = crusader_progression(crusader_id, skill_point: 1, learned_skills: partial)

      assert {:error, :missing_prerequisite} =
               SkillTree.can_learn(progression, grandcross_id)
    end

    progression = crusader_progression(crusader_id, skill_point: 1, learned_skills: full_prereqs)
    assert :ok = SkillTree.can_learn(progression, grandcross_id)
  end

  test "cannot learn CR_PROVIDENCE missing either of its two prerequisites" do
    {:ok, crusader_id} = AvailableJobs.job_name_to_id(:crusader)
    providence_id = catalog_id(:cr_providence)

    full_prereqs = %{
      catalog_id(:al_dp) => 5,
      catalog_id(:al_heal) => 5
    }

    for {dropped_id, _level} <- full_prereqs do
      partial = Map.delete(full_prereqs, dropped_id)
      progression = crusader_progression(crusader_id, skill_point: 1, learned_skills: partial)

      assert {:error, :missing_prerequisite} =
               SkillTree.can_learn(progression, providence_id)
    end

    progression = crusader_progression(crusader_id, skill_point: 1, learned_skills: full_prereqs)
    assert :ok = SkillTree.can_learn(progression, providence_id)
  end

  test "SM_BASH remains learnable as a Crusader (inheritance intact)" do
    {:ok, crusader_id} = AvailableJobs.job_name_to_id(:crusader)
    progression = crusader_progression(crusader_id, skill_point: 1)

    assert :ok = SkillTree.can_learn(progression, catalog_id(:sm_bash))
  end

  defp normalized_entries do
    path = Path.join(Application.app_dir(:zone_server, "priv/db/skill_tree"), "crusader.yml")

    [%{"job" => "crusader", "inherit" => ["swordman"], "tree" => tree}] =
      DataLoader.parse_file(path)

    Enum.map(tree, fn entry ->
      requires = Enum.map(Map.get(entry, "requires", []), &{&1["name"], &1["level"]})
      {entry["name"], entry["max_level"], requires}
    end)
  end

  defp crusader_owned_entries(crusader_id) do
    crusader_id
    |> SkillTree.tree_for()
    |> Map.values()
    |> Enum.filter(&(&1.owner_job_id == crusader_id))
  end

  defp crusader_progression(crusader_id, attrs) do
    Map.merge(
      %PlayerProgression{
        base_level: 99,
        job_level: 50,
        base_exp: 0,
        job_exp: 0,
        job_id: crusader_id,
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
