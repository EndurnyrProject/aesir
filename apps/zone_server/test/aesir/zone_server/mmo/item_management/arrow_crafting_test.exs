defmodule Aesir.ZoneServer.Mmo.ItemManagement.ArrowCraftingTest do
  @moduledoc """
  Verifies the real shared recipe catalog, so reload tests run serially and restore
  the catalog afterwards. Temporary configuration reads are private Mimic stubs.
  """

  use ExUnit.Case, async: false

  alias Aesir.ZoneServer.DbTestSetup
  alias Aesir.ZoneServer.Mmo.ItemManagement.ArrowCrafting
  alias Aesir.ZoneServer.Mmo.ItemManagement.ArrowCrafting.Recipe
  alias Aesir.ZoneServer.Mmo.ItemManagement.Items

  describe "all/0" do
    test "every imported source and product resolves in the item catalog" do
      recipes = ArrowCrafting.all()

      assert recipes != []

      for %Recipe{source_id: source_id, makes: makes} <- recipes do
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
      :ok = DbTestSetup.stub_root(root)
      on_exit(fn -> ArrowCrafting.reload() end)

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

      assert :ok = ArrowCrafting.reload()

      recipes = ArrowCrafting.all()

      assert [
               %Recipe{source_id: 1, makes: [%{item_id: 201, amount: 3}]},
               %Recipe{source_id: 2, makes: [%{item_id: 102, amount: 2}]},
               %Recipe{source_id: 3, makes: [%{item_id: 203, amount: 4}]}
             ] = recipes
    end
  end
end
