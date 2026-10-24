defmodule Aesir.ZoneServer.Mmo.ItemManagement.Production.ProduceTest do
  use ExUnit.Case, async: true

  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.ItemManagement.Production.Produce
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats

  describe "offer/3" do
    test "a hammer lists every held weapon recipe up to its tier" do
      caster = caster(%{98 => 3, 99 => 1}, [{998, 50}, {909, 10}, {984, 4}, {999, 40}, {726, 1}])

      assert Produce.offer(caster, 1, 0) == [1101, 1104, 1201, 1204, 1207]
      assert 1219 not in Produce.offer(caster, 2, 0)
      assert 1219 in Produce.offer(caster, 3, 0)
    end

    test "a recipe needs its skill learned at the recipe's level" do
      caster = caster(%{98 => 2}, [{984, 4}, {999, 40}, {726, 1}])

      assert 1219 not in Produce.offer(caster, 3, 0)
    end

    test "a product is listed only while its materials are held" do
      assert Produce.offer(caster(%{99 => 1}, [{998, 1}]), 1, 0) == []
      assert Produce.offer(caster(%{99 => 1}, [{998, 2}]), 1, 0) == [1101]
    end

    test "the furnace lists only recipes whose item level equals its trigger" do
      caster =
        caster(%{94 => 1, 95 => 1, 96 => 1, 99 => 1}, [{1002, 1}, {1001, 10}, {990, 10}, {998, 2}])

      assert Produce.offer(caster, 21, 0) == [998, 1000, 994]
    end

    test "while another skill's menu is open only that skill's recipes count" do
      caster = caster(%{94 => 1, 96 => 1}, [{1002, 1}, {1001, 10}])

      assert Produce.offer(caster, 21, 94) == [998]
    end

    test "a product whose stack is full is not listed" do
      caster = caster(%{94 => 1}, [{1002, 1}, {998, 30_000}])

      assert Produce.offer(caster, 21, 0) == []
    end
  end

  describe "on_menu_reply/4" do
    test "a reply the trigger does not allow closes without producing" do
      caster = caster(%{98 => 3}, [{984, 4}, {999, 40}, {726, 1}])

      assert {:silent, ^caster} =
               Produce.on_menu_reply(caster, %{id: 1219, extras: []}, 1, %{trading?: false})
    end

    test "a reply while trading fails the skill" do
      caster = caster(%{99 => 1}, [{998, 2}])

      assert {:error, :skill_failed} =
               Produce.on_menu_reply(caster, %{id: 1101, extras: []}, 1, %{trading?: true})
    end
  end

  defp caster(learned, items) do
    stats =
      %Character{class: 10, base_level: 99, job_level: 70, dex: 99, luk: 99}
      |> Stats.from_character()
      |> put_in([Access.key!(:progression), Access.key!(:learned_skills)], learned)

    inventory =
      items
      |> Enum.with_index()
      |> Map.new(fn {{id, amount}, index} ->
        {index, %InventoryItem{nameid: id, amount: amount, identify: 1}}
      end)

    %PlayerState{character_id: 1, stats: stats, inventory: inventory}
  end
end
