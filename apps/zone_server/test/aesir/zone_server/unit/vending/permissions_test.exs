defmodule Aesir.ZoneServer.Unit.Vending.PermissionsTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.Skill.PortalAccess
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Vending.Permissions

  setup :verify_on_exit!
  setup :set_mimic_from_context

  test "a player without authenticated account identity has no transfer authority" do
    assert PortalAccess.trade_permissions(%PlayerState{}) == %{
             level: 0,
             can_trade: false,
             can_trade_bounded: false,
             trade_unconditional: false
           }
  end

  test "transfer authority requires the explicit trade or unconditional flag" do
    definition = %ItemDefinition{id: 501, aegis_name: "Potion", name: "Potion"}
    stub(ItemManagement, :get_item_by_id, fn 501 -> {:ok, definition} end)
    cart = %{0 => %InventoryItem{nameid: 501, amount: 1, identify: 1, bound: 0}}

    for {access, expected} <- [
          {%{}, {:error, :forbidden}},
          {%{level: 99, can_trade: false}, {:error, :forbidden}},
          {%{level: 0, can_trade: true}, :ok},
          {%{level: 0, trade_unconditional: true}, :ok}
        ] do
      assert Permissions.eligibility(cart, access) == %{0 => expected}
    end
  end

  test "bound exceptions do not bypass intrinsic item restrictions" do
    definition = %ItemDefinition{id: 501, aegis_name: "Potion", name: "Potion"}
    stub(ItemManagement, :get_item_by_id, fn 501 -> {:ok, definition} end)
    item = %InventoryItem{nameid: 501, amount: 1, identify: 1, bound: 1}
    ordinary = %{level: 0, can_trade: true}
    bounded = Map.put(ordinary, :can_trade_bounded, true)
    unconditional = %{level: 0, trade_unconditional: true}

    for {instance, access, expected} <- [
          {item, ordinary, {:error, :item_bound}},
          {item, bounded, :ok},
          {item, unconditional, :ok},
          {%{item | identify: 0}, unconditional, {:error, :item_unidentified}},
          {%{item | attribute: 1}, unconditional, {:error, :item_broken}},
          {%{item | expire_time: ~N[2030-01-01 00:00:00]}, unconditional, {:error, :item_rental}}
        ] do
      assert Permissions.eligibility(%{0 => instance}, access) == %{0 => expected}
    end
  end

  test "item restrictions use the imported group-level override, not unconditional authority" do
    definition = %ItemDefinition{
      id: 501,
      aegis_name: "Restricted",
      name: "Restricted",
      no_trade: true,
      trade_override: 55
    }

    stub(ItemManagement, :get_item_by_id, fn
      501 -> {:ok, definition}
      _id -> {:error, :item_not_found}
    end)

    cart = %{0 => %InventoryItem{nameid: 501, amount: 1, identify: 1, bound: 0}}

    for {access, expected} <- [
          {%{level: 54, can_trade: true}, {:error, :item_untradeable}},
          {%{level: 55, can_trade: true}, :ok},
          {%{level: 54, trade_unconditional: true}, {:error, :item_untradeable}}
        ] do
      assert Permissions.eligibility(cart, access) == %{0 => expected}
    end

    unknown = %{0 => %{cart[0] | nameid: 999}}

    assert Permissions.eligibility(unknown, %{level: 99, can_trade: true}) ==
             %{0 => {:error, :item_untradeable}}
  end

  test "genuine socket cards restrict their host but creator and pet markers do not" do
    host = %ItemDefinition{id: 1101, aegis_name: "Sword", name: "Sword", slots: 1}

    card = %ItemDefinition{
      id: 4001,
      aegis_name: "Card",
      name: "Card",
      no_trade: true,
      trade_override: 55
    }

    stub(ItemManagement, :get_item_by_id, fn
      1101 -> {:ok, host}
      4001 -> {:ok, card}
      _id -> {:error, :item_not_found}
    end)

    item = %InventoryItem{nameid: 1101, amount: 1, identify: 1, bound: 0, card0: 4001}
    ordinary = %{level: 54, can_trade: true}
    privileged = %{level: 55, can_trade: true}
    assert Permissions.eligibility(%{0 => item}, ordinary) == %{0 => {:error, :item_untradeable}}
    assert Permissions.eligibility(%{0 => item}, privileged) == %{0 => :ok}

    for marker <- [0xFE, 0xFF, 0x100] do
      signed = %{item | card0: marker, card1: 4001}
      assert Permissions.eligibility(%{0 => signed}, ordinary) == %{0 => :ok}
    end

    outside_socket_count = %{item | card0: 0, card1: 4001}
    assert Permissions.eligibility(%{0 => outside_socket_count}, ordinary) == %{0 => :ok}

    unknown_card = %{item | card0: 4999}

    assert Permissions.eligibility(%{0 => unknown_card}, privileged) ==
             %{0 => {:error, :item_untradeable}}
  end
end
