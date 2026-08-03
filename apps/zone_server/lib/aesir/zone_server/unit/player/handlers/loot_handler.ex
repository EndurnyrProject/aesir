defmodule Aesir.ZoneServer.Unit.Player.Handlers.LootHandler do
  @moduledoc """
  Kill-reward glue for a player session: drop rolling for the killing blow's
  reward owner (`{:mob_killed, ...}`) and hunting-quest kill credit
  (`{:quest_kill, ...}`).
  """

  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Mmo.ItemDrop.DropCalculator
  alias Aesir.ZoneServer.Mmo.ItemManagement.Production.OreTable
  alias Aesir.ZoneServer.Mmo.Skill.Learned
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
  EXP for the kill is granted separately, per eligible typed contributor, via
  `{:progression, {:mob_kill_exp, base, job, mob_race}}`
  (`Unit.Mob.KillExp.distribute_typed/6`); this handler only rolls and places
  this reward-owner session's drops. Ore Discovery additionally requires an
  actual player final source.
  """
  @spec mob_killed(map(), map()) :: {:noreply, map()}
  def mob_killed(payload, state), do: mob_killed(payload, state, &:rand.uniform/1)

  @doc false
  @spec mob_killed(map(), map(), (pos_integer() -> pos_integer())) :: {:noreply, map()}
  def mob_killed(payload, state, rng) do
    maybe_drop_items(payload, state, rng)
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

  # Rolls the slain mob's drop table from the reward owner's session (the only
  # place holding both the table and the reward owner's stats) and places results as
  # ground items through the map coordinator. Legacy payloads without a drop
  # table fall through to the no-op clause.
  defp maybe_drop_items(%{ownership: ownership, boss?: boss?} = payload, state, rng) do
    maybe_drop_items(payload, state, rng, ownership: {ownership, boss?})
  end

  defp maybe_drop_items(payload, state, rng), do: maybe_drop_items(payload, state, rng, [])

  defp maybe_drop_items(
         %{drops: drops, mob_level: mob_level, map: map, x: x, y: y} = payload,
         state,
         rng,
         opts
       ) do
    stats = state.game_state.stats
    luk = Stats.get_effective_stat(stats, :luk)
    base_level = stats.progression.base_level
    char_id = state.game_state.character_id

    drop_bonus =
      :player |> ModifierCalculator.get_all_modifiers(char_id) |> Map.get(:drop_rate, 0)

    items =
      drops
      |> DropCalculator.roll(luk, base_level, mob_level, drop_bonus, map, x, y)
      |> maybe_discover_ore(
        stats.progression.learned_skills,
        x,
        y,
        rng,
        Map.get(payload, :final_source, {:player, char_id})
      )

    case {items, opts} do
      {[], _opts} -> :ok
      {items, []} -> Coordinator.drop_items(map, items, x, y)
      {items, opts} -> Coordinator.drop_items(map, items, x, y, opts)
    end
  end

  defp maybe_drop_items(_payload, _state, _rng, _opts), do: :ok

  defp maybe_discover_ore(drops, learned_skills, x, y, rng, {:player, _id}) do
    if Learned.learned_level(learned_skills, 106) > 0 do
      entries = OreTable.entries()
      {item_id, rate} = Enum.fetch!(entries, rng.(length(entries)) - 1)

      if rng.(10_000) <= rate, do: drops ++ [{item_id, 1, x, y, true}], else: drops
    else
      drops
    end
  end

  defp maybe_discover_ore(drops, _learned_skills, _x, _y, _rng, _final_source), do: drops

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
