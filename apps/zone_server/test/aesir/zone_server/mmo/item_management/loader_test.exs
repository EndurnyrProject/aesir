defmodule Aesir.ZoneServer.Mmo.ItemManagement.LoaderTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.ItemManagement.Loader

  @items_yaml """
  - id: 501
    aegis_name: Red_Potion
    name: Red Potion
    type: healing
    weight: 70
  - id: 1201
    aegis_name: Knife
    name: Knife
    type: weapon
    subtype: dagger
    jobs:
      - swordman
    locations:
      - right_hand
    refineable: true
  """

  defp write_yaml(dir, contents) do
    path = Path.join(dir, "items.yml")
    File.write!(path, contents)
    path
  end

  describe "load/1" do
    @tag :tmp_dir
    test "parses our-schema YAML into an index by id and aegis", %{tmp_dir: dir} do
      write_yaml(dir, @items_yaml)

      assert %{
               all: all,
               by_id: %{501 => %ItemDefinition{aegis_name: "Red_Potion", type: :healing}},
               by_aegis: %{
                 "Knife" => %ItemDefinition{
                   id: 1201,
                   type: :weapon,
                   subtype: :dagger,
                   jobs: [:swordman],
                   locations: [:right_hand],
                   refineable: true
                 }
               }
             } = Loader.load(dir)

      assert length(all) == 2
    end

    @tag :tmp_dir
    test "writes a reusable .etf cache", %{tmp_dir: dir} do
      write_yaml(dir, @items_yaml)
      Loader.load(dir)

      assert File.exists?(Path.join([dir, ".cache", "items.etf"]))
    end

    @tag :tmp_dir
    test "reuses the cache while it is newer than the sources", %{tmp_dir: dir} do
      yaml = write_yaml(dir, @items_yaml)
      Loader.load(dir)

      cache = Path.join([dir, ".cache", "items.etf"])
      File.write!(yaml, String.replace(@items_yaml, "weight: 70", "weight: 99"))
      File.touch!(yaml, 1_000_000)
      File.touch!(cache, 2_000_000)

      assert %{by_id: %{501 => %ItemDefinition{weight: 70}}} = Loader.load(dir)
    end

    @tag :tmp_dir
    test "rebuilds when a source is newer than the cache", %{tmp_dir: dir} do
      yaml = write_yaml(dir, @items_yaml)
      Loader.load(dir)

      cache = Path.join([dir, ".cache", "items.etf"])
      File.write!(yaml, String.replace(@items_yaml, "weight: 70", "weight: 99"))
      File.touch!(cache, 1_000_000)
      File.touch!(yaml, 2_000_000)

      assert %{by_id: %{501 => %ItemDefinition{weight: 99}}} = Loader.load(dir)
    end

    @tag :tmp_dir
    test "raises a helpful error when there are no data files", %{tmp_dir: dir} do
      assert_raise RuntimeError, ~r/no data files in .*#{Path.basename(dir)}/, fn ->
        Loader.load(dir)
      end
    end

    @tag :tmp_dir
    test "parses on_use string field when present", %{tmp_dir: dir} do
      write_yaml(dir, """
      - id: 501
        aegis_name: Red_Potion
        name: Red Potion
        type: healing
        weight: 70
        on_use: "heal(ctx, hp: 45..65)"
      """)

      assert %{by_id: %{501 => %ItemDefinition{on_use: "heal(ctx, hp: 45..65)"}}} =
               Loader.load(dir)
    end

    @tag :tmp_dir
    test "on_use defaults to nil when not present", %{tmp_dir: dir} do
      write_yaml(dir, """
      - id: 501
        aegis_name: Red_Potion
        name: Red Potion
        type: healing
        weight: 70
      """)

      assert %{by_id: %{501 => %ItemDefinition{on_use: nil}}} = Loader.load(dir)
    end

    @tag :tmp_dir
    test "on_use preserves multiline block content", %{tmp_dir: dir} do
      write_yaml(dir, """
      - id: 501
        aegis_name: Red_Potion
        name: Red Potion
        type: healing
        weight: 70
        on_use: |
          heal(ctx, hp: 45..65)
          log(ctx, :used_potion)
      """)

      assert %{by_id: %{501 => %ItemDefinition{on_use: on_use}}} = Loader.load(dir)
      assert on_use =~ "heal(ctx, hp: 45..65)\n"
      assert on_use =~ "log(ctx, :used_potion)\n"
    end
  end
end
