defmodule Aesir.ZoneServer.Unit.Trade.OfferTest do
  use ExUnit.Case, async: true

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Unit.Trade.Offer

  test "adds an item to an offer in insertion order" do
    assert {:ok, offer} = Offer.new() |> Offer.add(item(1), 2)
    assert {:ok, offer} = Offer.add(offer, item(2), 3)

    assert offer.zeny == 0
    assert Enum.map(offer.entries, & &1.row_id) == [1, 2]
    assert Enum.map(offer.entries, & &1.amount) == [2, 3]
    assert Enum.map(offer.entries, & &1.snapshot.id) == [1, 2]
  end

  test "rejects an eleventh distinct item" do
    offer =
      Enum.reduce(1..10, Offer.new(), fn id, offer ->
        {:ok, offer} = Offer.add(offer, item(id), 1)
        offer
      end)

    assert Offer.add(offer, item(11), 1) == {:error, :offer_full}
    assert Offer.add(offer, item(10), 1) == {:error, :duplicate_item}
  end

  test "rejects zero and negative item amounts" do
    for amount <- [0, -1] do
      assert Offer.add(Offer.new(), item(1), amount) == {:error, :invalid_amount}
    end
  end

  test "removes an offered item" do
    assert {:ok, offer} = Offer.new() |> Offer.add(item(1), 1)
    assert {:ok, offer} = Offer.add(offer, item(2), 1)

    assert {:ok, %{entries: [%{row_id: 2}]}} = Offer.remove(offer, 1)
  end

  test "rejects removal of an absent item" do
    assert Offer.remove(Offer.new(), 1) == {:error, :not_found}
  end

  test "replaces the offered zeny" do
    assert {:ok, offer} = Offer.new() |> Offer.set_zeny(10)
    assert {:ok, %{zeny: 20}} = Offer.set_zeny(offer, 20)
  end

  test "rejects negative zeny" do
    assert Offer.set_zeny(Offer.new(), -1) == {:error, :invalid_amount}
  end

  test "rejects an item already in the offer" do
    assert {:ok, offer} = Offer.new() |> Offer.add(item(1), 1)
    assert Offer.add(offer, item(1), 2) == {:error, :duplicate_item}
  end

  defp item(id), do: %InventoryItem{id: id}
end
