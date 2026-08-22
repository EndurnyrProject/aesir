defmodule Aesir.ZoneServer.Navigation.SpawnIndex do
  @moduledoc """
  Inverted mob spawn index: which maps spawn a given mob.

  `Mmo.MobManagement.Spawns` is keyed by map only, so navigating to a monster -
  "where do I farm Porings?" - has no index to answer from. This folds the same
  data the other way round and caches it in `:persistent_term`, warming lazily
  on first lookup like the sibling navigation catalogs.
  """

  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.Spawns

  @pt_key __MODULE__

  @doc """
  Returns every map that spawns `mob_id`, or `[]` when nothing spawns it.

  Order is unspecified - the result is a set, and the router picks between
  candidate maps by route cost.
  """
  @spec maps_for_mob(non_neg_integer()) :: [String.t()]
  def maps_for_mob(mob_id), do: Map.get(index(), mob_id, [])

  @doc """
  Rebuilds the index after `Spawns.reload/0` in a long-running session.
  """
  @spec reload() :: :ok
  def reload do
    :persistent_term.put(@pt_key, build_index())
    :ok
  end

  defp index do
    case :persistent_term.get(@pt_key, nil) do
      nil ->
        built = build_index()
        :persistent_term.put(@pt_key, built)
        built

      built ->
        built
    end
  end

  defp build_index do
    Spawns.all()
    |> Enum.reduce(%{}, fn {map_name, spawns}, index ->
      Enum.reduce(spawns, index, fn %MobSpawn{mob: mob_id}, index ->
        Map.update(index, mob_id, MapSet.new([map_name]), &MapSet.put(&1, map_name))
      end)
    end)
    |> Map.new(fn {mob_id, maps} -> {mob_id, MapSet.to_list(maps)} end)
  end
end
