defmodule Aesir.ZoneServer.Npc.ShopSpawnIntegrationTest do
  @moduledoc """
  End-to-end static shop visibility at the session level (no real client).

  Mirrors the warp/NPC visibility path: a loaded `Npc.Shops` placement on the
  player's map, within view range, is sent to the player as a `UnitSpawn` with
  `object_type` npc when `MovementHandler.handle_visibility_update/1` runs. The
  returned state tracks the shop's synthetic entity id in `visible_shops`,
  leaving range sends a `UnitDespawn`, and re-running while still in range does
  not re-spawn (the MapSet dedupes).

  Drives the real `MovementHandler` + `Shop.Registry`; only the I/O collaborators
  (spatial index bookkeeping, unit registry lookups) and the shop data source
  (`Shops.for_map/1`) are stubbed. `prontera` uses the real map cache warmed by
  `TestEtsSetup`.
  """

  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.Net.UnitDespawn
  alias Aesir.Net.UnitSpawn
  alias Aesir.ZoneServer.Constants.ObjectType
  alias Aesir.ZoneServer.Npc.Shop
  alias Aesir.ZoneServer.Npc.Shops
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.Handlers.MovementHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @map "prontera"
  @char_id 3001

  setup :set_mimic_from_context
  setup :setup_ets_tables

  setup do
    Mimic.copy(Shops)
    stub(Shops, :for_map, fn _ -> :error end)

    stub(SpatialIndex, :get_players_in_range, fn _, _, _, _ -> [] end)
    stub(SpatialIndex, :get_units_in_range, fn _, _, _, _, _ -> [] end)
    stub(SpatialIndex, :update_visibility, fn _, _, _ -> :ok end)
    stub(Broadcast, :to_players, fn _, _, _ -> :ok end)

    {:ok, %{shop: shop()}}
  end

  describe "static shop visibility on map entry" do
    test "a player near a loaded shop receives a UnitSpawn for it (object type npc)", %{
      shop: shop
    } do
      gid = Shop.Registry.entity_id(shop)
      stub(Shops, :for_map, fn @map -> {:ok, [shop]} end)

      game_state = %{PlayerState.new(character()) | x: 150, y: 150}
      register_player(game_state)

      new_state = MovementHandler.handle_visibility_update(game_state)

      assert_received {:"$gen_cast",
                       {:send_packet,
                        %UnitSpawn{
                          object_type: object_type,
                          gid: ^gid,
                          x: 152,
                          y: 151,
                          job: 85,
                          name: "Tool Dealer"
                        }}}

      assert object_type == ObjectType.npc()
      assert MapSet.member?(new_state.visible_shops, gid)
    end

    test "a shop outside view range is not sent" do
      game_state = %{PlayerState.new(character()) | x: 10, y: 10}
      register_player(game_state)

      new_state = MovementHandler.handle_visibility_update(game_state)

      refute_received {:"$gen_cast", {:send_packet, %UnitSpawn{job: 85}}}
      assert MapSet.size(new_state.visible_shops) == 0
    end

    test "leaving range sends a UnitDespawn for the shop gid", %{shop: shop} do
      gid = Shop.Registry.entity_id(shop)
      stub(Shops, :for_map, fn @map -> {:ok, [shop]} end)

      game_state =
        %{PlayerState.new(character()) | x: 10, y: 10, visible_shops: MapSet.new([gid])}

      register_player(game_state)

      new_state = MovementHandler.handle_visibility_update(game_state)

      assert_received {:"$gen_cast", {:send_packet, %UnitDespawn{gid: ^gid}}}
      refute MapSet.member?(new_state.visible_shops, gid)
    end

    test "staying in range does not re-spawn an already-visible shop", %{shop: shop} do
      gid = Shop.Registry.entity_id(shop)
      stub(Shops, :for_map, fn @map -> {:ok, [shop]} end)

      game_state =
        %{PlayerState.new(character()) | x: 150, y: 150, visible_shops: MapSet.new([gid])}

      register_player(game_state)

      new_state = MovementHandler.handle_visibility_update(game_state)

      refute_received {:"$gen_cast", {:send_packet, %UnitSpawn{gid: ^gid}}}
      assert MapSet.member?(new_state.visible_shops, gid)
    end
  end

  defp shop do
    %Shop{
      id: "prontera_tool_dealer",
      map: @map,
      x: 152,
      y: 151,
      dir: 4,
      sprite: 85,
      name: "Tool Dealer",
      items: [%{nameid: 501, price: 50}]
    }
  end

  defp character do
    %Character{
      id: @char_id,
      account_id: 300,
      name: "Shopper",
      last_map: @map,
      last_x: 150,
      last_y: 150,
      sex: "M",
      hair: 1,
      hair_color: 0,
      clothes_color: 0,
      head_mid: 0,
      head_bottom: 0,
      robe: 0,
      str: 1,
      agi: 1,
      vit: 1,
      int: 1,
      dex: 1,
      luk: 1,
      base_level: 1,
      job_level: 1,
      class: 0
    }
  end

  defp register_player(game_state) do
    UnitRegistry.register_unit(:player, @char_id, PlayerState, game_state, self())
  end
end
