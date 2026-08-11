defmodule Aesir.ZoneServer.Npc.QuestInfo do
  @moduledoc """
  Registry of NPC quest-icon bubbles declared by the rAthena `questinfo`
  buildin (`nd->qi_data` in rAthena).

  An NPC registers one or more ordered entries during its `OnInit` handler via
  the `Aesir.ZoneServer.Script.Dsl.questinfo/2,3,4` op. Each entry pairs a
  client icon/mark-color with an optional per-player condition closure
  `(Ctx.t() -> boolean())`. At runtime `Aesir.ZoneServer.Unit.Player.QuestInfoView`
  reads the entries for the player's current map, evaluates the conditions
  against that player's state, and pushes the resulting bubbles.

  State lives in the public `:npc_quest_info` ETS table, keyed by NPC gid, so
  the boot-time `OnInit` tasks (concurrent across gids, sequential within a
  gid) can register without a coordinating process. The table is created and
  cleared by `reload/0`, which `MechanicsSupervisor` calls before
  `Npc.Events.run_on_init/0`.
  """

  alias Aesir.ZoneServer.Script.Ctx

  @table :npc_quest_info

  @typedoc "A single declared quest-icon: its client icon/color and optional condition."
  @type entry :: %{
          icon: non_neg_integer(),
          color: non_neg_integer(),
          condition: (Ctx.t() -> boolean()) | nil
        }

  @typedoc "Every quest-icon entry declared on one NPC, in declaration order."
  @type npc_entry :: %{
          gid: non_neg_integer(),
          x: non_neg_integer(),
          y: non_neg_integer(),
          entries: [entry()]
        }

  @doc """
  Creates the `:npc_quest_info` ETS table (idempotent) and clears any prior
  entries. Called at boot before `OnInit` runs and in test setup.
  """
  @spec reload() :: :ok
  def reload do
    case :ets.whereis(@table) do
      :undefined ->
        :ets.new(@table, [:set, :public, :named_table, read_concurrency: true])

      _ref ->
        :ets.delete_all_objects(@table)
    end

    :ok
  end

  @doc """
  Appends a quest-icon entry to NPC `gid` (rAthena `nd->qi_data.push_back`).

  Entries accumulate in declaration order; at display time the first entry
  whose condition passes wins. A no-op when the table is absent (a script
  running outside a booted zone).
  """
  @spec register(
          non_neg_integer(),
          String.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          (Ctx.t() -> boolean()) | nil
        ) :: :ok
  def register(gid, map, x, y, icon, color, condition) do
    if :ets.whereis(@table) == :undefined do
      :ok
    else
      entry = %{icon: icon, color: color, condition: condition}
      existing = existing_entries(gid)
      :ets.insert(@table, {gid, map, x, y, existing ++ [entry]})
      :ok
    end
  end

  @doc "Every NPC with quest-icon entries on `map`, in table order."
  @spec for_map(String.t()) :: [npc_entry()]
  def for_map(map) do
    case :ets.whereis(@table) do
      :undefined ->
        []

      _ref ->
        @table
        |> :ets.match_object({:_, map, :_, :_, :_})
        |> Enum.map(fn {gid, _map, x, y, entries} ->
          %{gid: gid, x: x, y: y, entries: entries}
        end)
    end
  end

  @spec existing_entries(non_neg_integer()) :: [entry()]
  defp existing_entries(gid) do
    case :ets.lookup(@table, gid) do
      [{^gid, _map, _x, _y, entries}] -> entries
      [] -> []
    end
  end
end
