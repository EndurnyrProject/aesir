defmodule Aesir.ZoneServer.Mmo.Homunculus.CatalogTest do
  use ExUnit.Case, async: false

  alias Aesir.ZoneServer.Mmo.Homunculus.Catalog
  alias Aesir.ZoneServer.Mmo.Homunculus.Catalogs
  alias Aesir.ZoneServer.Mmo.Homunculus.ExpTable
  alias Aesir.ZoneServer.Mmo.Homunculus.SkillTree

  @expected_variants ~w(Lif Amistr Filir Vanilmirth Lif2 Amistr2 Filir2 Vanilmirth2 Lif_H Amistr_H Filir_H Vanilmirth_H Lif_H2 Amistr_H2 Filir_H2 Vanilmirth_H2)
  @expected_foods [
    "Pet_Food",
    "Zargon",
    "Garlet",
    "Scell",
    "Pet_Food",
    "Zargon",
    "Garlet",
    "Scell"
  ]

  @ranges %{
    lif: %{
      "hp" => {150, 60, 100, 800, 2400},
      "sp" => {40, 4, 9, 220, 480},
      "str" => {17, 5, 19, 10, 30},
      "agi" => {20, 5, 19, 10, 30},
      "vit" => {15, 5, 19, 20, 40},
      "int" => {35, 4, 20, 30, 50},
      "dex" => {24, 6, 20, 20, 50},
      "luk" => {12, 6, 20, 10, 30}
    },
    amistr: %{
      "hp" => {320, 80, 130, 1600, 3600},
      "sp" => {10, 1, 4, 120, 360},
      "str" => {20, 8, 20, 20, 50},
      "agi" => {17, 4, 20, 10, 30},
      "vit" => {35, 4, 20, 20, 50},
      "int" => {11, 1, 10, 20, 50},
      "dex" => {24, 3, 19, 10, 30},
      "luk" => {12, 3, 19, 10, 30}
    },
    filir: %{
      "hp" => {90, 45, 75, 1200, 3200},
      "sp" => {25, 3, 6, 200, 400},
      "str" => {29, 4, 20, 20, 50},
      "agi" => {35, 8, 20, 10, 30},
      "vit" => {9, 1, 10, 20, 50},
      "int" => {8, 3, 19, 20, 50},
      "dex" => {30, 4, 20, 10, 30},
      "luk" => {9, 3, 19, 10, 30}
    },
    vanilmirth: %{
      "hp" => {80, 30, 150, 1200, 4800},
      "sp" => {11, 0, 7, 480, 640},
      "str" => {11, 1, 30, 10, 30},
      "agi" => {11, 1, 30, 10, 30},
      "vit" => {11, 1, 30, 10, 30},
      "int" => {11, 1, 30, 20, 50},
      "dex" => {11, 1, 30, 10, 50},
      "luk" => {11, 1, 30, 10, 100}
    }
  }

  setup do
    Catalogs.reload()
  end

  test "loads all 16 class variants and the exact eight initial variants" do
    rows = Catalog.all()

    assert Enum.map(rows, & &1.id) == Enum.to_list(6001..6016)
    assert Enum.map(rows, & &1.variant) == @expected_variants
    assert Catalog.initial_class_ids() == Enum.to_list(6001..6008)
    assert Enum.map(Enum.take(rows, 8), & &1.form) == List.duplicate(:original, 8)
    assert Enum.map(Enum.drop(rows, 8), & &1.form) == List.duplicate(:evolved, 8)
  end

  test "pins foods, form links, defaults, race, and size for every variant" do
    for id <- 6001..6008 do
      {:ok, original} = Catalog.by_id(id)
      {:ok, evolved} = Catalog.by_id(id + 8)
      offset = id - 6001

      assert original.food == Enum.at(@expected_foods, offset)
      assert evolved.food == original.food
      assert original.base_class_id == id
      assert original.evolution_class_id == id + 8
      assert evolved.base_class_id == id
      assert evolved.evolution_class_id == id + 8
      assert original.size == :small
      assert evolved.size == :medium
      assert original.element == :neutral
      assert original.hungry_delay == 60_000
      assert original.attack_delay == 700
    end

    assert Enum.map(Catalog.all() |> Enum.take(4), & &1.race) ==
             [:demi_human, :brute, :brute, :formless]
  end

  test "pins every inclusive growth and evolution range for all visual variants" do
    families = [:lif, :amistr, :filir, :vanilmirth, :lif, :amistr, :filir, :vanilmirth]

    for {family, offset} <- Enum.with_index(families), id <- [6001 + offset, 6009 + offset] do
      {:ok, row} = Catalog.by_id(id)

      assert Map.new(row.stats, fn {stat, range} ->
               {stat,
                {range.base, range.growth_min, range.growth_max, range.evolution_min,
                 range.evolution_max}}
             end) == @ranges[family]
    end
  end

  test "pins every Renewal level 1 through 99 EXP value" do
    table = ExpTable.all()

    canonical =
      Enum.map_join(1..99, "\n", fn level ->
        "#{level}:#{Map.fetch!(table, level)}"
      end)

    assert Base.encode16(:crypto.hash(:sha256, canonical), case: :lower) ==
             "2d0400d80a4f8ea87e2da8aeaed1f378d9fe3c07fe9bfb8616dd06e1413d412c"

    assert Map.keys(table) |> Enum.sort() == Enum.to_list(1..99)
    assert ExpTable.exp_for(100) == :error
  end

  test "pins every rank, prerequisite, form, and fixed-point intimacy rule" do
    expected = %{
      8001 => {5, [], :any, 0},
      8002 => {5, [%{skill_id: 8001, level: 3}], :any, 0},
      8003 => {5, [%{skill_id: 8001, level: 5}], :any, 0},
      8004 => {3, [], :evolved, 91_000},
      8005 => {5, [], :any, 0},
      8006 => {5, [%{skill_id: 8005, level: 5}], :any, 0},
      8007 => {5, [%{skill_id: 8006, level: 3}], :any, 0},
      8008 => {3, [], :evolved, 91_000},
      8009 => {5, [], :any, 0},
      8010 => {5, [%{skill_id: 8009, level: 3}], :any, 0},
      8011 => {5, [%{skill_id: 8010, level: 3}], :any, 0},
      8012 => {3, [], :evolved, 91_000},
      8013 => {5, [], :any, 0},
      8014 => {5, [%{skill_id: 8013, level: 3}], :any, 0},
      8015 => {5, [%{skill_id: 8013, level: 5}], :any, 0},
      8016 => {3, [], :evolved, 91_000}
    }

    assert length(SkillTree.all()) == 64

    for class_id <- 6001..6016 do
      rows = SkillTree.for_class(class_id)
      family_start = 8001 + rem(class_id - 6001, 4) * 4
      assert Enum.map(rows, & &1.skill_id) == Enum.to_list(family_start..(family_start + 3))

      for row <- rows do
        assert {row.max_level, row.requires, row.form, row.required_intimacy} ==
                 expected[row.skill_id]

        assert row.required_level == 0
      end
    end
  end

  test "orchestrated reload replaces data only after successful validation" do
    path = Application.app_dir(:zone_server, "priv/db/re/homunculus/species.yml")
    exp_path = Application.app_dir(:zone_server, "priv/db/re/homunculus/exp.yml")
    trees_path = Application.app_dir(:zone_server, "priv/db/re/homunculus/skill_trees.yml")
    rows = YamlElixir.read_from_file!(path)
    changed = put_in(hd(rows)["food"], "Fresh_Test_Food")

    temp =
      Path.join(System.tmp_dir!(), "homunculus-species-#{System.unique_integer([:positive])}.yml")

    File.write!(temp, Ymlr.document!([changed | tl(rows)]))

    on_exit(fn ->
      Catalogs.reload()
      File.rm(temp)
    end)

    assert :ok = Catalogs.reload(temp, exp_path, trees_path)
    assert {:ok, %{food: "Fresh_Test_Food"}} = Catalog.by_id(6001)

    File.write!(temp, Ymlr.document!(tl(rows)))

    assert_raise ArgumentError, ~r/expected 16/, fn ->
      Catalogs.reload(temp, exp_path, trees_path)
    end

    assert {:ok, %{food: "Fresh_Test_Food"}} = Catalog.by_id(6001)
  end

  test "malformed and incomplete corpora fail explicit validation" do
    species =
      YamlElixir.read_from_file!(
        Application.app_dir(:zone_server, "priv/db/re/homunculus/species.yml")
      )

    exp =
      YamlElixir.read_from_file!(
        Application.app_dir(:zone_server, "priv/db/re/homunculus/exp.yml")
      )

    trees =
      YamlElixir.read_from_file!(
        Application.app_dir(:zone_server, "priv/db/re/homunculus/skill_trees.yml")
      )

    assert_raise ArgumentError, ~r/expected 16/, fn -> Catalog.validate!(tl(species)) end

    assert_raise ArgumentError, ~r/growth range is reversed/, fn ->
      Catalog.validate!(put_in(species, [Access.at(0), "stats", "hp", "growth_min"], 101))
    end

    assert_raise ArgumentError, ~r/levels 1..99/, fn -> ExpTable.validate!(tl(exp)) end

    assert_raise ArgumentError, ~r/positive integers/, fn ->
      ExpTable.validate!(put_in(exp, [Access.at(0), "exp"], 0))
    end

    duplicate_species_skill =
      put_in(
        species,
        [Access.at(0), "skills", Access.at(3)],
        species |> hd() |> get_in(["skills", Access.at(0)])
      )

    assert_raise ArgumentError, ~r/duplicate species skills/, fn ->
      Catalog.validate!(duplicate_species_skill)
    end

    assert_raise ArgumentError, ~r/expected 64/, fn -> SkillTree.validate!(tl(trees)) end

    assert_raise ArgumentError, ~r/outside its class tree/, fn ->
      SkillTree.validate!(
        put_in(trees, [Access.at(1), "requires", Access.at(0), "skill_id"], 9999)
      )
    end

    assert_raise ArgumentError, ~r/invalid Homunculus skill name/, fn ->
      SkillTree.validate!(put_in(trees, [Access.at(0), "skill"], ""))
    end

    duplicate_requirement =
      update_in(trees, [Access.at(1), "requires"], fn [requirement] ->
        [requirement, requirement]
      end)

    assert_raise ArgumentError, ~r/duplicate prerequisites/, fn ->
      SkillTree.validate!(duplicate_requirement)
    end

    duplicate_skill = List.replace_at(trees, 3, Enum.at(trees, 2))

    assert_raise ArgumentError, ~r/duplicate skills/, fn ->
      SkillTree.validate!(duplicate_skill)
    end
  end

  @tag :tmp_dir
  test "successful orchestrated reload publishes one complete generation", %{tmp_dir: dir} do
    [species_path, exp_path, trees_path] = write_changed_triplet(dir)
    generation = Catalogs.generation()
    on_exit(fn -> Catalogs.reload() end)

    assert :ok = Catalogs.reload(species_path, exp_path, trees_path)
    assert Catalogs.generation() == generation + 1
    assert {:ok, %{food: "Atomic_Test_Food"}} = Catalog.by_id(6001)
    assert ExpTable.exp_for(1) == {:ok, 102}
    assert {:ok, %{skill: "HLIF_HEAL_TEST"}} = SkillTree.entry(6001, 8001)
  end

  @tag :tmp_dir
  test "every catalog reload reloads the complete canonical triplet", %{tmp_dir: dir} do
    paths = write_changed_triplet(dir)
    canonical = {Catalog.all(), ExpTable.all(), SkillTree.all()}

    for module <- [Catalog, ExpTable, SkillTree] do
      apply(Catalogs, :reload, paths)
      changed_generation = Catalogs.generation()
      assert :ok = module.reload()
      assert Catalogs.generation() == changed_generation + 1
      assert {Catalog.all(), ExpTable.all(), SkillTree.all()} == canonical
    end
  end

  test "catalogs expose no component install bypass" do
    refute function_exported?(Catalog, :install, 1)
    refute function_exported?(ExpTable, :install, 1)
    refute function_exported?(SkillTree, :install, 1)
  end

  @tag :tmp_dir
  test "failed orchestrated reload preserves all three installed catalogs", %{tmp_dir: dir} do
    species_path = Application.app_dir(:zone_server, "priv/db/re/homunculus/species.yml")
    exp_path = Application.app_dir(:zone_server, "priv/db/re/homunculus/exp.yml")
    trees_path = Application.app_dir(:zone_server, "priv/db/re/homunculus/skill_trees.yml")

    prior = {Catalogs.generation(), Catalog.all(), ExpTable.all(), SkillTree.all()}
    species = YamlElixir.read_from_file!(species_path)
    inconsistent = put_in(species, [Access.at(0), "skills", Access.at(0)], 9999)
    bad_species_path = Path.join(dir, "species.yml")
    File.write!(bad_species_path, Ymlr.document!(inconsistent))

    assert_raise ArgumentError, ~r/catalog skill mismatch for class 6001/, fn ->
      Catalogs.reload(bad_species_path, exp_path, trees_path)
    end

    assert {Catalogs.generation(), Catalog.all(), ExpTable.all(), SkillTree.all()} == prior
  end

  test "runtime cross-validation rejects unknown and missing species skills" do
    species =
      YamlElixir.read_from_file!(
        Application.app_dir(:zone_server, "priv/db/re/homunculus/species.yml")
      )

    trees =
      YamlElixir.read_from_file!(
        Application.app_dir(:zone_server, "priv/db/re/homunculus/skill_trees.yml")
      )

    inconsistent = put_in(species, [Access.at(0), "skills", Access.at(0)], 9999)

    assert_raise ArgumentError, ~r/catalog class mismatch/, fn ->
      Catalogs.validate!(tl(species), trees)
    end

    assert_raise ArgumentError, ~r/catalog skill mismatch for class 6001/, fn ->
      Catalogs.validate!(inconsistent, trees)
    end
  end

  defp write_changed_triplet(dir) do
    species =
      Application.app_dir(:zone_server, "priv/db/re/homunculus/species.yml")
      |> YamlElixir.read_from_file!()
      |> put_in([Access.at(0), "food"], "Atomic_Test_Food")

    exp =
      Application.app_dir(:zone_server, "priv/db/re/homunculus/exp.yml")
      |> YamlElixir.read_from_file!()
      |> put_in([Access.at(0), "exp"], 102)

    trees =
      Application.app_dir(:zone_server, "priv/db/re/homunculus/skill_trees.yml")
      |> YamlElixir.read_from_file!()
      |> put_in([Access.at(0), "skill"], "HLIF_HEAL_TEST")

    for {name, rows} <- [{"species.yml", species}, {"exp.yml", exp}, {"trees.yml", trees}] do
      path = Path.join(dir, name)
      File.write!(path, Ymlr.document!(rows))
      path
    end
  end
end
