defmodule Aesir.ZoneServer.Unit.Player.InventoryViewTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.ItemOption
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemCraft
  alias Aesir.ZoneServer.Unit.Player.InventoryView

  setup :verify_on_exit!
  setup :set_mimic_from_context

  setup do
    stub(ItemManagement, :get_item_by_id, fn _nameid -> {:error, :item_not_found} end)
    :ok
  end

  test "projects signed, forged, plain, and deleted creator metadata with one query" do
    signed = item(craft: ItemCraft.to_map(ItemCraft.signed(10)))
    forged = item(craft: ItemCraft.to_map(ItemCraft.forged(:fire, 2, 20)))
    plain = item()
    deleted_creator = item(craft: ItemCraft.to_map(ItemCraft.signed(30)))

    expect(Repo, :all, fn query ->
      assert %Ecto.Query{} = query
      [{10, "Signer"}, {20, "Forger"}]
    end)

    %{normal: [signed_view, forged_view, plain_view, deleted_view]} =
      InventoryView.inventory_list(%{0 => signed, 1 => forged, 2 => plain, 3 => deleted_creator})

    assert_creator(signed_view, :CREATOR_SIGNED, 10, "Signer")
    assert_creator(forged_view, :CREATOR_FORGED, 20, "Forger")
    assert_creator(plain_view, :CREATOR_NONE, 0, "")
    assert_creator(deleted_view, :CREATOR_SIGNED, 30, "")
  end

  test "projects creator metadata on every single-item update" do
    signed = item(craft: ItemCraft.to_map(ItemCraft.signed(10)))
    stub(Repo, :all, fn _query -> [{10, "Signer"}] end)

    for message <- [
          InventoryView.item_added(signed, 0),
          InventoryView.cart_item_added(signed, 0),
          InventoryView.storage_item_added(signed, 0)
        ] do
      assert_creator(message, :CREATOR_SIGNED, 10, "Signer")
    end
  end

  test "maps every inventory add refusal to its reference result code" do
    assert %{result: :ITEM_ADD_RESULT_INVALID} = InventoryView.item_add_failed(:invalid)
    assert %{result: :ITEM_ADD_RESULT_OVERWEIGHT} = InventoryView.item_add_failed(:overweight)
    assert %{result: :ITEM_ADD_RESULT_OVERITEM} = InventoryView.item_add_failed(:inventory_full)
    assert %{result: :ITEM_ADD_RESULT_OVERAMOUNT} = InventoryView.item_add_failed(:over_amount)
    assert %{result: :ITEM_ADD_RESULT_STACKLIMIT} = InventoryView.item_add_failed(:stack_limit)

    assert InventoryView.item_add_failed(:storage_full) == nil
    assert InventoryView.item_add_failed(:restricted) == nil
    assert InventoryView.item_add_failed(:bound) == nil
    assert InventoryView.item_add_failed(:persistence_failed) == nil
  end

  test "sends the option slots in order, an empty slot as zeros" do
    options = [%{id: 0, value: 9, param: 1}, %{id: 4, value: -3, param: 2}]

    added = InventoryView.item_added(item(random_options: options), 0)

    assert added.options == [
             %ItemOption{id: 0, value: 0, param: 0},
             %ItemOption{id: 4, value: -3, param: 2}
           ]
  end

  test "projects the bound type on the inventory dump" do
    %{normal: [unbound_view, account_view, char_view]} =
      InventoryView.inventory_list(%{0 => item(), 1 => item(bound: 1), 2 => item(bound: 4)})

    assert unbound_view.bound == :BOUND_NONE
    assert account_view.bound == :BOUND_ACCOUNT
    assert char_view.bound == :BOUND_CHAR
  end

  defp item(attrs \\ []) do
    struct(
      InventoryItem,
      Map.merge(%{nameid: 501, amount: 1, identify: 1, random_options: []}, Map.new(attrs))
    )
  end

  defp assert_creator(item, kind, id, name) do
    assert item.creator_kind == kind
    assert item.creator_id == id
    assert item.signer_name == name
  end
end
