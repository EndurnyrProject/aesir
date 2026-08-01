defmodule Aesir.ZoneServer.Integration.HunterTalkieboxIntegrationTest do
  @moduledoc """
  Real-PlayerSession coverage for HT_TALKIEBOX: the staged text-input lifecycle,
  non-owner movement activation ordering, timed cleanup, and every rejected path
  (capability, preflight, cancel, timeout, forged/stale replies, NPC lock, warp,
  disconnect, status block, and the direct/item/auto/mob bypass entry points).
  """
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.ChatMessage
  alias Aesir.Net.GroundSkillCast
  alias Aesir.Net.ItemOnGround
  alias Aesir.Net.MoveRequest
  alias Aesir.Net.SkillCastFailed
  alias Aesir.Net.SkillTextInputReply
  alias Aesir.Net.SkillTextInputRequest
  alias Aesir.Net.SkillUnitSpawn
  alias Aesir.ZoneServer.Map.MapManager
  alias Aesir.ZoneServer.Mmo.MobSkill.Executor
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Player.Handlers.WarpHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerSession

  @skill_id 125
  @item_id 1065
  @capability :FEATURE_CAPABILITY_SKILL_TEXT_INPUT
  @map "prontera"

  describe "successful staging, placement, activation, and cleanup" do
    test "places atomically, a non-owner walker materializes the used cell before the ChatMessage, then it expires without returning an item" do
      caster = start_caster(id: 98_500, position: {150, 150})
      walker = start_player_session(id: 98_501, name: "TalkieWalker", position: {149, 150})

      flush_packets()

      simulate_incoming_message(caster.pid, %GroundSkillCast{
        skill_id: @skill_id,
        level: 1,
        x: 151,
        y: 150
      })

      assert_receive {:packet_sent,
                      %SkillTextInputRequest{request_id: request_id, skill_id: @skill_id}, _},
                     1_000

      simulate_incoming_message(caster.pid, %SkillTextInputReply{
        request_id: request_id,
        outcome: {:text, "hello there"}
      })

      assert eventually(fn ->
               state = PlayerSession.get_state(caster.pid)

               state.pending_skill_text_input == nil and
                 state.game_state.stats.current_state.sp == 49
             end)

      assert Inventory.held_amount(
               PlayerSession.get_state(caster.pid).game_state.inventory,
               @item_id
             ) == 9

      trap = Enum.find(Storage.all(), &(&1.skill_name == :ht_talkiebox))
      assert %{visibility: :party_only, state: %{trap: %{phase: :armed}}} = trap
      refute_received {:packet_sent, %ChatMessage{}, _}

      move_to(walker, {151, 150})

      assert_receive {:packet_sent, %SkillUnitSpawn{group: %{group_id: group_id, cells: [cell]}},
                      _},
                     500

      assert group_id == trap.group_id
      refute_received {:packet_sent, %ChatMessage{}, _}

      assert_receive {:packet_sent, %ChatMessage{gid: cell_id, message: "hello there"}, _}, 1_500
      assert cell_id == cell.cell_id

      assert %{visibility: :public, state: %{trap: %{phase: :used}}} = Storage.get(group_id)

      assert :ok = Manager.tick(Manager, System.monotonic_time(:millisecond) + 6_000)
      assert Storage.get(group_id) == nil
      refute_received {:packet_sent, %ItemOnGround{}, _}
    end

    test "the owner walking over their own trap does not activate it" do
      caster = start_caster(id: 98_510, position: {150, 150})
      place_trap(caster, {151, 150}, "should not fire")

      trap = Enum.find(Storage.all(), &(&1.skill_name == :ht_talkiebox))

      move_to(caster, {151, 150})
      Process.sleep(1_100)

      assert %{visibility: :party_only, state: %{trap: %{phase: :armed}}} =
               Storage.get(trap.group_id)

      refute_received {:packet_sent, %ChatMessage{}, _}
    end

    test "an untouched armed trap returns one floor trap on natural expiry" do
      ensure_coordinator(@map)
      caster = start_caster(id: 98_520, position: {155, 150})
      place_trap(caster, {156, 150}, "never heard")

      trap = Enum.find(Storage.all(), &(&1.skill_name == :ht_talkiebox))

      assert :ok = Manager.tick(Manager, System.monotonic_time(:millisecond) + 700_000)
      assert Storage.get(trap.group_id) == nil

      assert_receive {:packet_sent, %ItemOnGround{nameid: @item_id, amount: 1, x: 156, y: 150},
                      _},
                     3_000
    end
  end

  describe "rejected paths spend nothing and place no group" do
    test "capability absence rejects before preflight" do
      caster = start_player_session(id: 98_530, name: "NoCap", position: {150, 150})
      flush_packets()

      simulate_incoming_message(caster.pid, %GroundSkillCast{
        skill_id: @skill_id,
        level: 1,
        x: 151,
        y: 150
      })

      assert_receive {:packet_sent,
                      %SkillCastFailed{
                        skill_id: @skill_id,
                        reason: :SKILL_CAST_FAILURE_REASON_UNSPECIFIED
                      }, _}

      refute_received {:packet_sent, %SkillTextInputRequest{}, _}
      assert Storage.all() == []
    end

    test "preflight failure (missing catalyst) stages nothing" do
      caster = start_caster(id: 98_531, position: {150, 150}, item_amount: 0)
      flush_packets()

      simulate_incoming_message(caster.pid, %GroundSkillCast{
        skill_id: @skill_id,
        level: 1,
        x: 151,
        y: 150
      })

      assert_receive {:packet_sent,
                      %SkillCastFailed{
                        reason: :SKILL_CAST_FAILURE_REASON_MISSING_CATALYST
                      }, _}

      refute_received {:packet_sent, %SkillTextInputRequest{}, _}
      assert Storage.all() == []
    end

    test "a matching cancel clears the prompt without spending or placing" do
      caster = start_caster(id: 98_532, position: {150, 150})
      request_id = stage(caster, {151, 150})

      simulate_incoming_message(caster.pid, %SkillTextInputReply{
        request_id: request_id,
        outcome: {:cancel, true}
      })

      assert eventually(fn ->
               PlayerSession.get_state(caster.pid).pending_skill_text_input == nil
             end)

      assert_unspent(caster)
      assert Storage.all() == []
    end

    test "an unanswered prompt times out, clearing the pending request" do
      caster = start_caster(id: 98_533, position: {150, 150})
      request_id = stage(caster, {151, 150})

      send(caster.pid, {:skill_text_input_timeout, request_id})

      assert eventually(fn ->
               PlayerSession.get_state(caster.pid).pending_skill_text_input == nil
             end)

      assert_unspent(caster)
      assert Storage.all() == []
    end

    test "a stale mismatched reply is dropped and a subsequent forged reply cannot complete it" do
      caster = start_caster(id: 98_534, position: {150, 150})
      request_id = stage(caster, {151, 150})

      simulate_incoming_message(caster.pid, %SkillTextInputReply{
        request_id: request_id + 1,
        outcome: {:text, "forged"}
      })

      Process.sleep(50)

      staged = PlayerSession.get_state(caster.pid)
      assert staged.pending_skill_text_input.request_id == request_id

      simulate_incoming_message(caster.pid, %SkillTextInputReply{
        request_id: request_id + 9_999,
        outcome: {:text, "also forged"}
      })

      Process.sleep(50)
      assert_unspent(caster)
      assert Storage.all() == []
    end

    test "an NPC interaction lock rejects staging outright" do
      caster = start_caster(id: 98_535, position: {150, 150})

      :sys.replace_state(caster.pid, fn state ->
        %{state | interaction_lock: {self(), make_ref(), 0x6000_0000}}
      end)

      flush_packets()

      simulate_incoming_message(caster.pid, %GroundSkillCast{
        skill_id: @skill_id,
        level: 1,
        x: 151,
        y: 150
      })

      refute_received {:packet_sent, %SkillTextInputRequest{}, _}
      assert_unspent(caster)
      assert Storage.all() == []
    end

    test "warping away clears the prompt so the original reply can no longer complete it" do
      caster = start_caster(id: 98_536, position: {150, 150})
      request_id = stage(caster, {151, 150})

      state = PlayerSession.get_state(caster.pid)
      {:ok, warped} = WarpHandler.warp(state, @map, 170, 170)
      :sys.replace_state(caster.pid, fn _ -> warped end)

      assert PlayerSession.get_state(caster.pid).pending_skill_text_input == nil

      simulate_incoming_message(caster.pid, %SkillTextInputReply{
        request_id: request_id,
        outcome: {:text, "too late"}
      })

      Process.sleep(50)
      assert_unspent(caster)
      assert Storage.all() == []
    end

    test "a disconnect while pending leaves no group behind" do
      caster = start_caster(id: 98_537, position: {150, 150})
      _request_id = stage(caster, {151, 150})

      ref = Process.monitor(caster.pid)
      GenServer.stop(caster.pid, :normal)
      assert_receive {:DOWN, ^ref, :process, _pid, _reason}, 1_000

      assert Storage.all() == []
    end

    test "becoming Silenced while pending rejects the completion" do
      caster = start_caster(id: 98_538, position: {150, 150})
      request_id = stage(caster, {151, 150})

      :ok =
        StatusStorage.apply_status(:player, caster.character.id, :sc_silence, duration: 10_000)

      simulate_incoming_message(caster.pid, %SkillTextInputReply{
        request_id: request_id,
        outcome: {:text, "silenced"}
      })

      assert eventually(fn ->
               PlayerSession.get_state(caster.pid).pending_skill_text_input == nil
             end)

      assert_unspent(caster)
      assert Storage.all() == []
    end
  end

  describe "direct/item/auto/mob bypass entry points" do
    test "every non-input entry point refuses and neither spends nor places" do
      caster = start_caster(id: 98_540, position: {150, 150})
      game_state = PlayerSession.get_state(caster.pid).game_state
      target = {:ground, 151, 150}

      assert {:error, :skill_input_required} = Interpreter.cast(game_state, @skill_id, 1, target)

      assert {:error, :skill_input_required} =
               Interpreter.item_cast(game_state, @skill_id, 1, target)

      assert {:error, :skill_input_required} =
               Interpreter.auto_cast(game_state, @skill_id, 1, target)

      mob = spawn_test_mob(@map, {160, 160})

      row = %{skill: "HT_TALKIEBOX", skill_id: @skill_id, level: 1, target: :self, emotion: nil}
      assert {:error, :skill_input_required} = Executor.execute(get_mob_state(mob.pid), row)

      assert Storage.all() == []
    end
  end

  defp start_caster(opts) do
    item_amount = Keyword.get(opts, :item_amount, 10)
    opts = Keyword.drop(opts, [:item_amount])

    session =
      start_player_session(
        Keyword.put(opts, :learned_skills, %{Integer.to_string(@skill_id) => 1})
      )

    :sys.replace_state(session.pid, fn state ->
      inventory =
        if item_amount > 0,
          do: %{0 => %InventoryItem{nameid: @item_id, amount: item_amount}},
          else: %{}

      %{
        state
        | client_capabilities: [@capability],
          game_state: %{state.game_state | inventory: inventory}
      }
    end)

    session
  end

  defp stage(caster, {x, y}) do
    flush_packets()

    simulate_incoming_message(caster.pid, %GroundSkillCast{
      skill_id: @skill_id,
      level: 1,
      x: x,
      y: y
    })

    assert_receive {:packet_sent, %SkillTextInputRequest{request_id: request_id}, _}, 1_000
    request_id
  end

  defp place_trap(caster, {x, y}, text) do
    request_id = stage(caster, {x, y})

    simulate_incoming_message(caster.pid, %SkillTextInputReply{
      request_id: request_id,
      outcome: {:text, text}
    })

    assert eventually(fn ->
             PlayerSession.get_state(caster.pid).pending_skill_text_input == nil
           end)
  end

  defp assert_unspent(caster) do
    state = PlayerSession.get_state(caster.pid).game_state
    assert state.stats.current_state.sp == 50
    assert Inventory.held_amount(state.inventory, @item_id) == 10
  end

  defp move_to(player, {x, y} = position) do
    simulate_incoming_message(player.pid, %MoveRequest{dest_x: x, dest_y: y})
    assert :ok = wait_for_position(:player, player.character.id, position)
    Process.sleep(200)
  end

  defp ensure_coordinator(map_name), do: ensure_coordinator(map_name, 40)
  defp ensure_coordinator(map_name, 0), do: MapManager.get_coordinator(map_name)

  defp ensure_coordinator(map_name, retries) do
    case MapManager.get_coordinator(map_name) do
      {:ok, pid} ->
        {:ok, pid}

      _ ->
        Process.sleep(50)
        ensure_coordinator(map_name, retries - 1)
    end
  end
end
