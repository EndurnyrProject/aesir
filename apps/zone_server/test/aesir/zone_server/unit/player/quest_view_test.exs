defmodule Aesir.ZoneServer.Unit.Player.QuestViewTest do
  use ExUnit.Case, async: false

  alias Aesir.Net.Envelope
  alias Aesir.Net.QuestEntry
  alias Aesir.Net.QuestHuntProgress
  alias Aesir.Net.QuestList
  alias Aesir.Net.QuestObjective
  alias Aesir.ZoneServer.Mmo.QuestManagement.QuestDefinition
  alias Aesir.ZoneServer.Mmo.QuestManagement.Quests
  alias Aesir.ZoneServer.Unit.Player.QuestLog.Entry
  alias Aesir.ZoneServer.Unit.Player.QuestView

  @targetless %QuestDefinition{id: 1000, title: "Transcend", targets: []}

  @hunt %QuestDefinition{
    id: 7393,
    title: "Shiny Silver Blade",
    targets: [%{mob_id: 2314, count: 10}, %{mob_id: 2311, count: 10}]
  }

  setup do
    defs = [@targetless, @hunt]
    index = %{all: defs, by_id: Map.new(defs, &{&1.id, &1})}
    :persistent_term.put(Quests, index)
    on_exit(fn -> :persistent_term.erase(Quests) end)
    :ok
  end

  defp entry(state, counts), do: %Entry{state: state, counts: counts, deadline: nil}

  describe "quest_added/2" do
    test "a hunting quest carries one objective per target with current counts" do
      assert %Aesir.Net.QuestAdded{
               quest: %QuestEntry{
                 quest_id: 7393,
                 state: 1,
                 objectives: [
                   %QuestObjective{mob_id: 2314, needed: 10, current: 3},
                   %QuestObjective{mob_id: 2311, needed: 10, current: 0}
                 ]
               }
             } = QuestView.quest_added(7393, entry(:active, [3, 0]))
    end

    test "a target-less quest carries no objectives" do
      assert %Aesir.Net.QuestAdded{
               quest: %QuestEntry{quest_id: 1000, state: 1, objectives: []}
             } = QuestView.quest_added(1000, entry(:active, []))
    end

    test "a quest whose definition no longer resolves carries no objectives" do
      assert %Aesir.Net.QuestAdded{
               quest: %QuestEntry{quest_id: 4242, state: 1, objectives: []}
             } = QuestView.quest_added(4242, entry(:active, [0]))
    end
  end

  describe "quest_removed/1" do
    test "carries only the quest id" do
      assert %Aesir.Net.QuestRemoved{quest_id: 7393} = QuestView.quest_removed(7393)
    end
  end

  describe "quest_state_changed/2" do
    test "encodes each state to its rAthena e_quest_state code" do
      assert %Aesir.Net.QuestStateChanged{quest_id: 7393, state: 0} =
               QuestView.quest_state_changed(7393, :inactive)

      assert %Aesir.Net.QuestStateChanged{quest_id: 7393, state: 1} =
               QuestView.quest_state_changed(7393, :active)

      assert %Aesir.Net.QuestStateChanged{quest_id: 7393, state: 2} =
               QuestView.quest_state_changed(7393, :complete)
    end
  end

  describe "quest_hunt_progress/1" do
    test "joins the changed objective with its target's cap" do
      change = %{quest_id: 7393, objective_index: 1, count: 4}

      assert %QuestHuntProgress{
               quest_id: 7393,
               objective_index: 1,
               count: 4,
               needed: 10
             } = QuestView.quest_hunt_progress(change)
    end

    test "needed is 0 when the definition no longer resolves" do
      change = %{quest_id: 4242, objective_index: 0, count: 1}

      assert %QuestHuntProgress{quest_id: 4242, objective_index: 0, count: 1, needed: 0} =
               QuestView.quest_hunt_progress(change)
    end
  end

  describe "quest_list/1" do
    test "covers active, inactive, and complete entries, sorted by quest id" do
      log = %{
        7393 => entry(:active, [3, 0]),
        1000 => entry(:complete, []),
        4242 => entry(:inactive, [0])
      }

      assert %QuestList{
               quests: [
                 %QuestEntry{quest_id: 1000, state: 2, objectives: []},
                 %QuestEntry{quest_id: 4242, state: 0, objectives: []},
                 %QuestEntry{
                   quest_id: 7393,
                   state: 1,
                   objectives: [
                     %QuestObjective{mob_id: 2314, needed: 10, current: 3},
                     %QuestObjective{mob_id: 2311, needed: 10, current: 0}
                   ]
                 }
               ]
             } = QuestView.quest_list(log)
    end

    test "an empty log yields an empty list" do
      assert %QuestList{quests: []} = QuestView.quest_list(%{})
    end
  end

  describe "Envelope round-trip" do
    test "quest_list with a nested hunting entry round-trips through the oneof" do
      log = %{7393 => entry(:active, [3, 0])}
      env = %Envelope{body: {:quest_list, QuestView.quest_list(log)}}

      {:ok, iodata, _size} = Envelope.encode(env)

      assert {:ok,
              %Envelope{
                body:
                  {:quest_list,
                   %QuestList{
                     quests: [
                       %QuestEntry{
                         quest_id: 7393,
                         state: 1,
                         objectives: [
                           %QuestObjective{mob_id: 2314, needed: 10, current: 3},
                           %QuestObjective{mob_id: 2311, needed: 10, current: 0}
                         ]
                       }
                     ]
                   }}
              }} = Envelope.decode(IO.iodata_to_binary(iodata))
    end

    test "quest_hunt_progress round-trips through the oneof" do
      change = %{quest_id: 7393, objective_index: 0, count: 4}
      env = %Envelope{body: {:quest_hunt_progress, QuestView.quest_hunt_progress(change)}}

      {:ok, iodata, _size} = Envelope.encode(env)

      assert {:ok,
              %Envelope{
                body:
                  {:quest_hunt_progress,
                   %QuestHuntProgress{
                     quest_id: 7393,
                     objective_index: 0,
                     count: 4,
                     needed: 10
                   }}
              }} = Envelope.decode(IO.iodata_to_binary(iodata))
    end

    test "quest_added round-trips through the oneof" do
      env = %Envelope{body: {:quest_added, QuestView.quest_added(7393, entry(:active, [3, 0]))}}

      {:ok, iodata, _size} = Envelope.encode(env)

      assert {:ok,
              %Envelope{
                body:
                  {:quest_added,
                   %Aesir.Net.QuestAdded{
                     quest: %QuestEntry{
                       quest_id: 7393,
                       state: 1,
                       objectives: [
                         %QuestObjective{mob_id: 2314, needed: 10, current: 3},
                         %QuestObjective{mob_id: 2311, needed: 10, current: 0}
                       ]
                     }
                   }}
              }} = Envelope.decode(IO.iodata_to_binary(iodata))
    end

    test "quest_removed round-trips through the oneof" do
      env = %Envelope{body: {:quest_removed, QuestView.quest_removed(7393)}}

      {:ok, iodata, _size} = Envelope.encode(env)

      assert {:ok, %Envelope{body: {:quest_removed, %Aesir.Net.QuestRemoved{quest_id: 7393}}}} =
               Envelope.decode(IO.iodata_to_binary(iodata))
    end

    test "quest_state_changed round-trips through the oneof" do
      env = %Envelope{
        body: {:quest_state_changed, QuestView.quest_state_changed(7393, :complete)}
      }

      {:ok, iodata, _size} = Envelope.encode(env)

      assert {:ok,
              %Envelope{
                body:
                  {:quest_state_changed, %Aesir.Net.QuestStateChanged{quest_id: 7393, state: 2}}
              }} = Envelope.decode(IO.iodata_to_binary(iodata))
    end
  end
end
