defmodule Aesir.ZoneServer.Unit.Player.QuestLogTest do
  use ExUnit.Case, async: false

  alias Aesir.ZoneServer.Mmo.QuestManagement.QuestDefinition
  alias Aesir.ZoneServer.Mmo.QuestManagement.Quests
  alias Aesir.ZoneServer.Unit.Player.QuestLog
  alias Aesir.ZoneServer.Unit.Player.QuestLog.Entry

  @targetless %QuestDefinition{id: 1000, title: "Transcend", targets: []}

  @hunt %QuestDefinition{
    id: 7393,
    title: "Shiny Silver Blade",
    targets: [%{mob_id: 2314, count: 10}, %{mob_id: 2311, count: 10}]
  }

  @same_mob %QuestDefinition{
    id: 8000,
    title: "Twin Objective",
    targets: [%{mob_id: 100, count: 2}, %{mob_id: 100, count: 3}]
  }

  setup do
    defs = [@targetless, @hunt, @same_mob]
    index = %{all: defs, by_id: Map.new(defs, &{&1.id, &1})}
    :persistent_term.put(Quests, index)
    on_exit(fn -> :persistent_term.erase(Quests) end)
    :ok
  end

  defp entry(state, counts), do: %Entry{state: state, counts: counts, deadline: nil}

  describe "add/2" do
    test "adds a quest as active with zeroed counters aligned to its targets" do
      assert {:ok, log, entry} = QuestLog.add(%{}, 7393)
      assert %Entry{state: :active, counts: [0, 0], deadline: nil} = entry
      assert log == %{7393 => entry}
    end

    test "a target-less quest gets an empty counts list" do
      assert {:ok, _log, %Entry{counts: []}} = QuestLog.add(%{}, 1000)
    end

    test "rejects an unknown quest id" do
      assert {:error, :unknown_quest} = QuestLog.add(%{}, 999_999)
    end

    test "rejects a quest already in the log, in any state" do
      log = %{7393 => entry(:complete, [10, 10])}
      assert {:error, :already_started} = QuestLog.add(log, 7393)
    end
  end

  describe "delete/2" do
    test "removes an active quest" do
      assert {:ok, log} = QuestLog.delete(%{7393 => entry(:active, [0, 0])}, 7393)
      assert log == %{}
    end

    test "removes a complete quest too" do
      assert {:ok, %{}} = QuestLog.delete(%{7393 => entry(:complete, [10, 10])}, 7393)
    end

    test "errors when the quest is not in the log" do
      assert {:error, :not_started} = QuestLog.delete(%{}, 7393)
    end
  end

  describe "change/3" do
    test "atomically swaps the old quest for a fresh active new quest" do
      log = %{1000 => entry(:active, [])}
      assert {:ok, new_log, entry} = QuestLog.change(log, 1000, 7393)
      assert %Entry{state: :active, counts: [0, 0]} = entry
      assert new_log == %{7393 => entry}
    end

    test "rejects an unknown new quest and leaves the log untouched" do
      log = %{1000 => entry(:active, [])}
      assert {:error, :unknown_quest} = QuestLog.change(log, 1000, 999_999)
    end

    test "rejects when the new quest is already held" do
      log = %{1000 => entry(:active, []), 7393 => entry(:active, [0, 0])}
      assert {:error, :already_started} = QuestLog.change(log, 1000, 7393)
    end

    test "rejects when the old quest is not held" do
      assert {:error, :not_started} = QuestLog.change(%{}, 1000, 7393)
    end

    test "rejects when the old quest is already complete" do
      log = %{1000 => entry(:complete, [])}
      assert {:error, :already_completed} = QuestLog.change(log, 1000, 7393)
    end
  end

  describe "complete/2" do
    test "forces an active quest to complete and keeps its counts" do
      log = %{7393 => entry(:active, [3, 7])}

      assert {:ok, %{7393 => %Entry{state: :complete, counts: [3, 7]}}} =
               QuestLog.complete(log, 7393)
    end

    test "completes an inactive quest" do
      assert {:ok, %{7393 => %Entry{state: :complete}}} =
               QuestLog.complete(%{7393 => entry(:inactive, [0, 0])}, 7393)
    end

    test "errors on an absent quest" do
      assert {:error, :not_started} = QuestLog.complete(%{}, 7393)
    end

    test "errors on an already-complete quest" do
      assert {:error, :not_started} =
               QuestLog.complete(%{7393 => entry(:complete, [10, 10])}, 7393)
    end
  end

  describe "check/3 :havequest" do
    test "not started" do
      assert QuestLog.check(%{}, 7393, :havequest) == -1
    end

    test "inactive reports as active (1), following the C source over the docs" do
      assert QuestLog.check(%{7393 => entry(:inactive, [0, 0])}, 7393, :havequest) == 1
    end

    test "active" do
      assert QuestLog.check(%{7393 => entry(:active, [0, 0])}, 7393, :havequest) == 1
    end

    test "complete" do
      assert QuestLog.check(%{7393 => entry(:complete, [10, 10])}, 7393, :havequest) == 2
    end
  end

  describe "check/3 :playtime" do
    test "not started" do
      assert QuestLog.check(%{}, 7393, :playtime) == -1
    end

    test "inactive (unexpired) is 0" do
      assert QuestLog.check(%{7393 => entry(:inactive, [0, 0])}, 7393, :playtime) == 0
    end

    test "active (unexpired) is 0" do
      assert QuestLog.check(%{7393 => entry(:active, [0, 0])}, 7393, :playtime) == 0
    end

    test "complete is 1" do
      assert QuestLog.check(%{7393 => entry(:complete, [10, 10])}, 7393, :playtime) == 1
    end
  end

  describe "check/3 :hunting" do
    test "not started" do
      assert QuestLog.check(%{}, 7393, :hunting) == -1
    end

    test "active with unmet objectives is 0" do
      assert QuestLog.check(%{7393 => entry(:active, [10, 0])}, 7393, :hunting) == 0
    end

    test "active with all objectives met is 2" do
      assert QuestLog.check(%{7393 => entry(:active, [10, 10])}, 7393, :hunting) == 2
    end

    test "inactive with all objectives met is 2" do
      assert QuestLog.check(%{7393 => entry(:inactive, [10, 10])}, 7393, :hunting) == 2
    end

    test "complete is 0 (falls through the objective scan)" do
      assert QuestLog.check(%{7393 => entry(:complete, [10, 10])}, 7393, :hunting) == 0
    end

    test "a target-less quest is vacuously met (2)" do
      assert QuestLog.check(%{1000 => entry(:active, [])}, 1000, :hunting) == 2
    end
  end

  describe "is_begin/2" do
    test "never started is 0" do
      assert QuestLog.is_begin(%{}, 7393) == 0
    end

    test "inactive is 1" do
      assert QuestLog.is_begin(%{7393 => entry(:inactive, [0, 0])}, 7393) == 1
    end

    test "active is 1" do
      assert QuestLog.is_begin(%{7393 => entry(:active, [0, 0])}, 7393) == 1
    end

    test "complete is 2" do
      assert QuestLog.is_begin(%{7393 => entry(:complete, [10, 10])}, 7393) == 2
    end
  end

  describe "tick_kill/2" do
    test "increments the matching objective on an active quest and reports the change" do
      log = %{7393 => entry(:active, [0, 0])}

      assert {new_log, [%{quest_id: 7393, objective_index: 0, count: 1}]} =
               QuestLog.tick_kill(log, 2314)

      assert %{7393 => %Entry{counts: [1, 0]}} = new_log
    end

    test "ticks the second objective by mob_id" do
      assert {%{7393 => %Entry{counts: [0, 1]}}, [%{objective_index: 1, count: 1}]} =
               QuestLog.tick_kill(%{7393 => entry(:active, [0, 0])}, 2311)
    end

    test "a non-matching mob changes nothing" do
      log = %{7393 => entry(:active, [0, 0])}
      assert {^log, []} = QuestLog.tick_kill(log, 9999)
    end

    test "clamps at the objective count" do
      log = %{7393 => entry(:active, [10, 0])}

      assert {%{7393 => %Entry{counts: [10, 0]}}, []} =
               QuestLog.tick_kill(log, 2314)
    end

    test "increments every objective naming the same mob, sorted by index" do
      assert {%{8000 => %Entry{counts: [1, 1]}}, changes} =
               QuestLog.tick_kill(%{8000 => entry(:active, [0, 0])}, 100)

      assert changes == [
               %{quest_id: 8000, objective_index: 0, count: 1},
               %{quest_id: 8000, objective_index: 1, count: 1}
             ]
    end

    test "ticks inactive quests" do
      assert {%{7393 => %Entry{counts: [1, 0]}}, [_]} =
               QuestLog.tick_kill(%{7393 => entry(:inactive, [0, 0])}, 2314)
    end

    test "skips complete quests" do
      log = %{7393 => entry(:complete, [0, 0])}
      assert {^log, []} = QuestLog.tick_kill(log, 2314)
    end

    test "skips a quest whose definition no longer resolves" do
      log = %{4242 => entry(:active, [0])}
      assert {^log, []} = QuestLog.tick_kill(log, 2314)
    end

    test "pads counts shorter than targets before ticking, so the increment persists" do
      log = %{7393 => entry(:active, [0])}

      assert {new_log, [%{quest_id: 7393, objective_index: 1, count: 1}]} =
               QuestLog.tick_kill(log, 2311)

      assert %{7393 => %Entry{counts: [0, 1]}} = new_log
    end
  end
end
