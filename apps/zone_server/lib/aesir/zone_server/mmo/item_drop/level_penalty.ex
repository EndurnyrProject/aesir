defmodule Aesir.ZoneServer.Mmo.ItemDrop.LevelPenalty do
  @moduledoc """
  Level-gap penalty tables for item drops, experience, MVP item drops, and MVP
  experience.

  Renewal loads each `level_difference => percent` map from its database domain.
  Pre-renewal has no level-gap penalties, so its empty source lists install empty
  maps whose lookup semantics return the neutral rate of `100`. Each map is
  cached in `:persistent_term`; `reload/0` rebuilds all four after data changes.
  """

  alias Aesir.ZoneServer.Db.Source

  @pt_key_drop __MODULE__
  @pt_key_exp {__MODULE__, :exp}
  @pt_key_mvp_drop {__MODULE__, :mvp_drop}
  @pt_key_mvp_exp {__MODULE__, :mvp_exp}
  @no_penalty 100

  @doc """
  Returns the drop-rate percent for `mob_level - killer_base_level`.

  An unlisted difference inherits the nearest defined breakpoint of the same
  sign whose magnitude does not exceed it. The no-penalty band around zero (and
  any difference smaller than the closest breakpoint) yields `100`.
  """
  @spec drop(integer(), integer()) :: integer()
  def drop(mob_level, killer_base_level) do
    lookup(table(@pt_key_drop, "level_penalty.yml"), mob_level - killer_base_level)
  end

  @doc """
  Returns the EXP-rate percent for `mob_level - killer_base_level`. Same
  carry-forward semantics as `drop/2`; rates above `100` are a bonus for
  fighting an overleveled mob.
  """
  @spec exp(integer(), integer()) :: integer()
  def exp(mob_level, killer_base_level) do
    lookup(table(@pt_key_exp, "level_penalty_exp.yml"), mob_level - killer_base_level)
  end

  @doc """
  Returns the MVP drop-rate percent for `mob_level - killer_base_level`. Same
  carry-forward semantics as `drop/2`, scaled from `level_penalty_mvp_drop.yml`.
  """
  @spec mvp_drop(integer(), integer()) :: integer()
  def mvp_drop(mob_level, killer_base_level) do
    lookup(table(@pt_key_mvp_drop, "level_penalty_mvp_drop.yml"), mob_level - killer_base_level)
  end

  @doc """
  Returns the MVP EXP-rate percent for `mob_level - killer_base_level`. Same
  carry-forward semantics as `exp/2`, scaled from `level_penalty_mvp_exp.yml`.
  """
  @spec mvp_exp(integer(), integer()) :: integer()
  def mvp_exp(mob_level, killer_base_level) do
    lookup(table(@pt_key_mvp_exp, "level_penalty_mvp_exp.yml"), mob_level - killer_base_level)
  end

  @spec lookup(%{integer() => integer()}, integer()) :: integer()
  defp lookup(table, diff) do
    table
    |> Enum.filter(fn {b, _rate} -> same_sign_within?(b, diff) end)
    |> Enum.max_by(fn {b, _rate} -> abs(b) end, fn -> {nil, @no_penalty} end)
    |> elem(1)
  end

  @spec same_sign_within?(integer(), integer()) :: boolean()
  defp same_sign_within?(breakpoint, diff) do
    breakpoint != 0 and diff != 0 and
      breakpoint > 0 == diff > 0 and abs(breakpoint) <= abs(diff)
  end

  @doc "Reloads all level-penalty tables for the active game mode."
  @spec reload() :: :ok
  def reload do
    :persistent_term.put(@pt_key_drop, load("level_penalty.yml"))
    :persistent_term.put(@pt_key_exp, load("level_penalty_exp.yml"))
    :persistent_term.put(@pt_key_mvp_drop, load("level_penalty_mvp_drop.yml"))
    :persistent_term.put(@pt_key_mvp_exp, load("level_penalty_mvp_exp.yml"))
    :ok
  end

  @spec table(term(), String.t()) :: %{integer() => integer()}
  defp table(pt_key, file) do
    case :persistent_term.get(pt_key, nil) do
      nil ->
        built = load(file)
        :persistent_term.put(pt_key, built)
        built

      built ->
        built
    end
  end

  @spec load(String.t()) :: %{integer() => integer()}
  defp load(file) do
    file
    |> Source.sources()
    |> Enum.reduce(%{}, fn path, table -> Map.merge(table, YamlElixir.read_from_file!(path)) end)
  end
end
