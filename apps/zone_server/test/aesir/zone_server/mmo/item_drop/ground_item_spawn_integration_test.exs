defmodule Aesir.ZoneServer.Mmo.ItemDrop.GroundItemSpawnIntegrationTest do
  @moduledoc """
  Walk-up discovery of already-lying ground items at the session level.

  Mirrors the static shop/NPC/warp visibility path: a `GroundItem` sitting in
  `GroundItemStore` on the player's map, within view range, is sent to the
  player as an `ItemOnGround` (`is_falling: false`) when
  `MovementHandler.handle_visibility_update/1` runs, and its id is tracked in
  `visible_items`. Leaving range sends `ItemVanished` and drops the id; staying
  in range does not re-spawn (the MapSet dedupes).

  Drives the real `MovementHandler` + `GroundItemStore`; only the spatial I/O
  collaborators and unit registry are stubbed. `prontera` uses the real map
  cache warmed by `TestEtsSetup`.
  """

  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.Net.ItemOnGround
  alias Aesir.Net.ItemVanished
  alias Aesir.ZoneServer.Mmo.ItemDrop.GroundItem
  alias Aesir.ZoneServer.Mmo.ItemDrop.GroundItemStore
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.Handlers.MovementHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @map "prontera"
  @char_id 4001

  setup :set_mimic_from_context
  setup :setup_ets_tables

  setup do
    stub(SpatialIndex, :get_players_in_range, fn _, _, _, _ -> [] end)
    stub(SpatialIndex, :get_units_in_range, fn _, _, _, _, _ -> [] end)
    stub(SpatialIndex, :update_visibility, fn _, _, _ -> :ok end)
    stub(Broadcast, :to_players, fn _, _, _ -> :ok end)
    :ok
  end

  describe "ground item walk-up discovery" do
    test "a player near a ground item receives an ItemOnGround (not falling)" do
      item = ground_item(150, 150)
      GroundItemStore.put(@map, item)
      ground_id = item.id

      game_state = %{PlayerState.new(character()) | x: 150, y: 150}
      register_player(game_state)

      new_state = MovementHandler.handle_visibility_update(game_state)

      assert_received {:"$gen_cast",
                       {:send_packet,
                        %ItemOnGround{
                          ground_id: ^ground_id,
                          nameid: 501,
                          amount: 1,
                          x: 150,
                          y: 150,
                          is_falling: false
                        }}}

      assert MapSet.member?(new_state.visible_items, ground_id)
    end

    test "a ground item outside view range is not sent" do
      item = ground_item(150, 150)
      GroundItemStore.put(@map, item)

      game_state = %{PlayerState.new(character()) | x: 10, y: 10}
      register_player(game_state)

      new_state = MovementHandler.handle_visibility_update(game_state)

      refute_received {:"$gen_cast", {:send_packet, %ItemOnGround{}}}
      assert MapSet.size(new_state.visible_items) == 0
    end

    test "leaving range sends an ItemVanished and drops the id" do
      item = ground_item(150, 150)
      GroundItemStore.put(@map, item)
      ground_id = item.id

      game_state =
        %{PlayerState.new(character()) | x: 10, y: 10, visible_items: MapSet.new([ground_id])}

      register_player(game_state)

      new_state = MovementHandler.handle_visibility_update(game_state)

      assert_received {:"$gen_cast", {:send_packet, %ItemVanished{ground_id: ^ground_id}}}
      refute MapSet.member?(new_state.visible_items, ground_id)
    end

    test "staying in range does not re-spawn an already-visible item" do
      item = ground_item(150, 150)
      GroundItemStore.put(@map, item)
      ground_id = item.id

      game_state =
        %{PlayerState.new(character()) | x: 150, y: 150, visible_items: MapSet.new([ground_id])}

      register_player(game_state)

      new_state = MovementHandler.handle_visibility_update(game_state)

      refute_received {:"$gen_cast", {:send_packet, %ItemOnGround{ground_id: ^ground_id}}}
      assert MapSet.member?(new_state.visible_items, ground_id)
    end
  end

  defp ground_item(x, y), do: GroundItem.new(501, 1, x, y, true)

  defp character do
    %Character{
      id: @char_id,
      account_id: 400,
      name: "Looter",
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
