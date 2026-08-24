defmodule Aesir.ZoneServer.Mmo.ItemManagement.ArrowCraftingTest do
  use ExUnit.Case, async: false

  alias Aesir.ZoneServer.Mmo.ItemManagement.ArrowCrafting
  alias Aesir.ZoneServer.Mmo.ItemManagement.ArrowCrafting.Recipe
  alias Aesir.ZoneServer.Mmo.ItemManagement.Items

  describe "all/0" do
    test "loads the imported recipe table" do
      recipes = ArrowCrafting.all()

      assert length(recipes) > 100
      assert Enum.all?(recipes, &match?(%Recipe{}, &1))
    end

    test "every source and product resolves in the item catalog" do
      for %Recipe{source_id: source_id, makes: makes} <- ArrowCrafting.all() do
        assert {:ok, _} = Items.by_id(source_id)

        for %{item_id: item_id, amount: amount} <- makes do
          assert {:ok, _} = Items.by_id(item_id)
          assert amount > 0
        end
      end
    end
  end

  describe "import overlay" do
    @tag :tmp_dir
    test "overrides and appends recipes identically in both modes", %{tmp_dir: root} do
      previous = [
        {:commons, :game_mode, Application.get_env(:commons, :game_mode)},
        {:zone_server, :db_root, Application.get_env(:zone_server, :db_root)}
      ]

      on_exit(fn ->
        Enum.each(previous, fn
          {app, key, nil} -> Application.delete_env(app, key)
          {app, key, value} -> Application.put_env(app, key, value)
        end)

        ArrowCrafting.reload()
      end)

      File.write!(Path.join(root, "arrows.yml"), """
      - source: 1
        make:
          - item: 101
            amount: 1
      - source: 2
        make:
          - item: 102
            amount: 2
      """)

      import = Path.join([root, "import", "arrows.yml"])
      File.mkdir_p!(Path.dirname(import))

      File.write!(import, """
      - source: 1
        make:
          - item: 201
            amount: 3
      - source: 3
        make:
          - item: 203
            amount: 4
      """)

      Application.put_env(:zone_server, :db_root, root)
      Application.put_env(:commons, :game_mode, :renewal)
      assert :ok = ArrowCrafting.reload()

      renewal = {ArrowCrafting.all(), ArrowCrafting.for_source(1), ArrowCrafting.for_source(3)}

      assert {
               [
                 %Recipe{source_id: 1, makes: [%{item_id: 201, amount: 3}]},
                 %Recipe{source_id: 2, makes: [%{item_id: 102, amount: 2}]},
                 %Recipe{source_id: 3, makes: [%{item_id: 203, amount: 4}]}
               ],
               {:ok, %Recipe{source_id: 1, makes: [%{item_id: 201, amount: 3}]}},
               {:ok, %Recipe{source_id: 3, makes: [%{item_id: 203, amount: 4}]}}
             } = renewal

      Application.put_env(:commons, :game_mode, :pre_renewal)
      assert :ok = ArrowCrafting.reload()

      assert {ArrowCrafting.all(), ArrowCrafting.for_source(1), ArrowCrafting.for_source(3)} ==
               renewal
    end
  end

  describe "for_source/1" do
    test "resolves a known recipe (Branch of Dead Tree -> 40 Mute Arrows)" do
      assert {:ok, %Recipe{source_id: 604, makes: [%{item_id: 1769, amount: 40}]}} =
               ArrowCrafting.for_source(604)
    end

    test "returns :error for an item that crafts nothing" do
      assert :error = ArrowCrafting.for_source(501)
    end
  end
end
