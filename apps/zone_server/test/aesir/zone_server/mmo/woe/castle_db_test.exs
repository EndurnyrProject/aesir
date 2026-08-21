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

      File.write!(base, """
      - id: 1
        name: Base Castle
        map: base_map
        client_id: 1
        emperium: [1, 2]
        respawn: [3, 4]
      """)

      import = Path.join([dir, "..", "..", "import", "castles", "custom.yml"])
      File.mkdir_p!(Path.dirname(import))

      File.write!(import, """
      - id: 1
        name: Custom Castle
        map: custom_map
        client_id: 2
        emperium: [5, 6]
        respawn: [7, 8]
      """)

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
  end
end
