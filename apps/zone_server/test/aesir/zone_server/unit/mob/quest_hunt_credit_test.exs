defmodule Aesir.ZoneServer.Unit.Mob.QuestHuntCreditTest do
  @moduledoc """
  Exercises hunt-credit fan-out on a mob kill (`quest_update_objective_sub`,
  quest.cpp:729): the solo killer alone with no party, the killer plus every
  party co-member online, on the mob's map, and within `AREA_SIZE` cells of
  the kill -- with no alive filter, so a dead-but-in-range member is still
  credited -- and the exclusion of out-of-range and off-map members.
  """

  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Party.Manager, as: PartyManager
  alias Aesir.ZoneServer.Party.Member
  alias Aesir.ZoneServer.Party.State, as: PartyState
  alias Aesir.ZoneServer.Unit.Mob.QuestHuntCredit
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry
  alias Phoenix.PubSub

  setup :verify_on_exit!
  setup :set_mimic_from_context
  setup :setup_ets_tables

  @mob_id 1002
  @mob_map "prontera"
  @mob_cell {150, 150}

  defp register_player(char_id, opts) do
    state = %{
      character_id: char_id,
      party_id: Keyword.get(opts, :party_id, 0),
      map_name: Keyword.get(opts, :map, @mob_map),
      x: Keyword.get(opts, :x, 150),
      y: Keyword.get(opts, :y, 150),
      stats: %{current_state: %{hp: Keyword.get(opts, :hp, 100)}}
    }

    UnitRegistry.register_unit(:player, char_id, PlayerState, state, self())
  end

  defp party(party_id, char_ids) do
    members =
      Map.new(char_ids, fn id -> {id, Member.new(id, "Char#{id}", 100, true, @mob_map)} end)

    %PartyState{
      party_id: party_id,
      name: "Party",
      leader_char_id: hd(char_ids),
      exp_share: false,
      members: members
    }
  end

  describe "credit/4" do
    test "credits a solo killer with no party" do
      register_player(1, party_id: 0)
      PubSub.subscribe(Aesir.PubSub, "player:1")

      QuestHuntCredit.credit(1, @mob_id, @mob_map, @mob_cell)

      assert_receive {:quest_kill, @mob_id}
    end

    test "takes the fast path without consulting the party for a party_id 0 killer" do
      register_player(1, party_id: 0)
      reject(&PartyManager.get/1)
      PubSub.subscribe(Aesir.PubSub, "player:1")

      QuestHuntCredit.credit(1, @mob_id, @mob_map, @mob_cell)

      assert_receive {:quest_kill, @mob_id}
    end

    test "credits the killer alone when it is no longer in the registry" do
      reject(&PartyManager.get/1)
      PubSub.subscribe(Aesir.PubSub, "player:1")

      QuestHuntCredit.credit(1, @mob_id, @mob_map, @mob_cell)

      assert_receive {:quest_kill, @mob_id}
    end

    test "credits the killer and every party member in range, each exactly once" do
      register_player(1, party_id: 10, x: 150, y: 150)
      register_player(2, party_id: 10, x: 160, y: 155)
      stub(PartyManager, :get, fn 10 -> {:ok, party(10, [1, 2])} end)

      PubSub.subscribe(Aesir.PubSub, "player:1")
      PubSub.subscribe(Aesir.PubSub, "player:2")

      QuestHuntCredit.credit(1, @mob_id, @mob_map, @mob_cell)

      assert_receive {:quest_kill, @mob_id}
      assert_receive {:quest_kill, @mob_id}
      refute_receive {:quest_kill, _mob_id}
    end

    test "excludes an out-of-range party member" do
      register_player(1, party_id: 10, x: 150, y: 150)
      register_player(2, party_id: 10, x: 200, y: 200)
      stub(PartyManager, :get, fn 10 -> {:ok, party(10, [1, 2])} end)

      PubSub.subscribe(Aesir.PubSub, "player:1")
      PubSub.subscribe(Aesir.PubSub, "player:2")

      QuestHuntCredit.credit(1, @mob_id, @mob_map, @mob_cell)

      assert_receive {:quest_kill, @mob_id}
      refute_receive {:quest_kill, _mob_id}
    end

    test "excludes an off-map party member" do
      register_player(1, party_id: 10, x: 150, y: 150)
      register_player(2, party_id: 10, map: "geffen", x: 150, y: 150)
      stub(PartyManager, :get, fn 10 -> {:ok, party(10, [1, 2])} end)

      PubSub.subscribe(Aesir.PubSub, "player:1")
      PubSub.subscribe(Aesir.PubSub, "player:2")

      QuestHuntCredit.credit(1, @mob_id, @mob_map, @mob_cell)

      assert_receive {:quest_kill, @mob_id}
      refute_receive {:quest_kill, _mob_id}
    end

    test "still credits a dead but in-range party member (no alive filter)" do
      register_player(1, party_id: 10, x: 150, y: 150)
      register_player(2, party_id: 10, x: 150, y: 150, hp: 0)
      stub(PartyManager, :get, fn 10 -> {:ok, party(10, [1, 2])} end)

      PubSub.subscribe(Aesir.PubSub, "player:1")
      PubSub.subscribe(Aesir.PubSub, "player:2")

      QuestHuntCredit.credit(1, @mob_id, @mob_map, @mob_cell)

      assert_receive {:quest_kill, @mob_id}
      assert_receive {:quest_kill, @mob_id}
    end
  end
end
