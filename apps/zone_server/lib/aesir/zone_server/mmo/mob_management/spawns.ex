defmodule Aesir.ZoneServer.Mmo.MobManagement.Spawns do
  @moduledoc """
  Registry of per-map mob spawns, loaded as data from `priv/db/re/spawns/*.yml`.

  The map-name index is built once via `Loader` and cached in `:persistent_term`;
  `reload/0` rebuilds it after the data files change in a long-running session.
  On load every referenced mob id is checked against `Mobs`, so a typo in the
  hand-authored spawn YAML fails loudly instead of silently dropping mobs.
  """

  alias Aesir.ZoneServer.Mmo.MobManagement.Mobs
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.Spawns.Loader

  @pt_key __MODULE__

  @doc """
  Returns the spawn list for a given map.
  """
  @spec for_map(String.t()) :: {:ok, [MobSpawn.t()]} | :error
  def for_map(map_name), do: Map.fetch(index().by_map, map_name)

  @doc """
  Returns all spawn data, keyed by map name.
  """
  @spec all() :: %{String.t() => [MobSpawn.t()]}
  def all, do: index().by_map

  @doc """
  Rebuilds the cached index after editing the data files in a running session.
  """
  @spec reload() :: :ok
  def reload do
    :persistent_term.put(@pt_key, load())
    :ok
  end

  @spec index() :: Loader.index()
  defp index do
    case :persistent_term.get(@pt_key, nil) do
      nil ->
        built = load()
        :persistent_term.put(@pt_key, built)
        built

      built ->
        built
    end
  end

  @spec load() :: Loader.index()
  defp load do
    loaded = Loader.load()
    validate_mob_refs!(loaded)
    loaded
  end

  @spec validate_mob_refs!(Loader.index()) :: :ok
  defp validate_mob_refs!(%{by_map: by_map}) do
    for {map, spawns} <- by_map, %MobSpawn{mob: id} <- spawns do
      check_mob!(map, id)
    end

    :ok
  end

  @spec check_mob!(String.t(), integer()) :: :ok
  defp check_mob!(map, id) do
    with :error <- Mobs.by_id(id) do
      raise ArgumentError, "spawn map #{map} references unknown mob id #{id}"
    end

    :ok
  end
end
