defmodule Aesir.ZoneServer.Unit.Player.PlayerSessionQuestKillTest do
  @moduledoc """
  Exercises `PlayerSession`'s `{:quest_kill, kill}` handler
  (`Unit.Mob.QuestHuntCredit` fan-out): the matching objective moves, the
  moved quest is written through to `character_quests`, and one
  `QuestHuntProgress` is pushed per moved objective; then the quest's extra
  drops are rolled and granted. A kill matching no active quest leaves the log
  untouched and writes/pushes nothing.
  """

  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.Net.ItemAddFailed
  alias Aesir.Net.QuestHuntProgress
  alias Aesir.ZoneServer.Mmo.QuestManagement.QuestDefinition
  alias Aesir.ZoneServer.Mmo.QuestManagement.Quests
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryManager
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.Handlers.LootHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.QuestLog.Entry
  alias Aesir.ZoneServer.Unit.Player.QuestPersistence

  setup :verify_on_exit!
  setup :setup_ets_tables

  @quest %QuestDefinition{id: 7393, title: "Hunt", targets: [%{mob_id: 2314, count: 2}]}

  setup do
    index = %{all: [@quest], by_id: %{@quest.id => @quest}}
    :persistent_term.put(Quests, index)
    on_exit(fn -> :persistent_term.erase(Quests) end)
    :ok
  end

  defp character do
    %Character{
      id: 1,
      account_id: 100,
      name: "Hunter",
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
      luk: 7
    }
  end

  defp kill(mob_id),
    do: %{mob_id: mob_id, level: 10, race: :brute, size: :small, element: :earth}

  defp state(quest_log) do
    game_state = %{PlayerState.new(character()) | quest_log: quest_log}
    %{game_state: game_state, connection_pid: self()}
  end

  test "ticks the matching objective, persists the moved quest, and pushes progress" do
    expect(QuestPersistence, :upsert, fn 1, {7393, %Entry{state: :active, counts: [1]}} -> :ok end)

    log = %{7393 => %Entry{state: :active, counts: [0], deadline: nil}}

    {:noreply, new_state} =
      PlayerSession.handle_info({:loot, {:quest_kill, kill(2314)}}, state(log))

    assert new_state.game_state.quest_log[7393].counts == [1]

    assert_receive {:send, :gameplay,
                    {:quest_hunt_progress,
                     %QuestHuntProgress{quest_id: 7393, objective_index: 0, count: 1, needed: 2}}}
  end

  test "clamps at the objective count so a re-kill after completion is a no-op" do
    reject(&QuestPersistence.upsert/2)

    log = %{7393 => %Entry{state: :active, counts: [2], deadline: nil}}

    {:noreply, new_state} =
      PlayerSession.handle_info({:loot, {:quest_kill, kill(2314)}}, state(log))

    assert new_state.game_state.quest_log == log
    refute_receive {:send, :gameplay, {:quest_hunt_progress, _}}
  end

  test "no-ops for a kill matching no active quest" do
    reject(&QuestPersistence.upsert/2)

    log = %{7393 => %Entry{state: :active, counts: [0], deadline: nil}}

    {:noreply, new_state} =
      PlayerSession.handle_info({:loot, {:quest_kill, kill(9999)}}, state(log))

    assert new_state.game_state.quest_log == log
    refute_receive {:send, :gameplay, {:quest_hunt_progress, _}}
  end

  describe "quest drops" do
    @drops %QuestDefinition{
      id: 8001,
      title: "Collect",
      targets: [%{mob_id: 2314, count: 5}],
      drops: [
        %{mob_id: 2314, item_id: 909, count: 3, rate: 10_000},
        %{mob_id: 1002, item_id: 910, count: 1, rate: 10_000},
        %{mob_id: 0, item_id: 1201, count: 1, rate: 2500},
        %{mob_id: 2314, item_id: 99_999_999, count: 1, rate: 5000}
      ]
    }

    setup do
      defs = [@quest, @drops]
      :persistent_term.put(Quests, %{all: defs, by_id: Map.new(defs, &{&1.id, &1})})
      stub(QuestPersistence, :upsert, fn _char_id, _entry -> :ok end)
      :ok
    end

    defp record_gives do
      test = self()

      stub(InventoryManager, :handle_give_item, fn item, amount, state, opts ->
        send(test, {:give, item.id, amount, opts})
        {:ok, state}
      end)
    end

    defp rolls(values) do
      {:ok, agent} = Agent.start_link(fn -> values end)
      test = self()

      fn 10_000 ->
        value = Agent.get_and_update(agent, fn [next | rest] -> {next, rest} end)
        send(test, {:roll, value})
        value
      end
    end

    defp mailbox(acc \\ []) do
      receive do
        message -> mailbox([message | acc])
      after
        0 -> Enum.reverse(acc)
      end
    end

    test "grants one item per row, rolling only rows below 10000, skipping other monsters and unknown items" do
      record_gives()
      log = %{8001 => %Entry{state: :active, counts: [0], position: 0}}

      {:noreply, _state} = LootHandler.quest_kill(kill(2314), state(log), rolls([2500, 1]))

      assert [
               {:send, :gameplay, {:quest_hunt_progress, %QuestHuntProgress{quest_id: 8001}}},
               {:give, 909, 1, %{identify: 1}},
               {:roll, 2500},
               {:give, 1201, 1, %{identify: 0}},
               {:roll, 1},
               :refresh_quest_info
             ] = mailbox()
    end

    test "a roll one above the rate grants nothing" do
      record_gives()
      log = %{8001 => %Entry{state: :active, counts: [5], position: 0}}

      {:noreply, _state} = LootHandler.quest_kill(kill(1002), state(log), rolls([2501]))

      assert [{:give, 910, 1, _opts}, {:roll, 2501}, :refresh_quest_info] = mailbox()
    end

    test "drops still roll for a quest whose objectives are already met" do
      record_gives()
      log = %{8001 => %Entry{state: :active, counts: [5], position: 0}}

      {:noreply, _state} = LootHandler.quest_kill(kill(2314), state(log), rolls([9999, 9999]))

      assert [{:give, 909, 1, _opts}, {:roll, 9999}, {:roll, 9999}, :refresh_quest_info] =
               mailbox()
    end

    test "each quest's objectives and drops run before the next quest, in walk order" do
      record_gives()

      log = %{
        8001 => %Entry{state: :active, counts: [0], position: 1},
        7393 => %Entry{state: :active, counts: [0], position: 0}
      }

      {:noreply, _state} = LootHandler.quest_kill(kill(2314), state(log), rolls([9999, 9999]))

      assert [
               {:send, :gameplay, {:quest_hunt_progress, %QuestHuntProgress{quest_id: 7393}}},
               {:send, :gameplay, {:quest_hunt_progress, %QuestHuntProgress{quest_id: 8001}}},
               {:give, 909, 1, _opts},
               {:roll, 9999},
               {:roll, 9999},
               :refresh_quest_info
             ] = mailbox()
    end

    test "a refused add reports ItemAddFailed and the next row still runs" do
      stub(InventoryOps, :add, fn _char_id, _inventory, _stats, _item, 1, _opts ->
        {:error, :overweight}
      end)

      log = %{
        8001 => %Entry{state: :complete, counts: [5]},
        7393 => %Entry{state: :active, counts: [2]}
      }

      :persistent_term.put(Quests, %{all: [@drops], by_id: %{8001 => @drops, 7393 => @drops}})

      {:noreply, _state} = LootHandler.quest_kill(kill(2314), state(log), rolls([1, 9999]))

      assert [
               {:send, :gameplay, {:quest_hunt_progress, %QuestHuntProgress{quest_id: 7393}}},
               {:send, :gameplay,
                {:item_add_failed, %ItemAddFailed{result: :ITEM_ADD_RESULT_OVERWEIGHT}}},
               {:roll, 1},
               {:send, :gameplay,
                {:item_add_failed, %ItemAddFailed{result: :ITEM_ADD_RESULT_OVERWEIGHT}}},
               {:roll, 9999},
               :refresh_quest_info
             ] = mailbox()
    end

    test "a player with only complete quests is untouched and refreshes nothing" do
      reject(&InventoryManager.handle_give_item/4)
      log = %{8001 => %Entry{state: :complete, counts: [5]}}

      assert {:noreply, state} = LootHandler.quest_kill(kill(2314), state(log), rolls([]))
      assert state.game_state.quest_log == log
      assert mailbox() == []
    end
  end
end
