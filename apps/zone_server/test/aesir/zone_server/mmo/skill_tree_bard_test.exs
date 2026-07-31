defmodule Aesir.ZoneServer.Mmo.SkillTreeBardTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias Aesir.ZoneServer.Mmo.DataLoader
  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.SkillTree
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression

  @bard_entries MapSet.new([
                  {"BA_MUSICALLESSON", 10, []},
                  {"BA_MUSICALSTRIKE", 5, [{"BA_MUSICALLESSON", 3}]},
                  {"BD_ADAPTATION", 1, []},
                  {"BD_ENCORE", 1, [{"BD_ADAPTATION", 1}]},
                  {"BA_DISSONANCE", 5, [{"BA_MUSICALLESSON", 1}, {"BD_ADAPTATION", 1}]},
                  {"BA_FROSTJOKER", 5, [{"BD_ENCORE", 1}]},
                  {"BA_WHISTLE", 10, [{"BA_DISSONANCE", 3}]},
                  {"BA_ASSASSINCROSS", 10, [{"BA_DISSONANCE", 3}]},
                  {"BA_POEMBRAGI", 10, [{"BA_DISSONANCE", 3}]},
                  {"BA_APPLEIDUN", 10, [{"BA_DISSONANCE", 3}]},
                  {"BD_LULLABY", 1, [{"BA_WHISTLE", 10}]},
                  {"BD_RICHMANKIM", 5, [{"BD_SIEGFRIED", 3}]},
                  {"BD_ETERNALCHAOS", 1, [{"BD_ROKISWEIL", 1}]},
                  {"BD_DRUMBATTLEFIELD", 5, [{"BA_APPLEIDUN", 10}]},
                  {"BD_RINGNIBELUNGEN", 5, [{"BD_DRUMBATTLEFIELD", 3}]},
                  {"BD_ROKISWEIL", 1, [{"BA_ASSASSINCROSS", 10}]},
                  {"BD_INTOABYSS", 1, [{"BD_LULLABY", 1}]},
                  {"BD_SIEGFRIED", 5, [{"BA_POEMBRAGI", 10}]}
                ])

  @inherited_names MapSet.new(~w(
                     NV_BASIC NV_FIRSTAID NV_TRICKDEAD
                     AC_OWL AC_VULTURE AC_CONCENTRATION AC_DOUBLE AC_SHOWER
                     AC_MAKINGARROW AC_CHARGEARROW
                   ))

  @novice_order [{:nv_basic, 9}]

  @archer_order [
    {:ac_owl, 10},
    {:ac_vulture, 10},
    {:ac_concentration, 10},
    {:ac_double, 10},
    {:ac_shower, 10}
  ]

  @bard_order [
    {:ba_musicallesson, 10},
    {:ba_musicalstrike, 5},
    {:bd_adaptation, 1},
    {:bd_encore, 1},
    {:ba_dissonance, 5},
    {:ba_frostjoker, 5},
    {:ba_whistle, 10},
    {:ba_assassincross, 10},
    {:ba_poembragi, 10},
    {:ba_appleidun, 10},
    {:bd_lullaby, 1},
    {:bd_intoabyss, 1},
    {:bd_drumbattlefield, 5},
    {:bd_ringnibelungen, 5},
    {:bd_rokisweil, 1},
    {:bd_eternalchaos, 1},
    {:bd_siegfried, 5},
    {:bd_richmankim, 5}
  ]

  @ensemble_names ~w(BD_LULLABY BD_RICHMANKIM BD_ETERNALCHAOS BD_DRUMBATTLEFIELD
                     BD_RINGNIBELUNGEN BD_ROKISWEIL BD_INTOABYSS BD_SIEGFRIED)

  test "Bard YAML pins every ordinary skill and no quest skill" do
    assert MapSet.size(@bard_entries) == 18
    assert normalized_entry_set(normalized_entries()) == normalized_entry_set(@bard_entries)
  end

  test "Bard entries resolve through the catalog with lowercase names and pinned levels" do
    {:ok, bard_id} = AvailableJobs.job_name_to_id(:bard)
    {:ok, novice_id} = AvailableJobs.job_name_to_id(:novice)
    {:ok, archer_id} = AvailableJobs.job_name_to_id(:archer)
    bard_tree = SkillTree.tree_for(bard_id)

    inherited_ids =
      for parent_id <- [novice_id, archer_id],
          {skill_id, parent_entry} <- SkillTree.tree_for(parent_id) do
        assert bard_tree[skill_id] == parent_entry
        assert bard_tree[skill_id].owner_job_id == parent_entry.owner_job_id
        skill_id
      end

    owned = bard_owned_entries(bard_id)

    assert normalized_entry_set(owned) == normalized_entry_set(@bard_entries)
    assert length(owned) == 18
    assert map_size(bard_tree) == 18 + length(Enum.uniq(inherited_ids))

    log = capture_log(&SkillTree.reload/0)

    for {name, max_level, _requires} <- @bard_entries do
      lowercase_name = atomize(name)
      assert Atom.to_string(lowercase_name) == String.downcase(name)
      assert {:ok, definition} = Catalog.by_name(lowercase_name)
      assert definition.max_level == max_level
      refute log =~ ~s(references unimplemented skill "#{name}")
    end
  end

  test "every Bard entry opens exactly on its own prerequisite set" do
    {:ok, bard_id} = AvailableJobs.job_name_to_id(:bard)
    progression = progression(bard_id)

    for {name, _max_level, requires} <- @bard_entries do
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

  test "the resolved Bard tree is exactly Novice and Archer inheritance plus Bard entries" do
    {:ok, bard_id} = AvailableJobs.job_name_to_id(:bard)

    resolved_names =
      bard_id |> SkillTree.tree_for() |> Map.keys() |> MapSet.new(&catalog_name/1)

    owned_names = MapSet.new(@bard_entries, fn {name, _max_level, _requires} -> name end)

    assert resolved_names == MapSet.union(@inherited_names, owned_names)
  end

  test "a Bard can learn every ensemble in full Novice to Archer to Bard order" do
    {:ok, novice_id} = AvailableJobs.job_name_to_id(:novice)
    {:ok, archer_id} = AvailableJobs.job_name_to_id(:archer)
    {:ok, bard_id} = AvailableJobs.job_name_to_id(:bard)
    order = @novice_order ++ @archer_order ++ @bard_order
    total_points = order |> Enum.map(&elem(&1, 1)) |> Enum.sum()

    final =
      progression(novice_id)
      |> Map.put(:skill_point, total_points)
      |> learn_all(@novice_order)
      |> Map.put(:job_id, archer_id)
      |> learn_all(@archer_order)
      |> Map.put(:job_id, bard_id)
      |> learn_all(@bard_order)

    assert final.skill_point == 0

    for name <- @ensemble_names do
      skill_id = name |> atomize() |> catalog_id()
      {:ok, definition} = Catalog.by_id(skill_id)
      assert final.learned_skills[skill_id] == definition.max_level
    end
  end

  test "Bard-owned skills stay inside the Bard job boundary" do
    {:ok, bard_id} = AvailableJobs.job_name_to_id(:bard)
    {:ok, archer_id} = AvailableJobs.job_name_to_id(:archer)
    {:ok, dancer_id} = AvailableJobs.job_name_to_id(:dancer)
    musical_lesson = catalog_id(:ba_musicallesson)

    assert :ok = SkillTree.can_learn(progression(bard_id), musical_lesson)
    assert {:error, :not_in_tree} = SkillTree.can_learn(progression(archer_id), musical_lesson)
    assert {:error, :not_in_tree} = SkillTree.can_learn(progression(dancer_id), musical_lesson)
  end

  test "Pang Voice remains a Bard-owned quest skill outside ordinary learning" do
    {:ok, bard_id} = AvailableJobs.job_name_to_id(:bard)
    {:ok, archer_id} = AvailableJobs.job_name_to_id(:archer)
    pang_voice = catalog_id(:ba_pangvoice)
    bard_tree = SkillTree.tree_for(bard_id)

    assert {:ok, definition} = Catalog.by_id(1010)
    assert definition.name == :ba_pangvoice
    assert definition.quest_skill
    assert definition.quest_owner_job == :bard
    assert SkillTree.quest_skill_available?(bard_id, definition)
    refute SkillTree.quest_skill_available?(archer_id, definition)
    refute Map.has_key?(bard_tree, pang_voice)
    assert {:error, :not_in_tree} = SkillTree.can_learn(progression(bard_id), pang_voice)
  end

  defp learn_all(progression, order) do
    Enum.reduce(order, progression, fn {name, max_level}, acc ->
      Enum.reduce(1..max_level, acc, fn expected_level, inner ->
        assert {:ok, updated} = SkillTree.learn(inner, catalog_id(name))
        assert updated.learned_skills[catalog_id(name)] == expected_level
        updated
      end)
    end)
  end

  defp normalized_entry_set(entries) do
    entries
    |> Enum.map(fn {name, max_level, requires} ->
      {name, max_level, MapSet.new(requires)}
    end)
    |> MapSet.new()
  end

  defp normalized_entries do
    path = Path.join(Application.app_dir(:zone_server, "priv/db/skill_tree"), "bard.yml")

    [%{"job" => "bard", "inherit" => ["novice", "archer"], "tree" => tree}] =
      DataLoader.parse_file(path)

    Enum.map(tree, fn entry ->
      requires = Enum.map(Map.get(entry, "requires", []), &{&1["name"], &1["level"]})
      {entry["name"], entry["max_level"], requires}
    end)
  end

  defp bard_owned_entries(bard_id) do
    bard_id
    |> SkillTree.tree_for()
    |> Map.values()
    |> Enum.filter(&(&1.owner_job_id == bard_id))
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
