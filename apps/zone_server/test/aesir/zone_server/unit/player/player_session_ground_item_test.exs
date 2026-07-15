defmodule Aesir.ZoneServer.Unit.Player.PlayerSessionGroundItemTest do
  @moduledoc """
  A Coordinator-broadcast `ItemVanished` arrives at the session as a
  `{:send_packet, ...}` cast. The session forwards it to the client and drops
  the id from `visible_items`, so re-entering the item's range later re-spawns
  it.
  """

  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.Net.ItemVanished
  alias Aesir.Net.SkillUnitDespawn
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables

  defp character do
    %Character{
      id: 1,
      account_id: 100,
      name: "Looter",
      last_map: "prontera",
      last_x: 150,
      last_y: 150,
      class: 0,
      base_level: 1,
      job_level: 1,
      sex: "M",
      str: 1,
      agi: 1,
      vit: 1,
      int: 1,
      dex: 1,
      luk: 1
    }
  end

  test "forwarding an ItemVanished removes the ground id from visible_items" do
    game_state = %{PlayerState.new(character()) | visible_items: MapSet.new([7, 9])}
    state = %{game_state: game_state, connection_pid: self()}

    packet = %ItemVanished{ground_id: 7, reason: :PICKED_UP}

    {:noreply, new_state} = PlayerSession.handle_cast({:send_packet, packet}, state)

    refute MapSet.member?(new_state.game_state.visible_items, 7)
    assert MapSet.member?(new_state.game_state.visible_items, 9)
    assert_received {:send, _channel, {_tag, ^packet}}
  end

  test "forwarding a removed skill-unit group drops its visible group id" do
    game_state = %{PlayerState.new(character()) | visible_skill_units: MapSet.new([7, 9])}
    state = %{game_state: game_state, connection_pid: self()}

    packet = %SkillUnitDespawn{
      group_id: 7,
      cell_ids: [101],
      reason: :SKILL_UNIT_DESPAWN_REASON_EXPIRED
    }

    assert :ok = UnitRegistry.register_player(game_state, self())
    {:noreply, new_state} = PlayerSession.handle_cast({:send_packet, packet}, state)

    refute MapSet.member?(new_state.game_state.visible_skill_units, 7)
    assert MapSet.member?(new_state.game_state.visible_skill_units, 9)

    assert {:ok, {_module, registered_state, _pid}} = UnitRegistry.get_unit(:player, 1)
    refute MapSet.member?(registered_state.visible_skill_units, 7)
    assert_received {:send, _channel, {_tag, ^packet}}
  end
end
