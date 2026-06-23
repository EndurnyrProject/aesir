defmodule Aesir.ZoneServer.Npc.Warps do
  @moduledoc """
  Registry of per-map NPC warps, loaded as data from `priv/db/warps/*.yml`.

  The map-name index is built once via `Loader` and cached in `:persistent_term`;
  `reload/0` rebuilds it after the data files change in a long-running session.
  The first lookup lazily warms the cache - mirroring `Mmo.MobManagement.Spawns`.
  """

  require Logger

  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Npc.Warp
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
  defp load do
    loaded = Loader.load(data_dir())
    validate!(loaded)
    loaded
  end

  @doc """
  Validates every loaded warp against `MapCache`.

  Hard failures (raise `ArgumentError` at boot): a warp whose `map` or `to_map`
  is not in `MapCache`, or whose own cell `(x, y)` is not walkable. Soft failures
  (`Logger.warning`): a blocked destination cell, or two warps on the same map
  whose `xs/ys` trigger areas intersect.

  Public so the verifier can be unit-tested with crafted warps + a stubbed
  `MapCache`, mirroring the `Spawns.validate_mob_refs!/1` boot-validation shape.
  """
  @spec validate!(Loader.index()) :: :ok
  def validate!(%{by_map: by_map}) do
    for {_map, warps} <- by_map, warp <- warps do
      check_warp!(warp)
    end

    for {map, warps} <- by_map do
      warn_overlaps_on_map(map, warps)
    end

    :ok
  end

  @spec check_warp!(Warp.t()) :: :ok
  defp check_warp!(%Warp{} = warp) do
    map_data = fetch_map!(warp.map, warp.id)
    to_map_data = fetch_map!(warp.to_map, warp.id)

    unless MapData.walkable?(map_data, warp.x, warp.y) do
      raise ArgumentError,
            "warp #{inspect(warp.id)} on map #{inspect(warp.map)} sits on a " <>
              "non-walkable cell (#{warp.x}, #{warp.y})"
    end

    unless MapData.walkable?(to_map_data, warp.to_x, warp.to_y) do
      Logger.warning(
        "warp #{inspect(warp.id)} destination cell (#{warp.to_x}, #{warp.to_y}) on " <>
          "#{inspect(warp.to_map)} is not walkable"
      )
    end

    :ok
  end

  @spec fetch_map!(String.t(), String.t()) :: MapData.t()
  defp fetch_map!(map_name, warp_id) do
    case MapCache.get(map_name) do
      {:ok, map_data} ->
        map_data

      {:error, :not_found} ->
        raise ArgumentError,
              "warp #{inspect(warp_id)} references unknown map #{inspect(map_name)}"
    end
  end

  @spec warn_overlaps_on_map(String.t(), [Warp.t()]) :: :ok
  defp warn_overlaps_on_map(_map, []), do: :ok
  defp warn_overlaps_on_map(_map, [_]), do: :ok

  defp warn_overlaps_on_map(map, warps) do
    indexed = Enum.with_index(warps)

    for {a, i} <- indexed, {b, j} <- indexed, i < j, areas_intersect?(a, b) do
      Logger.warning(
        "warps #{inspect(a.id)} and #{inspect(b.id)} on map #{inspect(map)} " <>
          "have overlapping trigger areas"
      )
    end

    :ok
  end

  @spec areas_intersect?(Warp.t(), Warp.t()) :: boolean()
  defp areas_intersect?(a, b) do
    a.x - a.xs <= b.x + b.xs and b.x - b.xs <= a.x + a.xs and
      a.y - a.ys <= b.y + b.ys and b.y - b.ys <= a.y + a.ys
  end

  @spec data_dir() :: Path.t()
  defp data_dir, do: Application.app_dir(:zone_server, "priv/db/warps")
end
