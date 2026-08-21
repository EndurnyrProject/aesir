defmodule Aesir.ZoneServer.Mmo.ImportOverlayTest do
  use ExUnit.Case, async: false

  @moduletag :tmp_dir

  alias Aesir.ZoneServer.Mmo.ItemManagement.Items
  alias Aesir.ZoneServer.Mmo.MobManagement.Mobs
  alias Aesir.ZoneServer.Mmo.MobManagement.Spawns

  setup context do
    assert {:ok, _} = Mobs.by_id(1002)

    on_exit(fn ->
      :ok = Items.reload()
      :ok = Spawns.reload()
    end)

    Aesir.ZoneServer.DbTestSetup.configure_root(context, "items")
  end

  @base_items """
  - id: 501
    aegis_name: Red_Potion
    name: Red Potion
    type: healing
    weight: 70
  """

  defp root(items_dir), do: Path.join([items_dir, "..", ".."]) |> Path.expand()

  defp write_yaml(root, path, contents) do
    path = Path.join([root, path])
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, contents)
    path
  end

  test "items reload lets imports replace and append definitions after script overrides", %{
    tmp_dir: items_dir
  } do
    root = root(items_dir)
    write_yaml(root, "re/items/items.yml", @base_items)

    write_yaml(root, "re/items/script_overrides.yml", """
    - id: 501
      on_use: "heal(ctx, hp: 999)"
    """)

    write_yaml(root, "import/items/custom.yml", """
    - id: 501
      aegis_name: Custom_Potion
      name: Custom Potion
      type: usable
    - id: 502
      aegis_name: Orange_Potion
      name: Orange Potion
      type: healing
    """)

    assert :ok = Items.reload()
    assert {:ok, %{name: "Custom Potion", on_use: nil, weight: 0}} = Items.by_id(501)
    assert {:ok, %{name: "Orange Potion"}} = Items.by_id(502)
    assert Enum.map(Items.all(), & &1.id) == [501, 502]
  end

  test "spawns reload appends imports to existing maps without removing base spawns", %{
    tmp_dir: items_dir
  } do
    root = root(items_dir)

    write_yaml(root, "re/spawns/base.yml", """
    - map: base_map
      spawns:
        - mob: 1002
          amount: 1
          respawn_time: 1000
          area:
            x: 10
            y: 10
    """)

    write_yaml(root, "import/spawns/custom.yml", """
    - map: base_map
      spawns:
        - mob: 1002
          amount: 2
          respawn_time: 2000
          area:
            x: 20
            y: 20
    - map: custom_map
      spawns:
        - mob: 1002
          amount: 3
          respawn_time: 3000
          area:
            x: 30
            y: 30
    """)

    assert :ok = Spawns.reload()

    assert {:ok, [%{mob: 1002, amount: 1}, %{mob: 1002, amount: 2}]} =
             Spawns.for_map("base_map")

    assert {:ok, [%{mob: 1002, amount: 3}]} = Spawns.for_map("custom_map")
  end

  test "items reload names an import file with unknown YAML keys", %{tmp_dir: items_dir} do
    root = root(items_dir)
    write_yaml(root, "re/items/items.yml", @base_items)

    import =
      write_yaml(root, "import/items/invalid.yml", """
      - id: 502
        aegis_name: Orange_Potion
        name: Orange Potion
        type: healing
        unknown_key: true
      """)

    assert_raise KeyError, ~r/#{Regex.escape(import)}/, fn ->
      Items.reload()
    end
  end
end
