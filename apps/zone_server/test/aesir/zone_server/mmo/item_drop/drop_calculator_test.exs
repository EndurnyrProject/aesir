defmodule Aesir.ZoneServer.Mmo.ItemDrop.DropCalculatorTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Mmo.ItemDrop.DropCalculator
  alias Aesir.ZoneServer.Mmo.ItemDrop.LevelPenalty
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDrop

  setup :verify_on_exit!

  setup do
    :rand.seed(:exsss, {1, 2, 3})
    :ok
  end

  defp drop(rate), do: %MobDrop{item: "Red_Potion", rate: rate}

  describe "drop_rate/4" do
    test "leaves a no-penalty rate unchanged" do
      stub(LevelPenalty, :drop, fn _, _ -> 100 end)

      assert DropCalculator.drop_rate(10_000, 0, 1, 1) == 10_000
      assert DropCalculator.drop_rate(8_000, 0, 1, 1) == 8_000
    end

    test "does not reduce items whose base rate is already above the 90% cap" do
      stub(LevelPenalty, :drop, fn _, _ -> 100 end)

      assert DropCalculator.drop_rate(9_500, 0, 1, 1) == 9_500
    end

    test "applies the renewal level penalty" do
      stub(LevelPenalty, :drop, fn _, _ -> 50 end)

      assert DropCalculator.drop_rate(10_000, 0, 1, 100) == 5_000
    end

    test "floors at 1 so a tiny rate never rounds to zero" do
      stub(LevelPenalty, :drop, fn _, _ -> 50 end)

      assert DropCalculator.drop_rate(1, 0, 1, 100) == 1
    end
  end

  describe "roll/7" do
    setup do
      stub(LevelPenalty, :drop, fn _, _ -> 100 end)
      stub(MapCache, :walkable?, fn _, _, _ -> true end)

      stub(ItemManagement, :get_item_by_aegis, fn "Red_Potion" ->
        {:ok, %{id: 501}}
      end)

      :ok
    end

    test "a guaranteed slot always yields its item at the death cell" do
      assert [{501, 1, 150, 150}] =
               DropCalculator.roll([drop(10_000)], 0, 1, 1, "prontera", 150, 150)
    end

    test "skips an aegis name absent from ItemManagement without crashing" do
      stub(ItemManagement, :get_item_by_aegis, fn _ -> {:error, :item_not_found} end)

      assert [] = DropCalculator.roll([drop(10_000)], 0, 1, 1, "prontera", 150, 150)
    end

    test "scatters multiple drops onto walkable cells around the death cell" do
      drops = [drop(10_000), drop(10_000)]

      result = DropCalculator.roll(drops, 0, 1, 1, "prontera", 150, 150)

      assert [{501, 1, x0, y0}, {501, 1, x1, y1}] = result
      assert {x0, y0} == {150, 150}
      assert Enum.all?(result, fn {_, _, x, y} -> MapCache.walkable?("prontera", x, y) end)
      refute {x1, y1} == {x0, y0}
    end

    test "falls back to the death cell when the scatter target is unwalkable" do
      stub(MapCache, :walkable?, fn
        _map, 150, 150 -> true
        _map, _, _ -> false
      end)

      drops = [drop(10_000), drop(10_000)]

      assert [{501, 1, 150, 150}, {501, 1, 150, 150}] =
               DropCalculator.roll(drops, 0, 1, 1, "prontera", 150, 150)
    end
  end
end
