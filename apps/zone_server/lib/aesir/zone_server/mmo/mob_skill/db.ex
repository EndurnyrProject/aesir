defmodule Aesir.ZoneServer.Mmo.MobSkill.Db do
  @moduledoc """
  Runtime store for mob skill rows, loaded from `priv/db/re/mob_skills/mob_skills.yml`.

  The importer (`mix aesir.import.mob_skills`) writes rows grouped by mob id
  (string keys) plus the three global groups under reserved keys
  (`"global_all"`, `"global_boss"`, `"global_normal"`). This module reads that
  file, coerces every row into a stable atom-keyed shape the `Selector` can rely
  on, and caches an index in `:persistent_term` (mirroring `MobManagement.Mobs`).

  `rows_for/1` merges a mob's own rows with the global rows applicable to its
  class - `global_all` for every mob, plus `global_boss` for `:boss`-mode mobs or
  `global_normal` otherwise - resolving the class via `Mobs.by_id/1` at read time
  so the on-disk file stays small and correct even though the renewal DB
  currently ships zero global rows.
  """

  alias Aesir.ZoneServer.Db.Source
  alias Aesir.ZoneServer.Mmo.MobManagement.Mobs

  @pt_key __MODULE__

  @global_keys ~w(global_all global_boss global_normal)

  @typedoc "A coerced skill row (atom keys, atom state/target/condition-type)."
  @type row :: %{
          skill: String.t(),
          skill_id: integer(),
          state: atom(),
          level: integer(),
          rate: integer(),
          cast_time: integer(),
          delay: integer(),
          cancelable: boolean(),
          target: atom(),
          condition: %{
            type: atom(),
            value: integer() | atom(),
            val1: integer() | nil,
            val2: integer() | nil,
            val3: integer() | nil,
            val4: integer() | nil,
            val5: integer() | nil
          },
          emotion: integer() | nil
        }

  @typedoc "The cached index: per-mob rows plus the three global groups."
  @type index :: %{
          by_id: %{integer() => [row()]},
          global_all: [row()],
          global_boss: [row()],
          global_normal: [row()]
        }

  @doc """
  Returns the mob's own rows merged with the global rows for its class.

  Unknown mob ids (no `MobDefinition`) return `[]`, since the class needed to
  resolve globals is unavailable and such a mob cannot be spawned anyway.
  """
  @spec rows_for(integer()) :: [row()]
  def rows_for(id) when is_integer(id) do
    case Mobs.by_id(id) do
      {:ok, mob} ->
        idx = index()
        own = Map.get(idx.by_id, id, [])
        own ++ idx.global_all ++ class_globals(idx, mob.modes)

      :error ->
        []
    end
  end

  @doc """
  Rebuilds the cached index after editing the data file in a running session.
  """
  @spec reload() :: :ok
  def reload do
    :persistent_term.put(@pt_key, build())
    :ok
  end

  @spec class_globals(index(), [atom()]) :: [row()]
  defp class_globals(idx, modes) do
    if :boss in modes, do: idx.global_boss, else: idx.global_normal
  end

  @spec index() :: index()
  defp index do
    case :persistent_term.get(@pt_key, nil) do
      nil ->
        built = build()
        :persistent_term.put(@pt_key, built)
        built

      built ->
        built
    end
  end

  @spec build() :: index()
  defp build do
    {globals, mobs} =
      "mob_skills/mob_skills.yml"
      |> Source.sources()
      |> Enum.reduce(%{}, &Map.merge(&2, YamlElixir.read_from_file!(&1)))
      |> Map.split(@global_keys)

    %{
      by_id: Map.new(mobs, fn {key, rows} -> {String.to_integer(key), coerce_rows(rows)} end),
      global_all: coerce_rows(Map.get(globals, "global_all", [])),
      global_boss: coerce_rows(Map.get(globals, "global_boss", [])),
      global_normal: coerce_rows(Map.get(globals, "global_normal", []))
    }
  end

  @spec coerce_rows([map()]) :: [row()]
  defp coerce_rows(rows), do: Enum.map(rows, &coerce_row/1)

  @spec coerce_row(map()) :: row()
  defp coerce_row(row) do
    %{
      skill: row["skill"],
      skill_id: row["skill_id"],
      state: String.to_atom(row["state"]),
      level: row["level"],
      rate: row["rate"],
      cast_time: row["cast_time"],
      delay: row["delay"],
      cancelable: row["cancelable"],
      target: String.to_atom(row["target"]),
      condition: coerce_condition(row["condition"]),
      emotion: row["emotion"]
    }
  end

  @spec coerce_condition(map()) :: map()
  defp coerce_condition(condition) do
    %{
      type: String.to_atom(condition["type"]),
      value: coerce_value(condition["value"]),
      val1: condition["val1"],
      val2: condition["val2"],
      val3: condition["val3"],
      val4: condition["val4"],
      val5: condition["val5"]
    }
  end

  @spec coerce_value(integer() | binary() | nil) :: integer() | atom()
  defp coerce_value(value) when is_binary(value), do: String.to_atom(value)
  defp coerce_value(value), do: value
end
