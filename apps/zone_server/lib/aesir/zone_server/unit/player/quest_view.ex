defmodule Aesir.ZoneServer.Unit.Player.QuestView do
  @moduledoc """
  Builds outbound quest-log wire messages from `QuestLog` state.

  Mirrors `InventoryView` for the quest domain: every builder joins the
  session's `QuestLog.Entry` counts with the quest's `QuestDefinition` targets
  so the client receives `mob_id`/`needed`/`current` per objective and never
  needs a quest database of its own. A quest whose definition no longer
  resolves is sent with no objectives (persisted rows survive a trimmed
  quest_db - see `QuestLog`).
  """

  alias Aesir.Net.QuestAdded
  alias Aesir.Net.QuestEntry
  alias Aesir.Net.QuestHuntProgress
  alias Aesir.Net.QuestList
  alias Aesir.Net.QuestObjective
  alias Aesir.Net.QuestRemoved
  alias Aesir.Net.QuestStateChanged
  alias Aesir.ZoneServer.Mmo.QuestManagement.QuestDefinition
  alias Aesir.ZoneServer.Mmo.QuestManagement.Quests
  alias Aesir.ZoneServer.Unit.Player.QuestLog

  @doc """
  Builds the full `QuestList` dump for a quest log (sent alongside the
  inventory dump on map load).
  """
  @spec quest_list(QuestLog.t()) :: QuestList.t()
  def quest_list(quest_log) do
    quests =
      quest_log
      |> Enum.sort_by(fn {quest_id, _entry} -> quest_id end)
      |> Enum.map(fn {quest_id, entry} -> to_quest_entry(quest_id, entry) end)

    %QuestList{quests: quests}
  end

  @doc """
  Builds a `QuestAdded` for a quest that just entered the log
  (`setquest`, or the new side of `changequest`).
  """
  @spec quest_added(QuestLog.quest_id(), QuestLog.Entry.t()) :: QuestAdded.t()
  def quest_added(quest_id, %QuestLog.Entry{} = entry) do
    %QuestAdded{quest: to_quest_entry(quest_id, entry)}
  end

  @doc """
  Builds a `QuestRemoved` for a quest that just left the log
  (`erasequest`, or the old side of `changequest`).
  """
  @spec quest_removed(QuestLog.quest_id()) :: QuestRemoved.t()
  def quest_removed(quest_id), do: %QuestRemoved{quest_id: quest_id}

  @doc """
  Builds a `QuestStateChanged` for a quest that changed state in place,
  objectives unaffected (`completequest`).
  """
  @spec quest_state_changed(QuestLog.quest_id(), QuestLog.Entry.state()) ::
          QuestStateChanged.t()
  def quest_state_changed(quest_id, state) do
    %QuestStateChanged{quest_id: quest_id, state: encode_state(state)}
  end

  @doc """
  Builds a `QuestHuntProgress` for one objective that moved during
  `QuestLog.tick_kill/2`, joining the new count with the target's cap.
  """
  @spec quest_hunt_progress(QuestLog.change()) :: QuestHuntProgress.t()
  def quest_hunt_progress(%{quest_id: quest_id, objective_index: index, count: count}) do
    %QuestHuntProgress{
      quest_id: quest_id,
      objective_index: index,
      count: count,
      needed: needed_at(quest_id, index)
    }
  end

  @spec to_quest_entry(QuestLog.quest_id(), QuestLog.Entry.t()) :: QuestEntry.t()
  defp to_quest_entry(quest_id, %QuestLog.Entry{state: state, counts: counts}) do
    %QuestEntry{
      quest_id: quest_id,
      state: encode_state(state),
      objectives: objectives(quest_id, counts)
    }
  end

  @spec objectives(QuestLog.quest_id(), [non_neg_integer()]) :: [QuestObjective.t()]
  defp objectives(quest_id, counts) do
    case Quests.by_id(quest_id) do
      {:ok, %QuestDefinition{targets: targets}} ->
        targets
        |> Enum.with_index()
        |> Enum.map(fn {target, index} ->
          %QuestObjective{
            mob_id: target.mob_id,
            needed: target.count,
            current: Enum.at(counts, index, 0)
          }
        end)

      :error ->
        []
    end
  end

  @spec needed_at(QuestLog.quest_id(), non_neg_integer()) :: non_neg_integer()
  defp needed_at(quest_id, index) do
    with {:ok, %QuestDefinition{targets: targets}} <- Quests.by_id(quest_id),
         target when not is_nil(target) <- Enum.at(targets, index) do
      target.count
    else
      _ -> 0
    end
  end

  @spec encode_state(QuestLog.Entry.state()) :: 0 | 1 | 2
  defp encode_state(:inactive), do: 0
  defp encode_state(:active), do: 1
  defp encode_state(:complete), do: 2
end
