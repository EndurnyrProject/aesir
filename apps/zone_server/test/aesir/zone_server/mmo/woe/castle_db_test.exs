defmodule Aesir.ZoneServer.Mmo.Woe.CastleDbTest do
  use ExUnit.Case, async: false

  alias Aesir.ZoneServer.Mmo.Woe.CastleDb
  alias Aesir.ZoneServer.Mmo.Woe.CastleDb.Castle

  describe "reload/0" do
    test "loads the 20 FE castles into :persistent_term" do
      assert :ok = CastleDb.reload()
      assert length(CastleDb.all()) == 20
    end
  end

  describe "import overlay" do
    setup context do
      on_exit(&CastleDb.reload/0)
      Aesir.ZoneServer.DbTestSetup.configure_root(context, "castles")
    end

    @tag :tmp_dir
    test "reload replaces a castle with its imported definition", %{tmp_dir: dir} do
      base = Path.join(dir, "base.yml")

      File.write!(
        base,
        castle_yaml(name: "Base Castle", map: "base_map", emperium: [1, 2], box_id: 1324)
      )

      import = Path.join([dir, "..", "..", "import", "castles", "custom.yml"])
      File.mkdir_p!(Path.dirname(import))

      File.write!(
        import,
        castle_yaml(name: "Custom Castle", map: "custom_map", emperium: [5, 6], box_id: 1326)
      )

      assert :ok = CastleDb.reload()

      assert {:ok, %Castle{name: "Custom Castle", map: "custom_map", emperium: {5, 6}}} =
               CastleDb.by_id(1)

      assert :error = CastleDb.by_map("base_map")
    end
  end

  describe "lookups" do
    setup do
      :ok = CastleDb.reload()
      :ok
    end

    test "by_id/1 resolves a known castle with tuple coordinates" do
      assert {:ok, %Castle{} = castle} = CastleDb.by_id(16)
      assert castle.map == "prtg_cas02"
      assert castle.emperium == {157, 174}
      assert castle.respawn == {94, 56}
    end

    test "by_map/1 resolves a known castle with tuple coordinates" do
      assert {:ok, %Castle{} = castle} = CastleDb.by_map("prtg_cas01")
      assert castle.id == 15
      assert castle.emperium == {197, 197}
      assert castle.respawn == {107, 180}
    end

    test "unknown id and map return :error" do
      assert :error = CastleDb.by_id(999)
      assert :error = CastleDb.by_map("nonexistent_map")
    end
  end

  describe "%Castle{}" do
    test "exposes emperium and respawn as positive-integer tuples" do
      assert {:ok, castle} = CastleDb.by_id(16)

      assert match?(
               {x, y} when is_integer(x) and x > 0 and is_integer(y) and y > 0,
               castle.emperium
             )

      assert match?(
               {x, y} when is_integer(x) and x > 0 and is_integer(y) and y > 0,
               castle.respawn
             )
    end

    test "exposes treasure as a box id with exactly 24 positive-integer tuple cells" do
      assert {:ok, castle} = CastleDb.by_id(16)

      assert %{box_id: box_id, cells: cells} = castle.treasure
      assert is_integer(box_id) and box_id > 0
      assert length(cells) == 24

      assert Enum.all?(cells, fn
               {x, y} -> is_integer(x) and x > 0 and is_integer(y) and y > 0
               _other -> false
             end)
    end
  end

  describe "treasure loading" do
    setup context do
      on_exit(&CastleDb.reload/0)
      Aesir.ZoneServer.DbTestSetup.configure_root(context, "castles")
    end

    @tag :tmp_dir
    test "converts treasure.cells from list-of-pairs into tuples", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "base.yml"), castle_yaml())

      assert :ok = CastleDb.reload()
      assert {:ok, %Castle{treasure: treasure}} = CastleDb.by_id(1)

      assert treasure.box_id == 1324
      assert treasure.cells == Enum.map(1..24, &{&1, &1 + 1})
    end

    @tag :tmp_dir
    test "raises when a castle's treasure does not have exactly 24 cells", %{tmp_dir: dir} do
      File.write!(Path.join(dir, "base.yml"), castle_yaml(cell_count: 23))

      assert_raise RuntimeError, ~r/24/, fn -> CastleDb.reload() end
    end
  end

  defp castle_yaml(opts \\ []) do
    cell_count = Keyword.get(opts, :cell_count, 24)
    box_id = Keyword.get(opts, :box_id, 1324)

    Ymlr.document!([
      %{
        id: Keyword.get(opts, :id, 1),
        name: Keyword.get(opts, :name, "Test Castle"),
        map: Keyword.get(opts, :map, "test_map"),
        client_id: Keyword.get(opts, :client_id, 1),
        emperium: Keyword.get(opts, :emperium, [1, 2]),
        respawn: Keyword.get(opts, :respawn, [3, 4]),
        treasure: %{box_id: box_id, cells: Enum.map(1..cell_count, &[&1, &1 + 1])}
      }
    ])
  end
end
