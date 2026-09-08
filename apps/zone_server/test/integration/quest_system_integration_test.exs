defmodule Aesir.ZoneServer.Integration.QuestSystemIntegrationTest do
  @moduledoc """
  End-to-end acceptance of the quest system, driving the real subsystems through
  a shared test NPC and quest definitions that exist in both active corpora.

  The loop, all through production code paths:

  1. Accept hunting quest `1100` through an NPC dialog and real
     `Script.Interaction`, routing `{:npc, {:script_apply, op}}` to a real
     `PlayerSession` and asserting the `QuestAdded` push.
  2. Hunt: `{:quest_kill, 1178}` ticks the session's `QuestLog`, pushing one
     `QuestHuntProgress` per moved objective and clamping at the target of 20.
  3. A partied kill through the real `QuestHuntCredit.credit/4` fan-out credits a
     nearby party member's own session.
  4. Turn in: gated on `checkquest(1100, HUNTING) == 2`, the NPC `changequest`s
     `1100 -> 2290` (asserting `QuestRemoved` + `QuestAdded`) and grants `getexp`.
  5. Relog: `QuestPersistence.load_on_spawn/1` restores the cooldown quest and the
     map-load flow re-sends it in the `QuestList` dump.

  Persistence runs inline (`IntegrationCase`), and the `character_quests` FK to
  `characters` is why every quest-holding player is a real inserted row.
  """

  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.StatusParams
  alias Aesir.Net.MapLoaded
  alias Aesir.Net.NpcDialog
  alias Aesir.Net.NpcInteract
  alias Aesir.Net.ParamChange
  alias Aesir.Net.QuestAdded
  alias Aesir.Net.QuestEntry
  alias Aesir.Net.QuestHuntProgress
  alias Aesir.Net.QuestList
  alias Aesir.Net.QuestRemoved
  alias Aesir.Repo
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Party.Manager, as: PartyManager
  alias Aesir.ZoneServer.Party.Member
  alias Aesir.ZoneServer.Party.State, as: PartyState
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Interaction
  alias Aesir.ZoneServer.Unit.Mob.QuestHuntCredit
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.QuestLog.Entry
  alias Aesir.ZoneServer.Unit.Player.QuestPersistence
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @hunt_mob 1178
  @hunt_quest 1100
  @cooldown_quest 2290
  @target 20

  defmodule QuestFixtureNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 150, y: 150, sprite: 547, name: "Quest Fixture"}]

    @hunt_quest 1100
    @cooldown_quest 2290

    @impl true
    def on_talk(ctx) do
      case checkquest(ctx, @hunt_quest, :hunting) do
        -1 ->
          ctx |> mes("Hunt twenty monsters.") |> next() |> setquest(@hunt_quest) |> close()

        2 ->
          ctx |> changequest(@hunt_quest, @cooldown_quest) |> getexp(300_000, 100_000) |> close()

        _ ->
          close(ctx)
      end
    end
  end

  setup {Aesir.MimicMode, :global}

  setup do
    gid = NpcRegistry.entity_id(hd(QuestFixtureNpc.spawn()))
    {:ok, gid: gid}
  end

  describe "hunting-quest acceptance loop" do
    test "accept, hunt to the cap, turn in, and survive a relog", %{gid: gid} do
      char = insert_character("Quester")
      player = start_player_session(character: char, position: {150, 150}, map_name: "prontera")
      flush_packets()

      # 1. Accept quest 1100 through the NPC dialog.
      {:ok, ipid} = start_talk(player, gid)
      continue(ipid, gid)

      assert_receive {:packet_sent, %QuestAdded{quest: %QuestEntry{quest_id: @hunt_quest}}, _},
                     500

      await_interaction_end(ipid)

      assert %Entry{state: :active, counts: [0]} =
               get_player_state(player.pid).quest_log[@hunt_quest]

      # 2. Hunt: exact-mob kill ticks push progress and clamp at the target.
      flush_packets()

      Enum.each(1..(@target + 2), fn _ -> send(player.pid, {:loot, {:quest_kill, @hunt_mob}}) end)

      # get_state is a serialized GenServer.call, so it only returns once every
      # queued {:quest_kill} handle_info has run -- a barrier, no sleep needed.
      hunted = get_player_state(player.pid)
      assert hunted.quest_log[@hunt_quest].counts == [@target]

      progress = collect_packets_of_type(QuestHuntProgress)
      assert length(progress) == @target
      assert List.last(progress).count == @target
      assert Enum.all?(progress, &(&1.needed == @target))
      assert Enum.map(progress, & &1.count) == Enum.to_list(1..@target)

      # 3. Turn in, gated on checkquest(1100, HUNTING) == 2.
      level_before = get_player_state(player.pid).stats.progression.base_level
      base_exp_id = StatusParams.base_exp()
      flush_packets()

      {:ok, ipid2} = start_talk(player, gid)

      assert_receive {:packet_sent, %QuestRemoved{quest_id: @hunt_quest}, _}, 500

      assert_receive {:packet_sent, %QuestAdded{quest: %QuestEntry{quest_id: @cooldown_quest}},
                      _},
                     500

      # getexp fired: a base-exp ParamChange lands and the level rose.
      assert_receive {:packet_sent, %ParamChange{var_id: ^base_exp_id}, _}, 500
      await_interaction_end(ipid2)

      turned_in = get_player_state(player.pid)
      refute Map.has_key?(turned_in.quest_log, @hunt_quest)
      assert %Entry{state: :active} = turned_in.quest_log[@cooldown_quest]
      assert turned_in.stats.progression.base_level > level_before

      # 4. Relog: the cooldown quest is restored from character_quests.
      end_player_session(player)

      loaded =
        QuestPersistence.load_on_spawn(%{
          game_state: %{character_id: char.id, quest_log: %{}}
        })

      assert %Entry{state: :active} = loaded.game_state.quest_log[@cooldown_quest]
      refute Map.has_key?(loaded.game_state.quest_log, @hunt_quest)

      # ...and the map-load flow re-sends it in the full QuestList dump.
      relog = start_player_session(character: char, position: {150, 150}, map_name: "prontera")
      assert %Entry{state: :active} = get_player_state(relog.pid).quest_log[@cooldown_quest]

      flush_packets()
      simulate_incoming_message(relog.pid, %MapLoaded{})
      list = assert_packet_sent(QuestList)
      assert Enum.any?(list.quests, &(&1.quest_id == @cooldown_quest and &1.state == 1))
    end
  end

  describe "party hunt credit" do
    test "a party kill credits a nearby member's own hunting quest" do
      member_char = insert_character("Member")

      member =
        start_player_session(character: member_char, position: {150, 150}, map_name: "prontera")

      {:ok, _gs} = PlayerSession.script_apply(member.pid, {:setquest, @hunt_quest})

      killer_id = 990_001

      UnitRegistry.register_unit(
        :player,
        killer_id,
        PlayerState,
        %{party_id: 42, map_name: "prontera", x: 150, y: 150},
        self()
      )

      stub(PartyManager, :get, fn 42 ->
        members =
          Map.new([killer_id, member_char.id], fn id ->
            {id, Member.new(id, "Char#{id}", 100, true, "prontera")}
          end)

        {:ok,
         %PartyState{
           party_id: 42,
           name: "Party",
           leader_char_id: killer_id,
           exp_share: false,
           item_pickup_share: false,
           members: members
         }}
      end)

      flush_packets()

      QuestHuntCredit.credit(killer_id, @hunt_mob, "prontera", {150, 150})

      assert_receive {:packet_sent,
                      %QuestHuntProgress{quest_id: @hunt_quest, count: 1, needed: @target}, _},
                     500

      assert get_player_state(member.pid).quest_log[@hunt_quest].counts == [1]
    end
  end

  defp insert_character(name) do
    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        userid: "quest_#{System.unique_integer([:positive])}",
        user_pass: "password",
        sex: "M",
        email: "#{name}#{System.unique_integer([:positive])}@example.com"
      })
      |> Repo.insert()

    {:ok, character} =
      %{
        account_id: account.id,
        char_num: 0,
        name: "#{name}#{System.unique_integer([:positive])}",
        class: 0,
        base_level: 1,
        job_level: 1,
        last_map: "prontera",
        last_x: 150,
        last_y: 150,
        save_map: "prontera",
        save_x: 150,
        save_y: 150
      }
      |> Character.new()
      |> Repo.insert()

    character
  end

  defp start_talk(player, gid) do
    session_state = PlayerSession.get_state(player.pid)

    ctx = %Ctx{
      char_id: player.character.id,
      account_id: player.character.account_id,
      connection_pid: session_state.connection_pid,
      game_state: session_state.game_state,
      source: {:npc, QuestFixtureNpc.npc_id()},
      npc_gid: gid
    }

    Interaction.start(player.pid, QuestFixtureNpc, ctx)
  end

  defp continue(pid, gid) do
    assert_receive {:packet_sent, %NpcDialog{expect: :NEXT}, _}, 500
    send(pid, {:npc_interact, %NpcInteract{npc_id: gid, response: {:continue, true}}})
  end

  defp await_interaction_end(pid) do
    ref = Process.monitor(pid)
    assert_receive {:DOWN, ^ref, :process, ^pid, _reason}, 500
  end
end
