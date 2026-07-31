defmodule Aesir.ZoneServer.Mmo.Skills.Merchant.McIdentifyTest do
  use ExUnit.Case, async: true

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Merchant.McIdentify
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  test "offers unidentified inventory slot indexes" do
    state = caster(%{2 => item(501, 1), 7 => item(1101, 0), 9 => item(1101, 0)})

    assert {:ok, offered} = McIdentify.cast(state, :self, 1, definition())

    assert offered.pending_menu_offer == %{
             skill_id: 40,
             kind: :INVENTORY_SLOTS,
             entry_ids: [7, 9],
             level: 1
           }
  end

  test "rejects a cast with no unidentified items" do
    assert {:error, :no_unidentified_items} =
             McIdentify.cast(caster(%{0 => item(1101, 1)}), :self, 1, definition())
  end

  test "identifies only the selected row when item ids match" do
    state = caster(%{3 => item(1101, 0), 8 => item(1101, 0)})

    assert {:ok, identified} =
             McIdentify.on_menu_reply(state, %{id: 8, extras: []}, 1)

    assert identified.inventory[3].identify == 0
    assert identified.inventory[8].identify == 1
    assert [{old, new, {:identified, 8}}] = identified.pending_inventory_persist
    assert old[8].identify == 0
    assert new[8].identify == 1
  end

  defp definition do
    {:ok, definition} = Catalog.by_id(40)
    definition
  end

  defp caster(inventory) do
    %PlayerState{character_id: 1, inventory: inventory, pending_inventory_persist: []}
  end

  defp item(nameid, identify) do
    %InventoryItem{nameid: nameid, amount: 1, identify: identify, equip: 0}
  end
end
