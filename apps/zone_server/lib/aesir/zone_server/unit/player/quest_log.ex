defmodule Aesir.ZoneServer.Unit.Player.QuestLog.Entry do
  @moduledoc """
  One quest-log row: its `state`, per-objective `counts` (positionally aligned
  with the definition's `targets`), and a reserved `deadline` (always `nil` this
  iteration - the time-limit mechanic is deferred).
  """
  use TypedStruct

  @typedoc "Quest progression state (`Q_INACTIVE`/`Q_ACTIVE`/`Q_COMPLETE`)."
  @type state :: :active | :inactive | :complete

  typedstruct do
    field :state, state(), enforce: true
    field :counts, [non_neg_integer()], default: []
    field :deadline, nil, default: nil
  end
end

defmodule Aesir.ZoneServer.Unit.Player.QuestLog do
  @moduledoc """
  Pure rAthena quest-log semantics over a plain `%{quest_id => Entry}` map.

  No processes, no side effects: every function takes a log and returns a new
  one (plus, where relevant, the affected entry or the objectives that changed).
  This is where quest fidelity lives; it mirrors `src/map/quest.cpp`.

  ## State

  Each entry is an `Entry` with `state` (`:active | :inactive | :complete`),
  `counts` (positionally aligned with the definition's `targets`), and a reserved
  `deadline` that is always `nil` this iteration. `check/3` therefore behaves as
  rAthena would with an unexpired timer, which is why the `:playtime`/`:hunting`
  "timeout reached" codes (2 / 1 respectively) never surface yet.

  ## `check/3` return matrix (verified against `quest_check`, quest.cpp:898)

  | state \\ mode | `:havequest` | `:playtime` | `:hunting`          |
  |--------------|--------------|-------------|---------------------|
  | not started  | -1           | -1          | -1                  |
  | `:inactive`  | 1            | 0           | 2 if met, else 0    |
  | `:active`    | 1            | 0           | 2 if met, else 0    |
  | `:complete`  | 2            | 1           | 0                   |

  Notes:

  - `:havequest` on an `:inactive` quest returns `1`, not `0`: `quest_check`
    reports inactive quests as active (`quest.cpp:908`). This contradicts
    `doc/script_commands.txt` (which documents `0` for inactive) - the C source
    is authoritative, so we follow it.
  - `:hunting` is "all objectives met" (code `2`) versus not (code `0`). A quest
    with no targets is vacuously met and returns `2`, matching rAthena's empty
    `objectives` scan (`quest.cpp:918`).
  - `is_begin/2` collapses the same states to `0` (never) / `1` (has, either
    inactive or active) / `2` (complete).
  """

  alias Aesir.ZoneServer.Mmo.QuestManagement.QuestDefinition
  alias Aesir.ZoneServer.Mmo.QuestManagement.Quests
  alias Aesir.ZoneServer.Unit.Player.QuestLog.Entry

  @type quest_id :: non_neg_integer()

  @typedoc "A monster definition id, as named by a quest objective's `mob_id`."
  @type mob_id :: non_neg_integer()

  @typedoc "A quest-log keyed by quest id."
  @type t :: %{quest_id() => Entry.t()}

  @typedoc "A single objective count that moved during `tick_kill/2`."
  @type change :: %{
          quest_id: quest_id(),
          objective_index: non_neg_integer(),
          count: non_neg_integer()
        }

  @updatable [:active, :inactive]

  @doc """
  Adds a quest as `:active` with zeroed counters (`quest_add`, quest.cpp:590).

  Rejects an unknown quest id and a quest already in the log, matching the
  `quest_search`-then-`HAVEQUEST` guards; the definition is resolved first.
  """
  @spec add(t(), quest_id()) ::
          {:ok, t(), Entry.t()} | {:error, :already_started | :unknown_quest}
  def add(log, quest_id) do
    case Quests.by_id(quest_id) do
      :error ->
        {:error, :unknown_quest}

      {:ok, %QuestDefinition{targets: targets}} ->
        if Map.has_key?(log, quest_id) do
          {:error, :already_started}
        else
          entry = %Entry{state: :active, counts: zeroed(targets), deadline: nil}
          {:ok, Map.put(log, quest_id, entry), entry}
        end
    end
  end

  @doc """
  Removes a quest from the log regardless of state, including `:complete`
  entries (`quest_delete`, quest.cpp:685).
  """
  @spec delete(t(), quest_id()) :: {:ok, t()} | {:error, :not_started}
  def delete(log, quest_id) do
    if Map.has_key?(log, quest_id) do
      {:ok, Map.delete(log, quest_id)}
    else
      {:error, :not_started}
    end
  end

  @doc """
  Atomically replaces an active/inactive quest with a fresh one
  (`quest_change`, quest.cpp:636).

  The log is left untouched on any error. Guard order follows rAthena: the new
  definition must exist, the new quest must not already be held, the old quest
  must be held, and the old quest must not be complete (rAthena scans only the
  available - non-complete - quests when locating the old one).
  """
  @spec change(t(), quest_id(), quest_id()) ::
          {:ok, t(), Entry.t()}
          | {:error, :already_started | :already_completed | :not_started | :unknown_quest}
  def change(log, old_id, new_id) do
    case Quests.by_id(new_id) do
      :error ->
        {:error, :unknown_quest}

      {:ok, %QuestDefinition{targets: targets}} ->
        cond do
          Map.has_key?(log, new_id) ->
            {:error, :already_started}

          not Map.has_key?(log, old_id) ->
            {:error, :not_started}

          match?(%Entry{state: :complete}, Map.fetch!(log, old_id)) ->
            {:error, :already_completed}

          true ->
            entry = %Entry{state: :active, counts: zeroed(targets), deadline: nil}
            {:ok, log |> Map.delete(old_id) |> Map.put(new_id, entry), entry}
        end
    end
  end

  @doc """
  Forces a quest to `:complete`, preserving its counters
  (`quest_update_status` to `Q_COMPLETE`, quest.cpp:849).

  Only active/inactive quests can be updated; an absent quest and an
  already-complete quest both return `{:error, :not_started}` (rAthena scans
  only the available quests, so neither is found).
  """
  @spec complete(t(), quest_id()) :: {:ok, t()} | {:error, :not_started}
  def complete(log, quest_id) do
    case Map.fetch(log, quest_id) do
      {:ok, %Entry{state: state} = entry} when state in @updatable ->
        {:ok, Map.put(log, quest_id, %{entry | state: :complete})}

      _ ->
        {:error, :not_started}
    end
  end

  @doc """
  Queries quest state (`quest_check`, quest.cpp:898). See the module return
  matrix. `:playtime`/`:hunting` treat the (always-`nil`) deadline as unexpired.
  """
  @spec check(t(), quest_id(), :havequest | :playtime | :hunting) :: -1 | 0 | 1 | 2
  def check(log, quest_id, mode) do
    case Map.fetch(log, quest_id) do
      :error -> -1
      {:ok, entry} -> check_present(entry, quest_id, mode)
    end
  end

  @doc """
  Whether the quest has been begun: `0` never, `1` inactive/active, `2` complete
  (`isbegin_quest`, `doc/script_commands.txt`).
  """
  @spec is_begin(t(), quest_id()) :: 0 | 1 | 2
  # credo:disable-for-next-line Credo.Check.Readability.PredicateFunctionNames
  def is_begin(log, quest_id) do
    case check(log, quest_id, :havequest) do
      -1 -> 0
      2 -> 2
      _ -> 1
    end
  end

  @doc """
  Credits a monster kill against every active/inactive quest whose objectives
  name `mob_id` (`quest_update_objective`, quest.cpp:757).

  Counters clamp at their objective count; complete quests are skipped, as are
  quests whose definition no longer resolves. Returns the new log and the
  objectives that moved (sorted by quest id then objective index) for
  persistence and the client push.
  """
  @spec tick_kill(t(), mob_id()) :: {t(), [change()]}
  def tick_kill(log, mob_id) do
    {log, changes} =
      Enum.reduce(log, {log, []}, fn {quest_id, entry}, {acc_log, acc_changes} ->
        tick_entry(acc_log, acc_changes, quest_id, entry, mob_id)
      end)

    {log, Enum.sort_by(changes, &{&1.quest_id, &1.objective_index})}
  end

  @spec check_present(Entry.t(), quest_id(), :havequest | :playtime | :hunting) :: integer()
  defp check_present(%Entry{state: :complete}, _quest_id, :havequest), do: 2
  defp check_present(%Entry{}, _quest_id, :havequest), do: 1

  defp check_present(%Entry{state: :complete}, _quest_id, :playtime), do: 1
  defp check_present(%Entry{}, _quest_id, :playtime), do: 0

  defp check_present(%Entry{state: state, counts: counts}, quest_id, :hunting)
       when state in @updatable do
    case Quests.by_id(quest_id) do
      {:ok, %QuestDefinition{targets: targets}} ->
        if objectives_met?(counts, targets), do: 2, else: 0

      :error ->
        0
    end
  end

  defp check_present(%Entry{}, _quest_id, :hunting), do: 0

  @spec tick_entry(t(), [change()], quest_id(), Entry.t(), mob_id()) :: {t(), [change()]}
  defp tick_entry(log, changes, _quest_id, %Entry{state: state}, _mob_id)
       when state not in @updatable do
    {log, changes}
  end

  defp tick_entry(log, changes, quest_id, entry, mob_id) do
    case Quests.by_id(quest_id) do
      {:ok, %QuestDefinition{targets: targets}} ->
        {counts, hits} = bump(entry.counts, targets, quest_id, mob_id)
        {Map.put(log, quest_id, %{entry | counts: counts}), hits ++ changes}

      :error ->
        {log, changes}
    end
  end

  @spec bump([non_neg_integer()], [QuestDefinition.target()], quest_id(), mob_id()) ::
          {[non_neg_integer()], [change()]}
  defp bump(counts, targets, quest_id, mob_id) do
    padded = pad(counts, length(targets))

    targets
    |> Enum.with_index()
    |> Enum.reduce({padded, []}, fn {target, index}, {counts, hits} ->
      current = Enum.at(counts, index)

      if target.mob_id == mob_id and current < target.count do
        next = current + 1
        hit = %{quest_id: quest_id, objective_index: index, count: next}
        {List.replace_at(counts, index, next), [hit | hits]}
      else
        {counts, hits}
      end
    end)
  end

  @spec pad([non_neg_integer()], non_neg_integer()) :: [non_neg_integer()]
  defp pad(counts, target_length) when length(counts) >= target_length, do: counts

  defp pad(counts, target_length),
    do: counts ++ List.duplicate(0, target_length - length(counts))

  @spec objectives_met?([non_neg_integer()], [QuestDefinition.target()]) :: boolean()
  defp objectives_met?(counts, targets) do
    targets
    |> Enum.with_index()
    |> Enum.all?(fn {target, index} -> Enum.at(counts, index, 0) >= target.count end)
  end

  @spec zeroed([QuestDefinition.target()]) :: [non_neg_integer()]
  defp zeroed(targets), do: List.duplicate(0, length(targets))
end
