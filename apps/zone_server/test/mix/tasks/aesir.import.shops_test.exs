defmodule Mix.Tasks.Aesir.Import.ShopsTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Npc.Shops
  alias Aesir.ZoneServer.Npc.ShopVerifier
  alias Aesir.ZoneServer.Npc.Warps
  alias Mix.Tasks.Aesir.Import.Shops, as: Task

  describe "resolve_duplicates/3" do
    test "fills a duplicate's items and discount flag from its source shop" do
      shop =
        "Tool Dealer#alb"
        |> shop_map([%{"id" => 501, "price" => nil}])
        |> Map.put("discount", false)

      duplicates = [{"Tool Dealer#alb", partial_map("Tool Dealer#alb2")}]

      assert {resolved, []} = Task.resolve_duplicates([shop], duplicates)

      assert [
               %{"id" => "Tool Dealer#alb"},
               %{
                 "id" => "Tool Dealer#alb2",
                 "items" => [%{"id" => 501, "price" => nil}],
                 "discount" => false
               }
             ] = resolved
    end

    test "classifies a duplicate of a script source as :duplicate_of_script" do
      shops = [shop_map("Tool Dealer#alb", [%{"id" => 501, "price" => nil}])]
      duplicates = [{"GuildWarehouse", partial_map("Guild Warehouse#1")}]
      sources = %{"GuildWarehouse" => :script}

      assert {[%{"id" => "Tool Dealer#alb"}], [:duplicate_of_script]} =
               Task.resolve_duplicates(shops, duplicates, sources)
    end

    test "classifies a duplicate of a cashshop source as :duplicate_of_cashshop" do
      duplicates = [{"idRO_kafra", partial_map("Kafra Cash#1")}]
      sources = %{"idRO_kafra" => :cashshop}

      assert {[], [:duplicate_of_cashshop]} =
               Task.resolve_duplicates([], duplicates, sources)
    end

    test "falls back to :unknown_duplicate_source when no source is known" do
      duplicates = [{"IceCreamer", partial_map("Ice Cream Maker#1")}]

      assert {[], [:unknown_duplicate_source]} =
               Task.resolve_duplicates([], duplicates, %{})
    end
  end

  describe "generated corpus" do
    setup :setup_ets_tables

    setup do
      :persistent_term.erase(Shops)
      on_exit(fn -> :persistent_term.erase(Shops) end)
      :ok
    end

    test "loads from priv/db/shops and passes the fatal boot verifier" do
      stub(NpcRegistry, :entries, fn -> [] end)
      stub(Warps, :all, fn -> %{} end)

      :ok = Shops.reload()
      all = Shops.all()

      assert map_size(all) > 1
      assert :ok = ShopVerifier.verify!(all)
    end
  end

  defp shop_map(id, items) do
    %{
      "id" => id,
      "name" => id |> String.split("#") |> hd(),
      "map" => "alberta_in",
      "x" => 165,
      "y" => 96,
      "dir" => 0,
      "sprite" => 74,
      "items" => items
    }
  end

  defp partial_map(id), do: shop_map(id, []) |> Map.delete("items")
end
