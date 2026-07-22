defmodule Aesir.ZoneServer.Unit.Player.PlayerSessionVendingTest do
  @moduledoc """
  Exercises the vending wiring on `PlayerSession` directly: the on-view-enter
  shop board, the seller-authority `{:vending, {:vending_purchase, ...}}` call, and the
  `terminate/2` shop teardown. The two-player end-to-end flow lives in the
  integration suite (Task 8).
  """

  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.Net.VendingBoardShown
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.Handlers.VendingHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.WarpHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.StatusPersistence
  alias Aesir.ZoneServer.Unit.UnitRegistry
  alias Aesir.ZoneServer.Unit.Vending.Registry, as: VendingRegistry

  setup :verify_on_exit!
  setup :set_mimic_from_context
  setup :setup_ets_tables

  defp character(id, name) do
    %Character{
      id: id,
      account_id: id * 100,
      name: name,
      last_map: "prontera",
      last_x: 150,
      last_y: 150,
      class: 0,
      base_level: 50,
      job_level: 50,
      sex: "M",
      str: 10,
      agi: 10,
      vit: 10,
      int: 10,
      dex: 10,
      luk: 10
    }
  end

  defp shop(title) do
    %{title: title, owner_char_id: 2, items: []}
  end

  describe "player_entered_view shop board" do
    test "sends VendingBoardShown when the entering unit has an open shop" do
      vendor = %{PlayerState.new(character(2, "Merchy")) | movement_state: :standing}

      vendor_pid = spawn(fn -> Process.sleep(1000) end)
      UnitRegistry.register_player(vendor, vendor_pid)
      VendingRegistry.put(2, vendor_pid, shop("Cheap Pots"))

      state = %{
        game_state: PlayerState.new(character(1, "Buyer")),
        connection_pid: self()
      }

      {:noreply, _state} =
        PlayerSession.handle_cast({:visibility, {:player_entered_view, 2}}, state)

      assert_received {:send, :world,
                       {:vending_board_shown, %VendingBoardShown{unit_id: 2, title: "Cheap Pots"}}}

      Process.exit(vendor_pid, :kill)
    end

    test "sends no board when the entering unit has no shop" do
      vendor = %{PlayerState.new(character(2, "Plain")) | movement_state: :standing}

      vendor_pid = spawn(fn -> Process.sleep(1000) end)
      UnitRegistry.register_player(vendor, vendor_pid)

      state = %{
        game_state: PlayerState.new(character(1, "Buyer")),
        connection_pid: self()
      }

      {:noreply, _state} =
        PlayerSession.handle_cast({:visibility, {:player_entered_view, 2}}, state)

      refute_received {:send, :world, {:vending_board_shown, _}}

      Process.exit(vendor_pid, :kill)
    end
  end

  describe "vending_purchase_request self-purchase guard" do
    test "a request to buy from one's own shop is a safe no-op" do
      buyer = PlayerState.new(character(1, "Merchy"))
      state = %{game_state: buyer, connection_pid: self()}

      assert {:noreply, ^state} =
               VendingHandler.handle_purchase_request(state, 1, [{0, 1}])

      refute_received {:send, _ch, _body}
    end
  end

  describe "terminate/2" do
    setup do
      Mimic.copy(CharacterPersistence)
      Mimic.copy(WarpHandler)
      Mimic.copy(StatusPersistence)

      stub(CharacterPersistence, :update_position, fn _id, _x, _y, _map -> {:ok, %Character{}} end)

      stub(WarpHandler, :leave_current_map, fn _gs, _reason -> :ok end)

      stub(StatusPersistence, :save_statuses, fn _char_id -> :ok end)

      test_pid = self()

      stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, packet, _opts ->
        send(test_pid, {:board, packet})
        :ok
      end)

      :ok
    end

    test "closes an open vending shop so the registry entry does not leak" do
      vending_gs = %{
        PlayerState.new(character(2, "Merchy"))
        | action_state: :vending,
          state_context: shop("Cheap Pots")
      }

      VendingRegistry.put(2, self(), shop("Cheap Pots"))

      state = %{
        game_state: vending_gs,
        connection_pid: self(),
        connection_monitor_ref: make_ref()
      }

      assert :ok = PlayerSession.terminate(:normal, state)
      assert :error = VendingRegistry.get(2)
    end

    test "is a no-op for a non-vending session" do
      state = %{
        game_state: PlayerState.new(character(3, "Idle")),
        connection_pid: self(),
        connection_monitor_ref: make_ref()
      }

      assert :ok = PlayerSession.terminate(:normal, state)
      refute_received {:board, _}
    end
  end
end
