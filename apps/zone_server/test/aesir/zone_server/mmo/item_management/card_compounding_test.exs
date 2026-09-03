defmodule Aesir.ZoneServer.Mmo.ItemManagement.CardCompoundingTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.CardCompounding
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition

  @card_id 90_001
  @target_id 90_002
  @other_target_id 90_003
  @third_target_id 90_004

  setup :verify_on_exit!
  setup :set_mimic_from_context

  test "compounds one card into the first free declared socket" do
    stub_catalog(%{
      @card_id => definition(@card_id, :card, [:armor]),
      @target_id => definition(@target_id, :armor, [:armor], 3)
    })

    card = item(@card_id, amount: 2)
    target = item(@target_id, card0: 40_001, card2: 40_003)
    inventory = %{7 => card, 3 => target}

    assert {:ok, compounded, {:card_compounded, 7, 3, :card1}} =
             CardCompounding.compound(inventory, 7, 3)

    assert compounded[7].amount == 1
    assert compounded[3].card0 == 40_001
    assert compounded[3].card1 == @card_id
    assert compounded[3].card2 == 40_003
    assert compounded[3].card3 == 0
  end

  test "rejects invalid card sources with typed reasons and no mutation" do
    target = item(@target_id)

    cases = [
      {%{3 => target}, 7, %{}, :card_not_found},
      {%{7 => :malformed, 3 => target}, 7, %{}, :card_not_found},
      {%{7 => item(@card_id, amount: 0), 3 => target}, 7, %{}, :card_not_found},
      {%{7 => item(@card_id, amount: -1), 3 => target}, 7, %{}, :card_not_found},
      {%{7 => item(@card_id, amount: "1"), 3 => target}, 7, %{}, :card_not_found},
      {%{7 => item(0), 3 => target}, 7, %{}, :card_not_found},
      {%{7 => item(@card_id), 3 => target}, 7, %{@card_id => definition(@card_id, :etc, [])},
       :not_a_card},
      {%{7 => item(@card_id), 3 => target}, 7, %{}, :not_a_card},
      {%{7 => item(@card_id, equip: 16), 3 => target}, 7,
       %{@card_id => definition(@card_id, :card, [:armor])}, :card_source_equipped},
      {%{7 => item(@card_id, equip: -1), 3 => target}, 7,
       %{@card_id => definition(@card_id, :card, [:armor])}, :card_source_equipped}
    ]

    for {inventory, card_index, definitions, reason} <- cases do
      stub_catalog(Map.put(definitions, @target_id, definition(@target_id, :armor, [:armor], 1)))
      original = inventory

      assert CardCompounding.eligible_targets(inventory, card_index) == {:error, reason}
      assert CardCompounding.compound(inventory, card_index, 3) == {:error, reason}
      assert inventory == original
    end
  end

  test "rejects invalid equipment targets with typed reasons and no mutation" do
    card_definition = definition(@card_id, :card, [:armor])

    cases = [
      {%{7 => item(@card_id)}, 3, %{}, :target_not_found},
      {%{7 => item(@card_id), 3 => :malformed}, 3, %{}, :target_not_found},
      {%{7 => item(@card_id), 3 => item(@target_id, amount: 0)}, 3,
       %{@target_id => definition(@target_id, :armor, [:armor], 1)}, :target_not_found},
      {%{7 => item(@card_id), 3 => item(@target_id, amount: -1)}, 3,
       %{@target_id => definition(@target_id, :armor, [:armor], 1)}, :target_not_found},
      {%{7 => item(@card_id), 3 => item(@target_id, amount: "1")}, 3,
       %{@target_id => definition(@target_id, :armor, [:armor], 1)}, :target_not_found},
      {%{7 => item(@card_id), 3 => item(0)}, 3, %{}, :target_not_found},
      {%{7 => item(@card_id)}, 7, %{}, :same_inventory_slot},
      {%{7 => item(@card_id), 3 => item(@target_id)}, 3,
       %{@target_id => definition(@target_id, :etc, [:armor], 1)}, :not_equipment},
      {%{7 => item(@card_id), 3 => item(@target_id)}, 3, %{}, :not_equipment},
      {%{7 => item(@card_id), 3 => item(@target_id, identify: 0)}, 3,
       %{@target_id => definition(@target_id, :armor, [:armor], 1)}, :target_unidentified},
      {%{7 => item(@card_id), 3 => item(@target_id, identify: 2)}, 3,
       %{@target_id => definition(@target_id, :armor, [:armor], 1)}, :target_unidentified},
      {%{7 => item(@card_id), 3 => item(@target_id, equip: 16)}, 3,
       %{@target_id => definition(@target_id, :armor, [:armor], 1)}, :target_equipped},
      {%{7 => item(@card_id), 3 => item(@target_id, equip: -1)}, 3,
       %{@target_id => definition(@target_id, :armor, [:armor], 1)}, :target_equipped}
    ]

    for {inventory, equipment_index, definitions, reason} <- cases do
      stub_catalog(Map.put(definitions, @card_id, card_definition))
      original = inventory

      assert CardCompounding.compound(inventory, 7, equipment_index) == {:error, reason}
      assert inventory == original
    end
  end

  test "requires card and equipment location masks to intersect" do
    stub_catalog(%{
      @card_id => definition(@card_id, :card, [:armor]),
      @target_id => definition(@target_id, :weapon, [:right_hand], 1)
    })

    inventory = %{7 => item(@card_id), 3 => item(@target_id)}

    assert CardCompounding.eligible_targets(inventory, 7) == {:ok, []}
    assert CardCompounding.compound(inventory, 7, 3) == {:error, :location_mismatch}
    assert inventory[7].amount == 1
    assert inventory[3].card0 == 0
  end

  test "allows shield cards only on armor targets, not left-hand weapons" do
    stub_catalog(%{
      @card_id => definition(@card_id, :card, [:left_hand]),
      @target_id => definition(@target_id, :weapon, [:left_hand], 1),
      @other_target_id => definition(@other_target_id, :armor, [:left_hand], 1)
    })

    inventory = %{
      7 => item(@card_id),
      3 => item(@target_id),
      5 => item(@other_target_id)
    }

    assert CardCompounding.eligible_targets(inventory, 7) == {:ok, [5]}
    assert CardCompounding.compound(inventory, 7, 3) == {:error, :location_mismatch}

    assert {:ok, compounded, {:card_compounded, 7, 5, :card0}} =
             CardCompounding.compound(inventory, 7, 5)

    assert compounded[5].card0 == @card_id
  end

  test "side-specific accessory cards require an armor target with the same specific side" do
    stub_catalog(%{
      @card_id => definition(@card_id, :card, [:right_accessory]),
      @target_id => definition(@target_id, :armor, [:right_accessory], 1),
      @other_target_id => definition(@other_target_id, :armor, [:left_accessory], 1),
      @third_target_id => definition(@third_target_id, :armor, [:both_accessory], 1)
    })

    inventory = %{
      7 => item(@card_id),
      2 => item(@target_id),
      3 => item(@other_target_id),
      4 => item(@third_target_id)
    }

    assert CardCompounding.eligible_targets(inventory, 7) == {:ok, [2]}
    assert CardCompounding.compound(inventory, 7, 3) == {:error, :location_mismatch}
    assert CardCompounding.compound(inventory, 7, 4) == {:error, :location_mismatch}
  end

  test "left-specific accessory cards reject right and dual-side accessory targets" do
    stub_catalog(%{
      @card_id => definition(@card_id, :card, [:left_accessory]),
      @target_id => definition(@target_id, :armor, [:right_accessory], 1),
      @other_target_id => definition(@other_target_id, :armor, [:left_accessory], 1),
      @third_target_id => definition(@third_target_id, :armor, [:both_accessory], 1)
    })

    inventory = %{
      7 => item(@card_id),
      2 => item(@target_id),
      3 => item(@other_target_id),
      4 => item(@third_target_id)
    }

    assert CardCompounding.eligible_targets(inventory, 7) == {:ok, [3]}
    assert CardCompounding.compound(inventory, 7, 2) == {:error, :location_mismatch}
    assert CardCompounding.compound(inventory, 7, 4) == {:error, :location_mismatch}
  end

  test "a both-accessory card accepts either specific accessory side" do
    stub_catalog(%{
      @card_id => definition(@card_id, :card, [:both_accessory]),
      @target_id => definition(@target_id, :armor, [:right_accessory], 1),
      @other_target_id => definition(@other_target_id, :armor, [:left_accessory], 1),
      @third_target_id => definition(@third_target_id, :armor, [:both_accessory], 1)
    })

    inventory = %{
      7 => item(@card_id),
      6 => item(@target_id),
      2 => item(@other_target_id),
      4 => item(@third_target_id)
    }

    assert CardCompounding.eligible_targets(inventory, 7) == {:ok, [2, 4, 6]}
  end

  test "exposes no free socket for non-positive or full bounded slot counts" do
    card_definition = definition(@card_id, :card, [:armor])

    cases = [
      {-2, []},
      {0, []},
      {1, [card0: 41_001]},
      {2, [card0: 41_001, card1: 41_002]},
      {3, [card0: 41_001, card1: 41_002, card2: 41_003]},
      {4, [card0: 41_001, card1: 41_002, card2: 41_003, card3: 41_004]},
      {5, [card0: 41_001, card1: 41_002, card2: 41_003, card3: 41_004]}
    ]

    for {slots, cards} <- cases do
      stub_catalog(%{
        @card_id => card_definition,
        @target_id => definition(@target_id, :armor, [:armor], slots)
      })

      inventory = %{7 => item(@card_id), 3 => item(@target_id, cards)}
      original = inventory

      assert CardCompounding.eligible_targets(inventory, 7) == {:ok, []}
      assert CardCompounding.compound(inventory, 7, 3) == {:error, :no_free_socket}
      assert inventory == original
    end
  end

  test "selects the first zero field within one through four bounded sockets" do
    cases = [
      {1, [card1: 42_002], :card0},
      {2, [card0: 42_001], :card1},
      {3, [card0: 42_001, card1: 42_002], :card2},
      {4, [card0: 42_001, card1: 42_002, card2: 42_003], :card3},
      {8, [card0: 42_001, card1: 42_002, card2: 42_003], :card3}
    ]

    for {slots, occupied, expected_field} <- cases do
      stub_catalog(%{
        @card_id => definition(@card_id, :card, [:armor]),
        @target_id => definition(@target_id, :armor, [:armor], slots)
      })

      inventory = %{7 => item(@card_id), 3 => item(@target_id, occupied)}

      assert {:ok, compounded, {:card_compounded, 7, 3, ^expected_field}} =
               CardCompounding.compound(inventory, 7, 3)

      assert Map.fetch!(compounded[3], expected_field) == @card_id

      for field <- [:card0, :card1, :card2, :card3], field != expected_field do
        assert Map.fetch!(compounded[3], field) == Map.fetch!(inventory[3], field)
      end
    end
  end

  test "removes a one-unit source and permits the same card in another socket" do
    stub_catalog(%{
      @card_id => definition(@card_id, :card, [:armor]),
      @target_id => definition(@target_id, :armor, [:armor], 2)
    })

    inventory = %{
      7 => item(@card_id, amount: 1),
      3 => item(@target_id, card0: @card_id)
    }

    assert {:ok, compounded, {:card_compounded, 7, 3, :card1}} =
             CardCompounding.compound(inventory, 7, 3)

    refute Map.has_key?(compounded, 7)
    assert compounded[3].card0 == @card_id
    assert compounded[3].card1 == @card_id
  end

  test "discovery returns unique ascending indices with confirmation predicate parity" do
    stub_catalog(%{
      @card_id => definition(@card_id, :card, [:armor]),
      @target_id => definition(@target_id, :armor, [:armor], 1)
    })

    inventory = %{
      9 => item(@target_id),
      7 => item(@card_id),
      5 => item(@target_id),
      4 => :malformed,
      3 => item(@target_id, identify: 0),
      2 => item(@target_id, card0: 43_001),
      1 => item(@target_id)
    }

    assert {:ok, targets} = CardCompounding.eligible_targets(inventory, 7)
    assert targets == [1, 5, 9]
    assert targets == targets |> Enum.uniq() |> Enum.sort()

    for equipment_index <- Map.keys(inventory) do
      case CardCompounding.compound(inventory, 7, equipment_index) do
        {:ok, _compounded, _change} -> assert equipment_index in targets
        {:error, _reason} -> refute equipment_index in targets
      end
    end
  end

  test "accepts ordinary weapon cards on compatible weapon targets" do
    stub_catalog(%{
      @card_id => definition(@card_id, :card, [:right_hand]),
      @target_id => definition(@target_id, :weapon, [:right_hand], 1)
    })

    inventory = %{7 => item(@card_id), 3 => item(@target_id)}

    assert CardCompounding.eligible_targets(inventory, 7) == {:ok, [3]}

    assert {:ok, compounded, {:card_compounded, 7, 3, :card0}} =
             CardCompounding.compound(inventory, 7, 3)

    assert compounded[3].card0 == @card_id
  end

  test "confirmation revalidates a target that became stale after discovery" do
    stub_catalog(%{
      @card_id => definition(@card_id, :card, [:armor]),
      @target_id => definition(@target_id, :armor, [:armor], 1)
    })

    inventory = %{7 => item(@card_id), 3 => item(@target_id)}
    assert CardCompounding.eligible_targets(inventory, 7) == {:ok, [3]}

    stale_inventory = put_in(inventory[3].card0, 44_001)

    assert CardCompounding.compound(stale_inventory, 7, 3) == {:error, :no_free_socket}
    assert stale_inventory[7].amount == 1
    assert stale_inventory[3].card0 == 44_001
  end

  defp stub_catalog(definitions) do
    stub(ItemManagement, :get_item_by_id, fn id ->
      case Map.fetch(definitions, id) do
        {:ok, definition} -> {:ok, definition}
        :error -> {:error, :item_not_found}
      end
    end)
  end

  defp definition(id, type, locations, slots \\ 0) do
    %ItemDefinition{
      id: id,
      aegis_name: "item_#{id}",
      name: "Item #{id}",
      type: type,
      locations: locations,
      slots: slots
    }
  end

  defp item(nameid, attrs \\ []) do
    struct(
      InventoryItem,
      Keyword.merge(
        [
          id: System.unique_integer([:positive]),
          char_id: 1,
          nameid: nameid,
          amount: 1,
          equip: 0,
          identify: 1,
          card0: 0,
          card1: 0,
          card2: 0,
          card3: 0,
          random_options: %{}
        ],
        attrs
      )
    )
  end
end
