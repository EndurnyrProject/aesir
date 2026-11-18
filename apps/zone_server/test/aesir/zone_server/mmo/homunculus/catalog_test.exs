defmodule Aesir.ZoneServer.Mmo.Homunculus.CatalogTest do
  use ExUnit.Case, async: false

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Db.Layout
  alias Aesir.ZoneServer.Mmo.Homunculus.Catalog
  alias Aesir.ZoneServer.Mmo.Homunculus.Catalogs
  alias Aesir.ZoneServer.Mmo.Homunculus.ExpTable
  alias Aesir.ZoneServer.Mmo.Homunculus.SkillTree

  setup do
    # These serialized tests exercise actual shared catalog publication and restore it on exit.
    on_exit(fn -> Catalogs.reload() end)
    Catalogs.reload()
  end

  test "orchestrated reload replaces data only after successful validation" do
    path = catalog_path("species.yml")
    exp_path = catalog_path("exp.yml")
    trees_path = catalog_path("skill_trees.yml")
    rows = YamlElixir.read_from_file!(path)
    changed = put_in(hd(rows)["food"], "Fresh_Test_Food")

    temp =
      Path.join(System.tmp_dir!(), "homunculus-species-#{System.unique_integer([:positive])}.yml")

    File.write!(temp, Ymlr.document!([changed | tl(rows)]))

    on_exit(fn -> File.rm(temp) end)

    assert :ok = Catalogs.reload(temp, exp_path, trees_path)
    assert {:ok, %{food: "Fresh_Test_Food"}} = Catalog.by_id(6001)

    File.write!(temp, Ymlr.document!(tl(rows)))

    assert_raise ArgumentError, ~r/expected 16/, fn ->
      Catalogs.reload(temp, exp_path, trees_path)
    end

    assert {:ok, %{food: "Fresh_Test_Food"}} = Catalog.by_id(6001)
  end

  test "malformed and incomplete corpora fail explicit validation" do
    species = YamlElixir.read_from_file!(catalog_path("species.yml"))
    exp = YamlElixir.read_from_file!(catalog_path("exp.yml", :renewal))
    trees = YamlElixir.read_from_file!(catalog_path("skill_trees.yml"))

    assert_raise ArgumentError, ~r/expected 16/, fn -> Catalog.validate!(tl(species)) end

    assert_raise ArgumentError, ~r/growth range is reversed/, fn ->
      Catalog.validate!(put_in(species, [Access.at(0), "stats", "hp", "growth_min"], 101))
    end

    assert_raise ArgumentError, ~r/levels 1..99/, fn ->
      ExpTable.validate!(tl(exp), :renewal)
    end

    assert :ok = ExpTable.validate!(Enum.take(exp, 98), :pre_renewal)

    assert_raise ArgumentError, ~r/levels 1..98/, fn ->
      ExpTable.validate!(exp, :pre_renewal)
    end

    assert_raise ArgumentError, ~r/positive integers/, fn ->
      ExpTable.validate!(put_in(exp, [Access.at(0), "exp"], 0), :renewal)
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

    assert :ok = Catalogs.reload(species_path, exp_path, trees_path)
    assert Catalogs.generation() == generation + 1
    assert {:ok, %{food: "Atomic_Test_Food"}} = Catalog.by_id(6001)
    assert ExpTable.exp_for(1) == {:ok, 102}
    assert {:ok, %{skill: "HLIF_HEAL_TEST"}} = SkillTree.entry(6001, 8001)
  end

  @tag :tmp_dir
  test "failed orchestrated reload preserves all three installed catalogs", %{tmp_dir: dir} do
    species_path = catalog_path("species.yml")
    exp_path = catalog_path("exp.yml")
    trees_path = catalog_path("skill_trees.yml")

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
    species = YamlElixir.read_from_file!(catalog_path("species.yml"))
    trees = YamlElixir.read_from_file!(catalog_path("skill_trees.yml"))

    inconsistent = put_in(species, [Access.at(0), "skills", Access.at(0)], 9999)

    assert_raise ArgumentError, ~r/catalog class mismatch/, fn ->
      Catalogs.validate!(tl(species), trees)
    end

    assert_raise ArgumentError, ~r/catalog skill mismatch for class 6001/, fn ->
      Catalogs.validate!(inconsistent, trees)
    end
  end

  defp catalog_path(name, mode \\ GameMode.mode()) do
    Application.app_dir(:zone_server, "priv/db/#{Layout.mode_dir(mode)}/homunculus/#{name}")
  end

  defp write_changed_triplet(dir) do
    species =
      catalog_path("species.yml")
      |> YamlElixir.read_from_file!()
      |> put_in([Access.at(0), "food"], "Atomic_Test_Food")

    exp =
      catalog_path("exp.yml")
      |> YamlElixir.read_from_file!()
      |> put_in([Access.at(0), "exp"], 102)

    trees =
      catalog_path("skill_trees.yml")
      |> YamlElixir.read_from_file!()
      |> put_in([Access.at(0), "skill"], "HLIF_HEAL_TEST")

    for {name, rows} <- [{"species.yml", species}, {"exp.yml", exp}, {"trees.yml", trees}] do
      path = Path.join(dir, name)
      File.write!(path, Ymlr.document!(rows))
      path
    end
  end
end
