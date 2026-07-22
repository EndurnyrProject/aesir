defmodule Aesir.ZoneServer.Unit.Player.Handlers.LootHandler do
  @moduledoc """
  Kill-reward glue for a player session: drop rolling for the killing blow's
  attacker (`{:mob_killed, ...}`) and hunting-quest kill credit
  (`{:quest_kill, ...}`).
  """

  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Mmo.ItemDrop.DropCalculator
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Unit.Player.QuestLog
  alias Aesir.ZoneServer.Unit.Player.QuestPersistence
  alias Aesir.ZoneServer.Unit.Player.QuestView
  alias Aesir.ZoneServer.Unit.Player.StateCommit
  alias Aesir.ZoneServer.Unit.Player.Stats

  @doc """
  Routes a `:loot`-enveloped session message to its handler. `PlayerSession`'s
  single `handle_info({:loot, msg}, state)` clause delegates here; each head
  returns the GenServer-native `{:noreply, state}` tuple.
  """
  @spec info(term(), map()) :: {:noreply, map()}
  def info({:mob_killed, payload}, state), do: mob_killed(payload, state)
  def info({:quest_kill, mob_id}, state), do: quest_kill(mob_id, state)

  @doc """
  EXP for the kill is granted separately, per contributing attacker, via
  `{:mob_kill_exp, base, job}` (`Unit.Mob.KillExp.distribute/5`); this
  handler only rolls and places this session's own drops as the killing
  blow's attacker.
  """
  @spec mob_killed(map(), map()) :: {:noreply, map()}
  def mob_killed(payload, state) do
    maybe_drop_items(payload, state)
    {:noreply, state}
  end

  @doc """
  Credits a mob kill against this session's hunting quests
  (`Unit.Mob.QuestHuntCredit`): the pure `QuestLog.tick_kill/2` clamps the
  matching objectives, we write each moved quest through to
  `character_quests`, and push one `QuestHuntProgress` per moved objective.
  A kill matching no active quest leaves the log untouched and no-ops.
  """
  @spec quest_kill(QuestLog.mob_id(), map()) :: {:noreply, map()}
  def quest_kill(mob_id, %{game_state: game_state} = state) do
    case QuestLog.tick_kill(game_state.quest_log, mob_id) do
      {_quest_log, []} ->
        {:noreply, state}

      {quest_log, changes} ->
        persist_quest_changes(game_state.character_id, quest_log, changes)
        push_quest_progress(state.connection_pid, changes)
        {:noreply, StateCommit.commit(state, %{game_state | quest_log: quest_log})}
    end
  end

  # Rolls the slain mob's drop table from the killer's session (the only place
  # holding both the table and the killer's stats) and places any results as
  # ground items through the map coordinator. Legacy payloads without a drop
  # table fall through to the no-op clause.
  defp maybe_drop_items(%{drops: drops, mob_level: mob_level, map: map, x: x, y: y}, state) do
    stats = state.game_state.stats
    luk = Stats.get_effective_stat(stats, :luk)
    base_level = stats.progression.base_level
    char_id = state.game_state.character_id

    drop_bonus =
      :player |> ModifierCalculator.get_all_modifiers(char_id) |> Map.get(:drop_rate, 0)

    case DropCalculator.roll(drops, luk, base_level, mob_level, drop_bonus, map, x, y) do
      [] -> :ok
      rolled -> Coordinator.drop_items(map, rolled, x, y)
    end
  end

  defp maybe_drop_items(_payload, _state), do: :ok

  defp persist_quest_changes(char_id, quest_log, changes) do
    changes
    |> Enum.map(& &1.quest_id)
    |> Enum.uniq()
    |> Enum.each(fn quest_id ->
      QuestPersistence.upsert(char_id, {quest_id, Map.fetch!(quest_log, quest_id)})
    end)
  end

  defp push_quest_progress(connection_pid, changes) do
    Enum.each(changes, fn change ->
      MessageRouter.send_to(connection_pid, QuestView.quest_hunt_progress(change))
    end)
  end
end
