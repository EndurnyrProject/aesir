defmodule Aesir.ZoneServer.Npc.Shops do
  @moduledoc """
  Registry of per-map NPC shops, loaded as data from `priv/db/re/shops/*.yml`.

  The map-name index is built once via `Loader` and cached in `:persistent_term`.
  It is warmed at boot by `Aesir.ZoneServer.MechanicsSupervisor`; the first
  lookup also lazily warms it as a fallback - mirroring `Npc.Warps`. `reload/0`
  rebuilds it after the data files change in a long-running session.

  Boot-time validation (unknown map, non-walkable cell, phantom item) lives in
  the shop verifier, not here.
  """

  require Logger

  alias Aesir.ZoneServer.Npc.Shop
  alias Aesir.ZoneServer.Npc.Shops.Loader

  @pt_key __MODULE__

  @doc """
  Returns the shop list for a given map.
  """
  @spec for_map(String.t()) :: {:ok, [Shop.t()]} | :error
  def for_map(map_name), do: Map.fetch(index().by_map, map_name)

  @doc """
  Returns all shop data, keyed by map name.
  """
  @spec all() :: %{String.t() => [Shop.t()]}
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
    index = Loader.load(data_dir())
    count = index.by_map |> Map.values() |> Enum.map(&length/1) |> Enum.sum()
    Logger.info("Loaded #{count} shops across #{map_size(index.by_map)} maps")
    index
  end

  @spec data_dir() :: Path.t()
  defp data_dir, do: Application.app_dir(:zone_server, "priv/db/re/shops")
end
