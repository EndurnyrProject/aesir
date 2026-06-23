defmodule Aesir.ZoneServer.Npc.Warps do
  @moduledoc """
  Registry of per-map NPC warps, loaded as data from `priv/db/warps/*.yml`.

  The map-name index is built once via `Loader` and cached in `:persistent_term`;
  `reload/0` rebuilds it after the data files change in a long-running session.
  The first lookup lazily warms the cache - mirroring `Mmo.MobManagement.Spawns`.
  """

  alias Aesir.ZoneServer.Npc.Warps.Loader

  @pt_key __MODULE__

  @doc """
  Returns the warp list for a given map.
  """
  @spec for_map(String.t()) :: {:ok, [Aesir.ZoneServer.Npc.Warp.t()]} | :error
  def for_map(map_name), do: Map.fetch(index().by_map, map_name)

  @doc """
  Returns all warp data, keyed by map name.
  """
  @spec all() :: %{String.t() => [Aesir.ZoneServer.Npc.Warp.t()]}
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
  defp load, do: Loader.load(data_dir())

  @spec data_dir() :: Path.t()
  defp data_dir, do: Application.app_dir(:zone_server, "priv/db/warps")
end
