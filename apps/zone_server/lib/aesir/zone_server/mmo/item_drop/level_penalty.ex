defmodule Aesir.ZoneServer.Mmo.ItemDrop.LevelPenalty do
  @moduledoc """
  Renewal level-penalty tables, loaded as data from `priv/db/level_penalty.yml`
  (item drops) and `priv/db/level_penalty_exp.yml` (experience).

  Each `level_difference => percent` map is cached once in `:persistent_term`;
  `reload/0` rebuilds both after the data files change in a long-running
  session. Mirrors the lazy-build pattern in `Mmo.ItemManagement.Items`.
  """

  @pt_key_drop __MODULE__
  @pt_key_exp {__MODULE__, :exp}
  @no_penalty 100

  @doc """
  Returns the drop-rate percent for `mob_level - killer_base_level`.

  Mirrors rAthena's carry-forward fill toward zero (`PenaltyDatabase::loadingFinished`):
  an unlisted diff inherits the nearest defined breakpoint of the same sign whose
  magnitude does not exceed it. The no-penalty band around zero (and any diff
  smaller than the closest breakpoint) yields `100`.
  """
  @spec drop(integer(), integer()) :: integer()
  def drop(mob_level, killer_base_level) do
    lookup(table(@pt_key_drop, "level_penalty.yml"), mob_level - killer_base_level)
  end

  @doc """
  Returns the EXP-rate percent for `mob_level - killer_base_level` (renewal
  `rAthena mob.cpp:3211`). Same carry-forward semantics as `drop/2`; rates
  above `100` are a bonus for fighting an overleveled mob.
  """
  @spec exp(integer(), integer()) :: integer()
  def exp(mob_level, killer_base_level) do
    lookup(table(@pt_key_exp, "level_penalty_exp.yml"), mob_level - killer_base_level)
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

  @spec reload() :: :ok
  def reload do
    :persistent_term.put(@pt_key_drop, load("level_penalty.yml"))
    :persistent_term.put(@pt_key_exp, load("level_penalty_exp.yml"))
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
    :zone_server
    |> Application.app_dir(Path.join("priv/db", file))
    |> YamlElixir.read_from_file!()
  end
end
