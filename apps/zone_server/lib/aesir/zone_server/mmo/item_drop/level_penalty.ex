defmodule Aesir.ZoneServer.Mmo.ItemDrop.LevelPenalty do
  @moduledoc """
  Renewal drop level-penalty table, loaded as data from `priv/db/level_penalty.yml`.

  The `level_difference => percent` map is cached once in `:persistent_term`;
  `reload/0` rebuilds it after the data file changes in a long-running session.
  Mirrors the lazy-build pattern in `Mmo.ItemManagement.Items`.
  """

  @pt_key __MODULE__
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
    diff = mob_level - killer_base_level

    table()
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
    :persistent_term.put(@pt_key, load())
    :ok
  end

  @spec table() :: %{integer() => integer()}
  defp table do
    case :persistent_term.get(@pt_key, nil) do
      nil ->
        built = load()
        :persistent_term.put(@pt_key, built)
        built

      built ->
        built
    end
  end

  @spec load() :: %{integer() => integer()}
  defp load do
    :zone_server
    |> Application.app_dir("priv/db/level_penalty.yml")
    |> YamlElixir.read_from_file!()
  end
end
