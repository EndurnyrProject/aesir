defmodule Aesir.ZoneServer.Unit.Player.QuestPersistence do
  @moduledoc """
  Write-through persistence for a character's quest log, mirroring rAthena's
  `quest` table.

  Unlike `StatusPersistence`, rows are the durable source of truth for a
  quest's progress rather than an expiring snapshot: `load_on_spawn/1` reads
  them without consuming them, and every mutation upserts (or deletes) its
  row immediately, async and fire-and-forget, so a crash loses at most the
  last unflushed write.
  """

  import Ecto.Query

  require Logger

  alias Aesir.Commons.Models.CharacterQuest
  alias Aesir.Repo
  alias Aesir.ZoneServer.Unit.Player.QuestLog.Entry

  @task_supervisor Aesir.ZoneServer.TaskSupervisor

  @type quest_id :: non_neg_integer()

  @doc """
  Loads all persisted quest rows for the player into `game_state.quest_log`.

  Takes and returns the session `state` map; runs inside `PlayerSession.init/1`
  next to `StatusPersistence.restore_on_spawn/1`. Non-consuming: the table is
  the source of truth for quest progress, so rows are only read here.
  """
  @spec load_on_spawn(map()) :: map()
  def load_on_spawn(%{game_state: game_state} = state) do
    quest_log =
      game_state.character_id
      |> quest_query()
      |> Repo.all()
      |> Map.new(&{&1.quest_id, to_entry(&1)})

    %{state | game_state: %{game_state | quest_log: quest_log}}
  end

  @doc """
  Upserts a single quest row from its `{quest_id, Entry}` pair, replacing the
  state and counters in place (conflict target `(char_id, quest_id)`).
  Fire-and-forget.
  """
  @spec upsert(integer(), {quest_id(), Entry.t()}) :: :ok
  def upsert(char_id, {quest_id, %Entry{} = entry}) do
    run_async(fn -> do_upsert(char_id, quest_id, entry) end)
    :ok
  end

  @doc """
  Deletes a single quest row. Fire-and-forget.
  """
  @spec delete(integer(), quest_id()) :: :ok
  def delete(char_id, quest_id) do
    run_async(fn -> Repo.delete_all(quest_row_query(char_id, quest_id)) end)
    :ok
  end

  defp do_upsert(char_id, quest_id, %Entry{} = entry) do
    [count1, count2, count3] = padded_counts(entry.counts)

    attrs = %{
      char_id: char_id,
      quest_id: quest_id,
      state: Atom.to_string(entry.state),
      count1: count1,
      count2: count2,
      count3: count3
    }

    %CharacterQuest{}
    |> CharacterQuest.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace, [:state, :count1, :count2, :count3, :updated_at]},
      conflict_target: [:char_id, :quest_id]
    )
    |> case do
      {:ok, _row} ->
        :ok

      {:error, changeset} ->
        Logger.error(
          "Failed to upsert quest #{quest_id} for char #{char_id}: #{inspect(changeset.errors)}"
        )
    end
  end

  defp to_entry(%CharacterQuest{} = row) do
    %Entry{
      state: String.to_existing_atom(row.state),
      counts: [row.count1, row.count2, row.count3],
      deadline: nil
    }
  end

  @spec padded_counts([non_neg_integer()]) :: [non_neg_integer()]
  defp padded_counts(counts), do: counts |> Enum.concat([0, 0, 0]) |> Enum.take(3)

  defp run_async(fun) do
    if Application.get_env(:zone_server, :inline_persistence, false) do
      fun.()
    else
      Task.Supervisor.start_child(@task_supervisor, fun)
    end
  end

  defp quest_query(char_id) do
    from(q in CharacterQuest, where: q.char_id == ^char_id)
  end

  defp quest_row_query(char_id, quest_id) do
    from(q in CharacterQuest, where: q.char_id == ^char_id and q.quest_id == ^quest_id)
  end
end
