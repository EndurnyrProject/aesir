defmodule Aesir.ZoneServer.Unit.Player.Handlers.RentalExpiryTest do
  use ExUnit.Case, async: false
  use Mimic

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.ItemRemoved
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Unit.Player.Handlers.EquipmentHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.Handlers.RentalExpiry
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @now ~N[2026-08-10 12:00:00]

  setup :set_mimic_private
  setup :verify_on_exit!

  setup do
    Mimic.copy(EquipmentHandler)
    Mimic.copy(InventoryOps)
    Mimic.copy(MessageRouter)
    Mimic.copy(UnitRegistry)

    test_pid = self()

    stub(MessageRouter, :send_to, fn _connection_pid, packet ->
      send(test_pid, {:item_removed, packet})
      :ok
    end)

    stub(UnitRegistry, :update_unit_state, fn :player, 1000, _game_state -> :ok end)
    :ok
  end

  test "removes unworn expired rentals and leaves live rentals untouched" do
    expired = item(1, expire_time: ~N[2026-08-10 11:59:59])
    live = item(2, expire_time: ~N[2026-08-10 12:00:01])
    inventory = %{0 => expired, 1 => live}
    state = state(inventory)

    reject(&EquipmentHandler.handle_unequip/2)

    expect(InventoryOps, :remove, fn 1000, ^inventory, 0, 1 ->
      {:ok, %{1 => live}, {:removed, 0}}
    end)

    new_state = RentalExpiry.sweep(state, @now)

    assert new_state.game_state.inventory == %{1 => live}
    assert_receive {:item_removed, %ItemRemoved{index: 2, amount: 1}}
  end

  test "unequips worn expired rentals before removing them" do
    expired = item(1, equip: 2, expire_time: ~N[2026-08-10 11:59:59])
    recalculated_stats = %{recomputed: true}
    state = state(%{0 => expired})

    expect(EquipmentHandler, :handle_unequip, fn 0, unequip_state ->
      send(self(), :unequipped)

      unequipped = %{expired | equip: 0}

      game_state = %{
        unequip_state.game_state
        | inventory: %{0 => unequipped},
          stats: recalculated_stats
      }

      {:noreply, %{unequip_state | game_state: game_state}}
    end)

    expect(InventoryOps, :remove, fn 1000, %{0 => %InventoryItem{equip: 0}}, 0, 1 ->
      send(self(), :removed)
      {:ok, %{}, {:removed, 0}}
    end)

    new_state = RentalExpiry.sweep(state, @now)

    assert_receive :unequipped
    assert_receive :removed
    assert new_state.game_state.inventory == %{}
    assert new_state.game_state.stats == recalculated_stats
    assert_receive {:item_removed, %ItemRemoved{index: 2, amount: 1}}
  end

  test "is a no-op when no rentals have expired" do
    live = item(1, expire_time: ~N[2026-08-10 12:00:01])
    state = state(%{0 => live})

    reject(&EquipmentHandler.handle_unequip/2)
    reject(&InventoryOps.remove/4)
    reject(&UnitRegistry.update_unit_state/3)

    assert RentalExpiry.sweep(state, @now) == state
    refute_receive {:item_removed, _}
  end

  defp state(inventory) do
    game_state = %PlayerState{character_id: 1000, party_id: 0, guild_id: 0, inventory: inventory}
    %{connection_pid: self(), game_state: game_state}
  end

  defp item(nameid, opts) do
    %InventoryItem{
      nameid: nameid,
      amount: 1,
      equip: Keyword.get(opts, :equip, 0),
      expire_time: Keyword.fetch!(opts, :expire_time)
    }
  end
end
