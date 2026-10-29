defmodule Aesir.ZoneServer.Mmo.ItemManagement.Production.ProduceTest do
  use ExUnit.Case, async: true

  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
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

  describe "offer/4" do
    test "a skill's list keeps only that skill's recipe rows" do
      caster = caster(%{228 => 1}, [{7144, 1}, {507, 1}, {1093, 1}])

      assert 501 in Produce.offer(caster, 22, 0, 228)
      assert Produce.offer(caster, 22, 0, 94) == []
    end
  end

  describe "fits_inventory?/2" do
    test "a non-stackable product always fits" do
      assert Produce.fits_inventory?(%{0 => stack(900, 30_000)}, item_def(:weapon, %{}))
    end

    test "one more copy must fit the item's own inventory stack limit" do
      limited = item_def(:usable, %{inventory: 5})

      assert Produce.fits_inventory?(%{0 => stack(900, 4)}, limited)
      refute Produce.fits_inventory?(%{0 => stack(900, 5)}, limited)
      refute Produce.fits_inventory?(%{}, item_def(:usable, %{inventory: 0}))
    end

    test "only the first slot holding the item is checked against the 30,000 cap" do
      plain = item_def(:usable, %{})

      assert Produce.fits_inventory?(%{3 => stack(900, 1), 50 => stack(900, 29_999)}, plain)
      refute Produce.fits_inventory?(%{3 => stack(900, 30_000), 50 => stack(900, 1)}, plain)
    end

    test "a held stack beyond the usable inventory slots does not fit" do
      plain = item_def(:usable, %{})

      assert Produce.fits_inventory?(%{99 => stack(900, 1)}, plain)
      refute Produce.fits_inventory?(%{100 => stack(900, 1)}, plain)
    end
  end

  describe "fits_inventory?/3" do
    test "a quantity above 30,000 never fits, stackable or not" do
      refute Produce.fits_inventory?(%{}, item_def(:weapon, %{}), 30_001)
      assert Produce.fits_inventory?(%{}, item_def(:usable, %{}), 30_000)
    end

    test "the quantity must fit the item's stack limit, held copies included" do
      limited = item_def(:usable, %{inventory: 5})

      assert Produce.fits_inventory?(%{}, limited, 5)
      refute Produce.fits_inventory?(%{}, limited, 6)
      assert Produce.fits_inventory?(%{0 => stack(900, 2)}, limited, 3)
      refute Produce.fits_inventory?(%{0 => stack(900, 2)}, limited, 4)
    end

    test "the first held stack plus the quantity must stay within 30,000" do
      plain = item_def(:usable, %{})

      assert Produce.fits_inventory?(%{0 => stack(900, 29_800)}, plain, 200)
      refute Produce.fits_inventory?(%{0 => stack(900, 29_801)}, plain, 200)
    end
  end

  describe "producible/5" do
    test "every material must be held for the whole quantity; a guide only once" do
      enough = caster(%{228 => 10}, [{7144, 1}, {509, 200}, {1093, 200}])
      short = caster(%{228 => 10}, [{7144, 1}, {509, 199}, {1093, 200}])

      assert {:ok, %{product_id: 504}} = Produce.producible(enough, 504, -1, 0, 200)
      assert :error = Produce.producible(short, 504, -1, 0, 200)
      assert {:ok, _recipe} = Produce.producible(short, 504, -1, 0, 199)
    end
  end

  describe "producible/4" do
    test "a negative trigger accepts a recipe of any item level" do
      caster = caster(%{94 => 1}, [{1002, 1}])

      assert {:ok, %{product_id: 998}} = Produce.producible(caster, 998, -1, 0)
      assert :error = Produce.producible(caster, 998, 1, 0)
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

  defp item_def(type, stack_limit),
    do: %ItemDefinition{
      id: 900,
      aegis_name: "Test",
      name: "Test",
      type: type,
      stack_limit: stack_limit
    }

  defp stack(id, amount), do: %InventoryItem{nameid: id, amount: amount, identify: 1}

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
