defmodule Aesir.ZoneServer.Unit.Player.Handlers.SkillTextVendingTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Auth
  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Npc.Shops
  alias Aesir.ZoneServer.Npc.Warps
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.Handlers.VendingHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!
  setup :set_mimic_from_context
  setup :setup_ets_tables

  test "a successful shop remembers its first 79 title bytes for later skills" do
    stub(SpatialIndex, :get_unit_position, fn :player, 7_001 -> {:ok, {150, 150, "prontera"}} end)
    stub(Broadcast, :to_in_range, fn _, _, _, _, _, _ -> :ok end)
    stub(Auth, :get_account!, fn 2_000 -> %Account{id: 2_000, group_id: 0} end)
    stub(NpcRegistry, :entries, fn -> [] end)
    stub(Warps, :for_map, fn _ -> :error end)
    stub(Shops, :for_map, fn _ -> :error end)
    StatusStorage.apply_status(:player, 7_001, :sc_push_cart, val1: 1, val2: 1)

    character = %Character{
      id: 7_001,
      account_id: 2_000,
      name: "Merchant",
      last_map: "prontera",
      last_x: 150,
      last_y: 150,
      sex: "M",
      str: 10,
      agi: 10,
      vit: 10,
      int: 10,
      dex: 10,
      luk: 10,
      base_level: 50,
      job_level: 50,
      class: 0,
      hp: 800,
      sp: 300,
      learned_skills: %{"41" => 3}
    }

    player = %{
      PlayerState.new(character)
      | cart: %{0 => %InventoryItem{id: 11, char_id: 7_001, nameid: 501, amount: 10, identify: 1}},
        cart_type: 1
    }

    :ok = UnitRegistry.register_player(player, self())

    state = %SessionState{
      connection_pid: self(),
      game_state: player,
      vending_setup: %{setup_id: "paid-fixture", level: 3, sp_spent: 30},
      work_in_progress: true
    }

    title = String.duplicate("a", 78) <> "é"
    assert {:ok, opened} = VendingHandler.open_shop(state, title, [{0, 5, 100}])
    assert opened.game_state.skill_message == String.duplicate("a", 78) <> <<195>>
  end
end
