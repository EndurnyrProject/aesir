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

  describe "drop_rate/5" do
    test "leaves a no-penalty rate unchanged" do
      stub(LevelPenalty, :drop, fn _, _ -> 100 end)

      assert DropCalculator.drop_rate(10_000, 0, 1, 1, 0) == 10_000
      assert DropCalculator.drop_rate(8_000, 0, 1, 1, 0) == 8_000
    end

    test "does not reduce items whose base rate is already above the 90% cap" do
      stub(LevelPenalty, :drop, fn _, _ -> 100 end)

      assert DropCalculator.drop_rate(9_500, 0, 1, 1, 0) == 9_500
    end

    test "applies the renewal level penalty" do
      stub(LevelPenalty, :drop, fn _, _ -> 50 end)

      assert DropCalculator.drop_rate(10_000, 0, 1, 100, 0) == 5_000
    end

    test "floors at 1 so a tiny rate never rounds to zero" do
      stub(LevelPenalty, :drop, fn _, _ -> 50 end)

      assert DropCalculator.drop_rate(1, 0, 1, 100, 0) == 1
    end

    test "a zero bonus leaves the rate untouched, unlike a positive bonus" do
      stub(LevelPenalty, :drop, fn _, _ -> 50 end)

      # base 4000, luk hook no-op, level penalty 50%: unboosted lands at 2000.
      assert DropCalculator.drop_rate(4_000, 7, 50, 60, 0) == 2_000
      # +50% before the cap: 4000 -> 6000, still under cap, then 50% penalty.
      assert DropCalculator.drop_rate(4_000, 7, 50, 60, 50) == 3_000
    end

    test "applies the drop bonus before the cap" do
      stub(LevelPenalty, :drop, fn _, _ -> 100 end)

      # 5000 * (100 + 100)/100 = 10000, then capped at 9000.
      assert DropCalculator.drop_rate(5_000, 0, 1, 1, 100) == 9_000
    end

    test "a boost that stays under the cap is not capped" do
      stub(LevelPenalty, :drop, fn _, _ -> 100 end)

      # 4000 * (100 + 100)/100 = 8000, below the 9000 cap.
      assert DropCalculator.drop_rate(4_000, 0, 1, 1, 100) == 8_000
    end

    test "the cap uses the base rate, so an already-rare item skips the cap even when boosted" do
      stub(LevelPenalty, :drop, fn _, _ -> 100 end)

      # base 9500 > cap, so the cap is skipped; boost still applies.
      assert DropCalculator.drop_rate(9_500, 0, 1, 1, 5) == 9_975
    end
  end

  describe "roll/8" do
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
               DropCalculator.roll([drop(10_000)], 0, 1, 1, 0, "prontera", 150, 150)
    end

    test "skips an aegis name absent from ItemManagement without crashing" do
      stub(ItemManagement, :get_item_by_aegis, fn _ -> {:error, :item_not_found} end)

      assert [] = DropCalculator.roll([drop(10_000)], 0, 1, 1, 0, "prontera", 150, 150)
    end

    test "scatters multiple drops onto walkable cells around the death cell" do
      drops = [drop(10_000), drop(10_000)]

      result = DropCalculator.roll(drops, 0, 1, 1, 0, "prontera", 150, 150)

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
               DropCalculator.roll(drops, 0, 1, 1, 0, "prontera", 150, 150)
    end
  end
end
