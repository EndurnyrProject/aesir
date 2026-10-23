defmodule Aesir.ZoneServer.Unit.Player.QuestLog.Entry do
  @moduledoc """
  One quest-log row: its `state`, per-objective `counts` (positionally aligned
  with the definition's `targets`), a reserved `deadline` (always `nil` this
  iteration - the time-limit mechanic is deferred), and its `position` in the
  log's walk order (see `QuestLog.available/1`). A `nil` position sorts after
  every positioned row.
  """

  @typedoc "Quest progression state (`Q_INACTIVE`/`Q_ACTIVE`/`Q_COMPLETE`)."
  @type state :: :active | :inactive | :complete

  @enforce_keys [:state]
  defstruct state: nil, counts: [], deadline: nil, position: nil

  @type t() :: %__MODULE__{
          state: state(),
          counts: [non_neg_integer()],
          deadline: nil,
          position: non_neg_integer() | nil
        }
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

  ## Walk order

  A kill visits the not-complete quests in log order, not quest-id order. A
  new quest goes after every not-complete quest, completing a quest moves the
  last not-complete quest into its slot, and a changed quest keeps the slot of
  the quest it replaces. Each entry's `position` carries that order; a log
  loaded from storage starts in quest-id order.
  """

  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Mmo.QuestManagement.QuestDefinition
  alias Aesir.ZoneServer.Mmo.QuestManagement.Quests
  alias Aesir.ZoneServer.Unit.Player.QuestLog.Entry

  @type quest_id :: non_neg_integer()

  @typedoc "A monster definition id, as named by a quest objective's `mob_id`."
  @type mob_id :: non_neg_integer()

  @typedoc "A quest-log keyed by quest id."
  @type t :: %{quest_id() => Entry.t()}

  @typedoc """
  A monster kill as an objective sees it: the monster's id, runtime level,
  current race, size and defence element, and the map of the player being
  credited.
  """
  @type kill :: %{
          mob_id: mob_id(),
          level: non_neg_integer(),
          race: atom(),
          size: atom(),
          element: atom(),
          map: String.t()
        }

  @typedoc "A single objective count that moved during `tick_kill/2`."
  @type change :: %{
          quest_id: quest_id(),
          objective_index: non_neg_integer(),
          count: non_neg_integer()
        }

  @updatable [:active, :inactive]

  @races %{
    "formless" => :formless,
    "undead" => :undead,
    "brute" => :brute,
    "plant" => :plant,
    "insect" => :insect,
    "fish" => :fish,
    "demon" => :demon,
    "demihuman" => :demi_human,
    "angel" => :angel,
    "dragon" => :dragon,
    "all" => :all
  }

  @sizes %{"small" => :small, "medium" => :medium, "large" => :large, "all" => :all}

  @elements %{
    "neutral" => :neutral,
    "water" => :water,
    "earth" => :earth,
    "fire" => :fire,
    "wind" => :wind,
    "poison" => :poison,
    "holy" => :holy,
    "dark" => :shadow,
    "ghost" => :ghost,
    "undead" => :undead,
    "all" => :all
  }

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
          entry = %Entry{
            state: :active,
            counts: zeroed(targets),
            deadline: nil,
            position: next_position(log)
          }

          {:ok, Map.put(log, quest_id, entry), entry}
        end
    end
  end

  @doc """
  Removes a quest from the log regardless of state, including `:complete`
  entries (`quest_delete`, quest.cpp:685). The remaining quests keep their
  order.
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
            entry = %Entry{
              state: :active,
              counts: zeroed(targets),
              deadline: nil,
              position: Map.fetch!(log, old_id).position
            }

            {:ok, log |> Map.delete(old_id) |> Map.put(new_id, entry), entry}
        end
    end
  end

  @doc """
  Forces a quest to `:complete`, preserving its counters
  (`quest_update_status` to `Q_COMPLETE`, quest.cpp:849).

  Only active/inactive quests can be updated; an absent quest and an
  already-complete quest both return `{:error, :not_started}` (rAthena scans
  only the available quests, so neither is found). The last not-complete
  quest in walk order takes the completed quest's slot.
  """
  @spec complete(t(), quest_id()) :: {:ok, t()} | {:error, :not_started}
  def complete(log, quest_id) do
    case Map.fetch(log, quest_id) do
      {:ok, %Entry{state: state} = entry} when state in @updatable ->
        log
        |> move_last_into_slot(quest_id, entry.position)
        |> Map.put(quest_id, %{entry | state: :complete})
        |> then(&{:ok, &1})

      _ ->
        {:error, :not_started}
    end
  end

  @doc """
  The not-complete quests in walk order, as `{quest_id, entry}` pairs.
  """
  @spec available(t()) :: [{quest_id(), Entry.t()}]
  def available(log) do
    log
    |> Enum.filter(fn {_quest_id, %Entry{state: state}} -> state in @updatable end)
    |> Enum.sort_by(fn {quest_id, %Entry{position: position}} -> {position, quest_id} end)
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
  Credits a monster kill against every not-complete quest, in walk order
  (`quest_update_objective`, quest.cpp:757). See `tick_quest/3`.

  Returns the new log and the objectives that moved, in walk order then
  objective order.
  """
  @spec tick_kill(t(), kill()) :: {t(), [change()]}
  def tick_kill(log, kill) do
    log
    |> available()
    |> Enum.reduce({log, []}, fn {quest_id, _entry}, {acc_log, acc_changes} ->
      {acc_log, changes} = tick_quest(acc_log, quest_id, kill)
      {acc_log, acc_changes ++ changes}
    end)
  end

  @doc """
  Credits a monster kill against one quest's objectives.

  An objective naming a monster matches that monster only. An objective with
  no monster matches when every one of its filters passes: minimum and
  maximum level (`0` or absent means no bound), race, size and element
  (absent or `All` means any), location (absent, `All`, or a map the server
  does not hold means any map; otherwise the credited player's map), and the
  allowed monster list (absent or empty means any). A matching objective
  below its count moves by one. A complete or unknown quest is untouched.
  """
  @spec tick_quest(t(), quest_id(), kill()) :: {t(), [change()]}
  def tick_quest(log, quest_id, kill) do
    with {:ok, %Entry{state: state} = entry} when state in @updatable <- Map.fetch(log, quest_id),
         {:ok, %QuestDefinition{targets: targets}} <- Quests.by_id(quest_id) do
      {counts, changes} = bump(entry.counts, targets, quest_id, kill)
      {Map.put(log, quest_id, %{entry | counts: counts}), changes}
    else
      _ -> {log, []}
    end
  end

  @doc """
  The quest's extra drop rows that apply to a kill of `mob_id`, in definition
  order. A row naming monster `0` applies to every kill. An unknown quest has
  none.
  """
  @spec drops_for_kill(quest_id(), mob_id()) :: [QuestDefinition.drop()]
  def drops_for_kill(quest_id, mob_id) do
    case Quests.by_id(quest_id) do
      {:ok, %QuestDefinition{drops: drops}} ->
        Enum.filter(drops, &(&1.mob_id == 0 or &1.mob_id == mob_id))

      :error ->
        []
    end
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

  @spec next_position(t()) :: non_neg_integer()
  defp next_position(log) do
    log
    |> Map.values()
    |> Enum.map(& &1.position)
    |> Enum.filter(&is_integer/1)
    |> Enum.max(fn -> -1 end)
    |> Kernel.+(1)
  end

  @spec move_last_into_slot(t(), quest_id(), non_neg_integer() | nil) :: t()
  defp move_last_into_slot(log, quest_id, position) do
    case List.last(available(log)) do
      {^quest_id, _entry} -> log
      {last_id, last} -> Map.put(log, last_id, %{last | position: position})
    end
  end

  @spec bump([non_neg_integer()], [QuestDefinition.target()], quest_id(), kill()) ::
          {[non_neg_integer()], [change()]}
  defp bump(counts, targets, quest_id, kill) do
    padded = pad(counts, length(targets))

    targets
    |> Enum.with_index()
    |> Enum.reduce({padded, []}, fn {target, index}, {counts, hits} ->
      current = Enum.at(counts, index)

      if objective_matches?(target, kill) and current < target.count do
        next = current + 1
        hit = %{quest_id: quest_id, objective_index: index, count: next}
        {List.replace_at(counts, index, next), hits ++ [hit]}
      else
        {counts, hits}
      end
    end)
  end

  @spec objective_matches?(QuestDefinition.target(), kill()) :: boolean()
  defp objective_matches?(%{mob_id: target_mob}, %{mob_id: mob_id}) when is_integer(target_mob),
    do: target_mob == mob_id

  defp objective_matches?(target, kill) do
    level_matches?(target, kill.level) and
      any_or_equal?(Map.get(target, :race), kill.race, @races) and
      any_or_equal?(Map.get(target, :size), kill.size, @sizes) and
      any_or_equal?(Map.get(target, :element), kill.element, @elements) and
      location_matches?(Map.get(target, :map), kill.map) and
      allowed_mob?(Map.get(target, :mobs_allowed), kill.mob_id)
  end

  @spec level_matches?(QuestDefinition.target(), non_neg_integer()) :: boolean()
  defp level_matches?(target, level) do
    min_level = Map.get(target, :min_level) || 0
    max_level = Map.get(target, :max_level) || 0
    (min_level == 0 or min_level <= level) and (max_level == 0 or max_level >= level)
  end

  @spec allowed_mob?([mob_id()] | nil, mob_id()) :: boolean()
  defp allowed_mob?(allowed, _mob_id) when allowed in [nil, []], do: true
  defp allowed_mob?(allowed, mob_id), do: mob_id in allowed

  @spec any_or_equal?(String.t() | nil, atom(), %{String.t() => atom()}) :: boolean()
  defp any_or_equal?(nil, _value, _names), do: true

  defp any_or_equal?(name, value, names) do
    case Map.fetch(names, String.downcase(name)) do
      {:ok, :all} -> true
      {:ok, parsed} -> parsed == value
      :error -> false
    end
  end

  @spec location_matches?(String.t() | nil, String.t()) :: boolean()
  defp location_matches?(nil, _map), do: true

  defp location_matches?(location, map) do
    String.downcase(location) == "all" or not MapCache.exists?(location) or location == map
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
