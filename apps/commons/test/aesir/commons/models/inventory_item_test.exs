defmodule Aesir.Commons.Models.InventoryItemTest do
  use ExUnit.Case, async: true

  alias Aesir.Commons.Models.InventoryItem

  describe "changeset/2" do
    test "casts craft metadata" do
      craft = %{"kind" => "signed", "creator_char_id" => 1}

      changeset =
        InventoryItem.changeset(%InventoryItem{}, %{
          char_id: 1,
          nameid: 501,
          amount: 1,
          craft: craft
        })

      assert changeset.changes.craft == craft
    end

    test "leaves craft absent by default" do
      changeset = InventoryItem.changeset(%InventoryItem{}, %{char_id: 1, nameid: 501, amount: 1})

      refute Map.has_key?(changeset.changes, :craft)
      assert changeset.data.craft == nil
    end
  end
end
