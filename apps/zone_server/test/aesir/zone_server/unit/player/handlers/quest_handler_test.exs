defmodule Aesir.ZoneServer.Unit.Player.Handlers.QuestHandlerTest do
  @moduledoc """
  The client shelving or resuming a quest (`CZ_ACTIVE_QUEST`): an active or
  inactive quest flips, persists and is acked; a complete or absent quest is
  ignored without a reply.
  """

  use ExUnit.Case, async: false
  use Mimic

  alias Aesir.Net.QuestActiveRequest
  alias Aesir.Net.QuestStateChanged
  alias Aesir.ZoneServer.Unit.Player.Handlers.PacketHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.QuestHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.QuestLog.Entry
  alias Aesir.ZoneServer.Unit.Player.QuestPersistence
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_private
  setup :verify_on_exit!

  setup do
    Mimic.copy(QuestPersistence)
    Mimic.copy(UnitRegistry)

    stub(UnitRegistry, :update_unit_state, fn :player, _char_id, _game_state -> :ok end)
    :ok
  end

  describe "handle_active_request/2" do
    test "active: false shelves an active quest, persists it and acks state 0" do
      test_pid = self()

      expect(QuestPersistence, :upsert, fn 1000, {7393, entry} ->
        send(test_pid, {:upserted, entry})
        :ok
      end)

      state = state(%{7393 => %Entry{state: :active, counts: [3]}})

      assert {:noreply, new_state} =
               QuestHandler.handle_active_request(
                 %QuestActiveRequest{quest_id: 7393, active: false},
                 state
               )

      assert %Entry{state: :inactive, counts: [3]} = new_state.game_state.quest_log[7393]
      assert_received {:upserted, %Entry{state: :inactive, counts: [3]}}

      assert_received {:send, _ch,
                       {:quest_state_changed, %QuestStateChanged{quest_id: 7393, state: 0}}}
    end

    test "active: true resumes an inactive quest and acks state 1" do
      expect(QuestPersistence, :upsert, fn 1000, {7393, %Entry{state: :active}} -> :ok end)

      state = state(%{7393 => %Entry{state: :inactive, counts: [3]}})

      assert {:noreply, new_state} =
               QuestHandler.handle_active_request(
                 %QuestActiveRequest{quest_id: 7393, active: true},
                 state
               )

      assert %Entry{state: :active} = new_state.game_state.quest_log[7393]

      assert_received {:send, _ch,
                       {:quest_state_changed, %QuestStateChanged{quest_id: 7393, state: 1}}}
    end

    test "the state it already has is still persisted and acked" do
      expect(QuestPersistence, :upsert, fn 1000, {7393, %Entry{state: :active}} -> :ok end)

      state = state(%{7393 => %Entry{state: :active, counts: [3]}})

      assert {:noreply, new_state} =
               QuestHandler.handle_active_request(
                 %QuestActiveRequest{quest_id: 7393, active: true},
                 state
               )

      assert new_state.game_state.quest_log == state.game_state.quest_log

      assert_received {:send, _ch,
                       {:quest_state_changed, %QuestStateChanged{quest_id: 7393, state: 1}}}
    end

    test "a complete quest and an absent quest get no reply and no change" do
      reject(&QuestPersistence.upsert/2)

      state = state(%{7393 => %Entry{state: :complete, counts: [10]}})

      for quest_id <- [7393, 8000], active <- [true, false] do
        assert {:noreply, ^state} =
                 QuestHandler.handle_active_request(
                   %QuestActiveRequest{quest_id: quest_id, active: active},
                   state
                 )
      end

      refute_received {:send, _ch, _message}
    end
  end

  describe "PacketHandler" do
    test "routes a QuestActiveRequest to the handler" do
      expect(QuestPersistence, :upsert, fn 1000, {7393, %Entry{state: :inactive}} -> :ok end)

      state = state(%{7393 => %Entry{state: :active, counts: [3]}})

      assert {:noreply, new_state} =
               PacketHandler.handle_message(
                 %QuestActiveRequest{quest_id: 7393, active: false},
                 state
               )

      assert %Entry{state: :inactive} = new_state.game_state.quest_log[7393]
    end
  end

  defp state(quest_log) do
    %{
      connection_pid: self(),
      game_state: %PlayerState{character_id: 1000, account_id: 2000, quest_log: quest_log}
    }
  end
end
