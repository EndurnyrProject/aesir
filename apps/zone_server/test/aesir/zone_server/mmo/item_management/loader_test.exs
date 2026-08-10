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
    bind_on_equip: true
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
               by_id: %{
                 501 => %ItemDefinition{
                   aegis_name: "Red_Potion",
                   type: :healing,
                   no_trade: false
                 }
               },
               by_aegis: %{
                 "Knife" => %ItemDefinition{
                   id: 1201,
                   type: :weapon,
                   subtype: :dagger,
                   jobs: [:swordman],
                   locations: [:right_hand],
                   refineable: true,
                   bind_on_equip: true
                 }
               }
             } = Loader.load(dir)

      assert length(all) == 2
    end

    @tag :tmp_dir
    test "writes a reusable .etf cache", %{tmp_dir: dir} do
      write_yaml(dir, @items_yaml)
      Loader.load(dir)

      assert File.exists?(Path.join([dir, ".cache", "items_v3.etf"]))
    end

    @tag :tmp_dir
    test "reuses the cache while it is newer than the sources", %{tmp_dir: dir} do
      yaml = write_yaml(dir, @items_yaml)
      Loader.load(dir)

      cache = Path.join([dir, ".cache", "items_v3.etf"])
      File.write!(yaml, String.replace(@items_yaml, "weight: 70", "weight: 99"))
      File.touch!(yaml, 1_000_000)
      File.touch!(cache, 2_000_000)

      assert %{by_id: %{501 => %ItemDefinition{weight: 70}}} = Loader.load(dir)
    end

    @tag :tmp_dir
    test "rebuilds when a source is newer than the cache", %{tmp_dir: dir} do
      yaml = write_yaml(dir, @items_yaml)
      Loader.load(dir)

      cache = Path.join([dir, ".cache", "items_v3.etf"])
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
    test "atomizes attack_element when present and defaults to nil", %{tmp_dir: dir} do
      write_yaml(dir, """
      - id: 1752
        aegis_name: Fire_Arrow
        name: Fire Arrow
        type: ammo
        subtype: arrow
        attack_element: fire
      - id: 1750
        aegis_name: Arrow
        name: Arrow
        type: ammo
        subtype: arrow
      """)

      assert %{
               by_id: %{
                 1752 => %ItemDefinition{attack_element: :fire},
                 1750 => %ItemDefinition{attack_element: nil}
               }
             } = Loader.load(dir)
    end

    @tag :tmp_dir
    test "script_overrides.yml replaces the generated on_use", %{tmp_dir: dir} do
      write_yaml(dir, """
      - id: 501
        aegis_name: Red_Potion
        name: Red Potion
        type: healing
        weight: 70
        on_use: "heal(ctx, hp: 45..65)"
      """)

      File.write!(Path.join(dir, "script_overrides.yml"), """
      - id: 501
        on_use: "heal(ctx, hp: 999)"
      """)

      assert %{by_id: %{501 => %ItemDefinition{on_use: "heal(ctx, hp: 999)"}}} = Loader.load(dir)
    end

    @tag :tmp_dir
    test "re-imported Stone stays active while the Supplement override survives", %{tmp_dir: dir} do
      write_yaml(dir, """
      - id: 12040
        aegis_name: Stone_Of_Intelligence_
        name: Stone of Sage
        type: usable
        on_use: "homevolution(ctx)"
      - id: 100371
        aegis_name: Homun_F_Tablet
        name: Homunculus Nutritional Supplement
        type: usable
      """)

      File.cp!(
        Application.app_dir(:zone_server, "priv/db/items/script_overrides.yml"),
        Path.join(dir, "script_overrides.yml")
      )

      assert %{
               by_id: %{
                 12_040 => %ItemDefinition{on_use: "homevolution(ctx)"},
                 100_371 => %ItemDefinition{on_use: "add_homunculus_intimacy(ctx, 100)"}
               }
             } = Loader.load(dir)
    end

    @tag :tmp_dir
    test "items without an override keep their on_use; the override file is not an item",
         %{tmp_dir: dir} do
      write_yaml(dir, @items_yaml)

      File.write!(Path.join(dir, "script_overrides.yml"), """
      - id: 999999
        on_use: "heal(ctx, hp: 1)"
      """)

      assert %{all: all, by_id: by_id} = Loader.load(dir)
      assert length(all) == 2
      refute Map.has_key?(by_id, 999_999)
    end

    @tag :tmp_dir
    test "touching script_overrides.yml invalidates the items_v3.etf cache", %{tmp_dir: dir} do
      items = write_yaml(dir, @items_yaml)
      overrides = Path.join(dir, "script_overrides.yml")
      File.write!(overrides, "- id: 501\n  on_use: \"heal(ctx, hp: 1)\"\n")
      Loader.load(dir)

      cache = Path.join([dir, ".cache", "items_v3.etf"])
      File.write!(overrides, "- id: 501\n  on_use: \"heal(ctx, hp: 2)\"\n")
      File.touch!(items, 1_000_000)
      File.touch!(cache, 2_000_000)
      File.touch!(overrides, 3_000_000)

      assert %{by_id: %{501 => %ItemDefinition{on_use: "heal(ctx, hp: 2)"}}} = Loader.load(dir)
    end

    @tag :tmp_dir
    test "parses an on_equip DSL source via EquipScript.parse!/1", %{tmp_dir: dir} do
      write_yaml(dir, """
      - id: 490160
        aegis_name: ST_Orleans_Glove
        name: Orleans's Glove
        type: armor
        on_equip: |-
          ctx = bonus(ctx, :smatk, 3)
          ctx = bonus(ctx, :spl, 2)
          ctx
      """)

      assert %{
               by_id: %{
                 490_160 => %ItemDefinition{on_equip: [{:bonus, :smatk, 3}, {:bonus, :spl, 2}]}
               }
             } = Loader.load(dir)
    end

    @tag :tmp_dir
    test "on_equip defaults to nil when not present", %{tmp_dir: dir} do
      write_yaml(dir, @items_yaml)

      assert %{by_id: %{501 => %ItemDefinition{on_equip: nil}}} = Loader.load(dir)
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
