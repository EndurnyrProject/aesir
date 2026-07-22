defmodule Aesir.ZoneServer.Unit.Player.PlayerSessionQuestKillTest do
  @moduledoc """
  Exercises `PlayerSession`'s `{:quest_kill, mob_id}` handler
  (`Unit.Mob.QuestHuntCredit` fan-out): the pure `QuestLog.tick_kill/2` clamps
  the matching objective, the moved quest is written through to
  `character_quests`, and one `QuestHuntProgress` is pushed per moved
  objective. A kill matching no active quest leaves the log untouched and
  writes/pushes nothing.
  """

  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.Net.QuestHuntProgress
  alias Aesir.ZoneServer.Mmo.QuestManagement.QuestDefinition
  alias Aesir.ZoneServer.Mmo.QuestManagement.Quests
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

  defp state(quest_log) do
    game_state = %{PlayerState.new(character()) | quest_log: quest_log}
    %{game_state: game_state, connection_pid: self()}
  end

  test "ticks the matching objective, persists the moved quest, and pushes progress" do
    expect(QuestPersistence, :upsert, fn 1, {7393, %Entry{state: :active, counts: [1]}} -> :ok end)

    log = %{7393 => %Entry{state: :active, counts: [0], deadline: nil}}

    {:noreply, new_state} = PlayerSession.handle_info({:loot, {:quest_kill, 2314}}, state(log))

    assert new_state.game_state.quest_log[7393].counts == [1]

    assert_receive {:send, :gameplay,
                    {:quest_hunt_progress,
                     %QuestHuntProgress{quest_id: 7393, objective_index: 0, count: 1, needed: 2}}}
  end

  test "clamps at the objective count so a re-kill after completion is a no-op" do
    reject(&QuestPersistence.upsert/2)

    log = %{7393 => %Entry{state: :active, counts: [2], deadline: nil}}

    {:noreply, new_state} = PlayerSession.handle_info({:loot, {:quest_kill, 2314}}, state(log))

    assert new_state.game_state.quest_log == log
    refute_receive {:send, :gameplay, {:quest_hunt_progress, _}}
  end

  test "no-ops for a kill matching no active quest" do
    reject(&QuestPersistence.upsert/2)

    log = %{7393 => %Entry{state: :active, counts: [0], deadline: nil}}

    {:noreply, new_state} = PlayerSession.handle_info({:loot, {:quest_kill, 9999}}, state(log))

    assert new_state.game_state.quest_log == log
    refute_receive {:send, :gameplay, {:quest_hunt_progress, _}}
  end
end
