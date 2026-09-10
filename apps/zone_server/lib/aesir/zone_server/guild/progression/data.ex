defmodule Aesir.ZoneServer.Guild.Progression.Data do
  @moduledoc """
  Static guild progression data, loaded from the active mode's `guild` database
  domain.

  Serves the guild exp table (exp required per level) and the guild skill
  tree (max levels and prerequisites). Built once and cached in
  `:persistent_term`; `reload/0` rebuilds after the data files change.
  Same shape as `QuestManagement.Quests`.
  """

  alias Aesir.ZoneServer.Db.Source
  alias Aesir.ZoneServer.Mmo.DataLoader

  @pt_key __MODULE__

  @typedoc "A learnable guild skill's tree entry."
  @type skill_entry :: %{
          max_level: non_neg_integer(),
          prerequisites: [{non_neg_integer(), pos_integer()}]
        }

  @doc """
  Exp required to advance from the given level, or `:max_level` at the cap.

  Raises on a malformed exp table (a missing intermediate level) rather than
  silently capping progression early.
  """
  @spec exp_for_next(pos_integer()) :: {:ok, pos_integer()} | :max_level
  def exp_for_next(level) do
    built = index()

    if level >= built.max_level do
      :max_level
    else
      {:ok, Map.fetch!(built.exp_by_level, level)}
    end
  end

  @doc """
  The tree entry for a guild skill id, or `:error` for skills outside the
  learnable tree.
  """
  @spec skill_entry(non_neg_integer()) :: {:ok, skill_entry()} | :error
  def skill_entry(skill_id), do: Map.fetch(index().skills_by_id, skill_id)

  @doc """
  Rebuilds the cached index after editing the data files in a running session.
  """
  @spec reload() :: :ok
  def reload do
    :persistent_term.put(@pt_key, build())
    :ok
  end

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

  defp build do
    exp_by_level =
      "guild/exp.yml"
      |> Source.sources()
      |> Enum.flat_map(&YamlElixir.read_from_file!/1)
      |> DataLoader.merge_by_key(& &1["level"])
      |> Map.new(fn %{"level" => level, "exp" => exp} -> {level, exp} end)

    skills_by_id =
      "guild/skill_tree.yml"
      |> Source.sources()
      |> Enum.flat_map(&YamlElixir.read_from_file!/1)
      |> DataLoader.merge_by_key(& &1["id"])
      |> Map.new(fn %{"id" => id} = entry ->
        {id,
         %{
           max_level: Map.fetch!(entry, "max_level"),
           prerequisites:
             entry
             |> Map.fetch!("prerequisites")
             |> Enum.map(fn %{"id" => req_id, "level" => level} -> {req_id, level} end)
         }}
      end)

    %{
      exp_by_level: exp_by_level,
      max_level: Enum.max(Map.keys(exp_by_level)) + 1,
      skills_by_id: skills_by_id
    }
  end
end
