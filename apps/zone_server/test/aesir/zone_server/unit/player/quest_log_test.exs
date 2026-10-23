defmodule Aesir.ZoneServer.Unit.Player.QuestLogTest do
  use ExUnit.Case, async: false

  alias Aesir.ZoneServer.Mmo.QuestManagement.QuestDefinition
  alias Aesir.ZoneServer.Mmo.QuestManagement.Quests
  alias Aesir.ZoneServer.Unit.Player.QuestLog
  alias Aesir.ZoneServer.Unit.Player.QuestLog.Entry

  import Aesir.TestEtsSetup

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

  @filtered %QuestDefinition{
    id: 9000,
    title: "Filtered Hunt",
    targets: [
      %{count: 5, race: "DemiHuman", min_level: 140},
      %{count: 5, size: "Large", element: "Dark", max_level: 50, min_level: 1},
      %{count: 5, map: "prontera", mobs_allowed: [1002, 1003]}
    ]
  }

  @anywhere %QuestDefinition{
    id: 9001,
    title: "Anywhere",
    targets: [
      %{count: 5, map: "All", race: "All", size: "all", element: "All"},
      %{count: 5, map: "not_a_loaded_map"},
      %{mob_id: 1002, count: 5, race: "Dragon"}
    ]
  }

  @dropper %QuestDefinition{
    id: 9002,
    title: "Dropper",
    targets: [],
    drops: [
      %{mob_id: 1002, item_id: 909, count: 1, rate: 5000},
      %{mob_id: 0, item_id: 910, count: 3, rate: 10_000},
      %{mob_id: 1003, item_id: 911, count: 1, rate: 100}
    ]
  }

  setup do
    defs = [@targetless, @hunt, @same_mob, @filtered, @anywhere, @dropper]
    index = %{all: defs, by_id: Map.new(defs, &{&1.id, &1})}
    :persistent_term.put(Quests, index)
    on_exit(fn -> :persistent_term.erase(Quests) end)
    :ok
  end

  defp entry(state, counts), do: %Entry{state: state, counts: counts, deadline: nil}

  defp entry(state, counts, position),
    do: %Entry{state: state, counts: counts, deadline: nil, position: position}

  defp kill(mob_id, overrides \\ []) do
    Map.merge(
      %{
        mob_id: mob_id,
        level: 1,
        race: :formless,
        size: :small,
        element: :neutral,
        map: "geffen"
      },
      Map.new(overrides)
    )
  end

  defp counts(log, quest_id), do: log |> Map.fetch!(quest_id) |> Map.fetch!(:counts)

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
               QuestLog.tick_kill(log, kill(2314))

      assert %{7393 => %Entry{counts: [1, 0]}} = new_log
    end

    test "ticks the second objective by mob_id" do
      assert {%{7393 => %Entry{counts: [0, 1]}}, [%{objective_index: 1, count: 1}]} =
               QuestLog.tick_kill(%{7393 => entry(:active, [0, 0])}, kill(2311))
    end

    test "a non-matching mob changes nothing" do
      log = %{7393 => entry(:active, [0, 0])}
      assert {^log, []} = QuestLog.tick_kill(log, kill(9999))
    end

    test "clamps at the objective count" do
      log = %{7393 => entry(:active, [10, 0])}

      assert {%{7393 => %Entry{counts: [10, 0]}}, []} =
               QuestLog.tick_kill(log, kill(2314))
    end

    test "increments every objective naming the same mob, sorted by index" do
      assert {%{8000 => %Entry{counts: [1, 1]}}, changes} =
               QuestLog.tick_kill(%{8000 => entry(:active, [0, 0])}, kill(100))

      assert changes == [
               %{quest_id: 8000, objective_index: 0, count: 1},
               %{quest_id: 8000, objective_index: 1, count: 1}
             ]
    end

    test "ticks inactive quests" do
      assert {%{7393 => %Entry{counts: [1, 0]}}, [_]} =
               QuestLog.tick_kill(%{7393 => entry(:inactive, [0, 0])}, kill(2314))
    end

    test "skips complete quests" do
      log = %{7393 => entry(:complete, [0, 0])}
      assert {^log, []} = QuestLog.tick_kill(log, kill(2314))
    end

    test "skips a quest whose definition no longer resolves" do
      log = %{4242 => entry(:active, [0])}
      assert {^log, []} = QuestLog.tick_kill(log, kill(2314))
    end

    test "pads counts shorter than targets before ticking, so the increment persists" do
      log = %{7393 => entry(:active, [0])}

      assert {new_log, [%{quest_id: 7393, objective_index: 1, count: 1}]} =
               QuestLog.tick_kill(log, kill(2311))

      assert %{7393 => %Entry{counts: [0, 1]}} = new_log
    end

    test "reports changes in walk order, not quest-id order" do
      log = %{8000 => entry(:active, [0, 0], 0), 7393 => entry(:active, [0, 0], 1)}
      targets = [%{mob_id: 100, count: 9}]
      both = %{@hunt | id: 7393, targets: targets ++ targets}
      defs = [both, @same_mob]
      :persistent_term.put(Quests, %{all: defs, by_id: Map.new(defs, &{&1.id, &1})})

      {_log, changes} = QuestLog.tick_kill(log, kill(100))

      assert Enum.map(changes, &{&1.quest_id, &1.objective_index}) ==
               [{8000, 0}, {8000, 1}, {7393, 0}, {7393, 1}]
    end
  end

  describe "tick_kill/2 objectives without a monster" do
    setup :setup_ets_tables

    test "a level bound of 0 is unbounded and a set bound is inclusive" do
      log = %{9000 => entry(:active, [0, 0, 0])}

      assert [1, 0, 0] =
               counts(
                 elem(QuestLog.tick_kill(log, kill(1, race: :demi_human, level: 140)), 0),
                 9000
               )

      assert [0, 0, 0] =
               counts(
                 elem(QuestLog.tick_kill(log, kill(1, race: :demi_human, level: 139)), 0),
                 9000
               )

      dark_large = [size: :large, element: :shadow]

      assert [0, 1, 0] =
               counts(elem(QuestLog.tick_kill(log, kill(1, [level: 50] ++ dark_large)), 0), 9000)

      assert [0, 0, 0] =
               counts(elem(QuestLog.tick_kill(log, kill(1, [level: 51] ++ dark_large)), 0), 9000)
    end

    test "race, size and element compare case-insensitively, Dark meaning shadow" do
      log = %{9000 => entry(:active, [0, 0, 0])}

      assert [0, 0, 0] =
               counts(elem(QuestLog.tick_kill(log, kill(1, race: :brute, level: 150)), 0), 9000)

      assert [0, 0, 0] =
               counts(
                 elem(QuestLog.tick_kill(log, kill(1, size: :medium, element: :shadow)), 0),
                 9000
               )

      assert [0, 0, 0] =
               counts(
                 elem(QuestLog.tick_kill(log, kill(1, size: :large, element: :ghost)), 0),
                 9000
               )
    end

    test "a held location counts only on the credited player's map, and only listed monsters" do
      log = %{9000 => entry(:active, [0, 0, 0])}

      assert [0, 0, 1] =
               counts(elem(QuestLog.tick_kill(log, kill(1002, map: "prontera")), 0), 9000)

      assert [0, 0, 0] = counts(elem(QuestLog.tick_kill(log, kill(1002, map: "geffen")), 0), 9000)

      assert [0, 0, 0] =
               counts(elem(QuestLog.tick_kill(log, kill(1004, map: "prontera")), 0), 9000)
    end

    test "All, and a map the server does not hold, count on any map" do
      log = %{9001 => entry(:active, [0, 0, 0])}

      assert [1, 1, 0] =
               counts(elem(QuestLog.tick_kill(log, kill(1, race: :angel, size: :large)), 0), 9001)
    end

    test "an objective naming a monster ignores every filter" do
      log = %{9001 => entry(:active, [5, 5, 0])}

      assert [5, 5, 1] = counts(elem(QuestLog.tick_kill(log, kill(1002, race: :brute)), 0), 9001)
      assert [5, 5, 0] = counts(elem(QuestLog.tick_kill(log, kill(1003, race: :dragon)), 0), 9001)
    end
  end

  describe "walk order" do
    test "a new quest goes after every not-complete quest" do
      log = %{1000 => entry(:active, [], 4), 8000 => entry(:complete, [2, 3], 0)}

      assert {:ok, log, %Entry{position: 5}} = QuestLog.add(log, 7393)
      assert [1000, 7393] = log |> QuestLog.available() |> Enum.map(&elem(&1, 0))
    end

    test "completing a quest moves the last not-complete quest into its slot" do
      log = %{
        1000 => entry(:active, [], 0),
        7393 => entry(:active, [0, 0], 1),
        8000 => entry(:inactive, [0, 0], 2),
        9000 => entry(:active, [0, 0, 0], 3)
      }

      assert {:ok, log} = QuestLog.complete(log, 1000)
      assert [9000, 7393, 8000] = log |> QuestLog.available() |> Enum.map(&elem(&1, 0))
    end

    test "completing the last not-complete quest moves nothing" do
      log = %{1000 => entry(:active, [], 0), 7393 => entry(:active, [0, 0], 1)}

      assert {:ok, log} = QuestLog.complete(log, 7393)
      assert [{1000, %Entry{position: 0}}] = QuestLog.available(log)
    end

    test "a changed quest keeps the replaced quest's slot" do
      log = %{1000 => entry(:active, [], 0), 8000 => entry(:active, [0, 0], 1)}

      assert {:ok, log, %Entry{position: 0}} = QuestLog.change(log, 1000, 7393)
      assert [7393, 8000] = log |> QuestLog.available() |> Enum.map(&elem(&1, 0))
    end

    test "unpositioned entries walk after positioned ones, in quest-id order" do
      log = %{
        1000 => entry(:active, []),
        9000 => entry(:active, [], 7),
        7393 => entry(:active, [])
      }

      assert [9000, 1000, 7393] = log |> QuestLog.available() |> Enum.map(&elem(&1, 0))
    end
  end

  describe "drops_for_kill/2" do
    test "keeps the rows naming this monster or monster 0, in definition order" do
      assert [%{item_id: 909}, %{item_id: 910}] = QuestLog.drops_for_kill(9002, 1002)
      assert [%{item_id: 910}, %{item_id: 911}] = QuestLog.drops_for_kill(9002, 1003)
    end

    test "an unknown quest has none" do
      assert QuestLog.drops_for_kill(4242, 1002) == []
    end
  end
end
