defmodule Aesir.ZoneServer.Unit.Player.InventoryViewTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Commons.Models.InventoryItem
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

  defp item(attrs \\ []) do
    struct(
      InventoryItem,
      Map.merge(%{nameid: 501, amount: 1, identify: 1, random_options: %{}}, Map.new(attrs))
    )
  end

  defp assert_creator(item, kind, id, name) do
    assert item.creator_kind == kind
    assert item.creator_id == id
    assert item.signer_name == name
  end
end
