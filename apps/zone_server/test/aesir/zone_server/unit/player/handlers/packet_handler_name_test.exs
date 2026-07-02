defmodule Aesir.ZoneServer.Unit.Player.Handlers.PacketHandlerNameTest do
  @moduledoc """
  Verifies the QUIC + protobuf inbound dispatch for the entity-name slice
  collapses the legacy `ZC_ACK_REQNAME` (mob) and `ZC_ACK_REQNAMEALL` (player)
  replies into a single `NameResponse` on the World channel, preserving the
  legacy `CZ_REQNAME2` entity-type resolution.
  """

  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Net.NameRequest
  alias Aesir.Net.NameResponse
  alias Aesir.ZoneServer.Party.Manager, as: PartyManager
  alias Aesir.ZoneServer.Party.State, as: PartyState
  alias Aesir.ZoneServer.Unit.Player.Handlers.PacketHandler
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  @account_id 1
  @character_id 11
  @char_name "TestChar"

  defp state(opts) do
    %{
      connection_pid: self(),
      game_state: %{
        account_id: @account_id,
        character_id: @character_id,
        character_name: @char_name,
        party_id: Keyword.get(opts, :party_id, 0),
        visible_players: Keyword.get(opts, :visible_players, MapSet.new()),
        visible_mobs: Keyword.get(opts, :visible_mobs, MapSet.new())
      }
    }
  end

  test "self request replies with the player's own name and empty party/guild/position" do
    s = state([])

    {:noreply, ^s} = PacketHandler.handle_message(%NameRequest{entity_id: @character_id}, s)

    assert_receive {:send, :world,
                    {:name_response,
                     %NameResponse{
                       gid: @character_id,
                       name: @char_name,
                       party_name: "",
                       guild_name: "",
                       position_name: ""
                     }}}
  end

  test "self request replies with the party name when in a party" do
    s = state(party_id: 5)

    expect(PartyManager, :get, fn 5 ->
      {:ok, %PartyState{party_id: 5, name: "Vanguard", leader_char_id: 1, exp_share: false}}
    end)

    {:noreply, ^s} = PacketHandler.handle_message(%NameRequest{entity_id: @character_id}, s)

    assert_receive {:send, :world,
                    {:name_response, %NameResponse{gid: @character_id, party_name: "Vanguard"}}}
  end

  test "visible player request replies with the player's name (party/guild empty)" do
    other_id = 42
    s = state(visible_players: MapSet.new([other_id]))
    other_player_state = %{character_name: "OtherPlayer", party_id: 0}

    expect(UnitRegistry, :get_unit, fn :player, ^other_id ->
      {:ok, {SomeMod, other_player_state, self()}}
    end)

    {:noreply, ^s} = PacketHandler.handle_message(%NameRequest{entity_id: other_id}, s)

    assert_receive {:send, :world,
                    {:name_response,
                     %NameResponse{
                       gid: ^other_id,
                       name: "OtherPlayer",
                       party_name: "",
                       guild_name: "",
                       position_name: ""
                     }}}
  end

  test "visible player request replies with the party name when the player is in a party" do
    other_id = 42
    s = state(visible_players: MapSet.new([other_id]))
    other_player_state = %{character_name: "OtherPlayer", party_id: 7}

    expect(UnitRegistry, :get_unit, fn :player, ^other_id ->
      {:ok, {SomeMod, other_player_state, self()}}
    end)

    expect(PartyManager, :get, fn 7 ->
      {:ok, %PartyState{party_id: 7, name: "Vanguard", leader_char_id: 1, exp_share: false}}
    end)

    {:noreply, ^s} = PacketHandler.handle_message(%NameRequest{entity_id: other_id}, s)

    assert_receive {:send, :world,
                    {:name_response,
                     %NameResponse{gid: ^other_id, name: "OtherPlayer", party_name: "Vanguard"}}}
  end

  test "visible mob request replies with the mob name only" do
    mob_id = 2_001
    s = state(visible_mobs: MapSet.new([mob_id]))

    mob_state = %{mob_data: %{name: "Poring"}}

    expect(UnitRegistry, :get_unit, fn :mob, ^mob_id -> {:ok, {SomeMod, mob_state, self()}} end)

    {:noreply, ^s} = PacketHandler.handle_message(%NameRequest{entity_id: mob_id}, s)

    assert_receive {:send, :world,
                    {:name_response,
                     %NameResponse{
                       gid: ^mob_id,
                       name: "Poring",
                       party_name: "",
                       guild_name: "",
                       position_name: ""
                     }}}
  end

  @tag :capture_log
  test "ignores a request for an entity not in view range" do
    s = state([])

    {:noreply, ^s} = PacketHandler.handle_message(%NameRequest{entity_id: 9_999}, s)

    refute_receive {:send, _channel, _payload}
  end
end
