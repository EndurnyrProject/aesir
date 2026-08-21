defmodule Aesir.ZoneServer.Npc.Warps do
  @moduledoc """
  Registry of per-map NPC warps, loaded as data from `priv/db/re/warps/*.yml`.

  The map-name index is built once via `Loader`, sanitized against `MapCache`
  (see `sanitize/1`) and cached in `:persistent_term`. It is warmed at boot by
  `Aesir.ZoneServer.MechanicsSupervisor` after `MapCache.init/0`; the first
  lookup also lazily warms it as a fallback - mirroring `Mmo.MobManagement.Spawns`.
  `reload/0` rebuilds it after the data files change in a long-running session.

  Sanitizing never raises: a warp referencing an unknown map or sitting on a
  non-walkable cell is dropped with a `Logger.warning`, so a bad data file can
  never crash a player's spawn path.
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
    sanitized = Loader.load() |> sanitize()
    count = sanitized.by_map |> Map.values() |> Enum.map(&length/1) |> Enum.sum()
    Logger.info("Loaded #{count} warps across #{map_size(sanitized.by_map)} maps")
    sanitized
  end

  @doc """
  Sanitizes the loaded index against `MapCache`, returning a cleaned index.

  Warp loading is lazy and runs on a player's spawn path, so a bad data file
  must never crash the caller. Every check is therefore non-fatal:

    * a warp whose source `map` or destination `to_map` is not loaded in
      `MapCache`, or whose own cell `(x, y)` is not walkable, is **dropped**
      with a `Logger.warning` - it could never fire or would teleport into a
      missing map;
    * a surviving warp with a blocked destination cell, or two warps on the
      same map whose `xs/ys` trigger areas intersect, is **kept** and logged
      as a warning.

  Public so the sanitizer can be unit-tested with crafted warps + a stubbed
  `MapCache`, mirroring the `Spawns.validate_mob_refs!/1` boot-validation shape.
  """
  @spec sanitize(Loader.index()) :: Loader.index()
  def sanitize(%{by_map: by_map} = index) do
    cleaned =
      by_map
      |> Enum.map(fn {map, warps} -> {map, Enum.filter(warps, &keep_warp?/1)} end)
      |> Enum.reject(fn {_map, warps} -> warps == [] end)
      |> Map.new()

    for {map, warps} <- cleaned do
      warn_overlaps_on_map(map, warps)
    end

    %{index | by_map: cleaned}
  end

  @spec keep_warp?(Warp.t()) :: boolean()
  defp keep_warp?(%Warp{} = warp) do
    with {:ok, map_data} <- fetch_map(warp.map, warp.id, "source"),
         {:ok, to_map_data} <- fetch_map(warp.to_map, warp.id, "destination"),
         :ok <- check_own_cell(warp, map_data) do
      warn_blocked_destination(warp, to_map_data)
      true
    else
      :drop -> false
    end
  end

  @spec fetch_map(String.t(), String.t(), String.t()) :: {:ok, MapData.t()} | :drop
  defp fetch_map(map_name, warp_id, role) do
    case MapCache.get(map_name) do
      {:ok, map_data} ->
        {:ok, map_data}

      {:error, :not_found} ->
        Logger.warning(
          "warp #{inspect(warp_id)} references unknown #{role} map #{inspect(map_name)}; dropping"
        )

        :drop
    end
  end

  @spec check_own_cell(Warp.t(), MapData.t()) :: :ok | :drop
  defp check_own_cell(%Warp{} = warp, map_data) do
    if span_walkable?(warp, map_data) do
      :ok
    else
      Logger.warning(
        "warp #{inspect(warp.id)} on map #{inspect(warp.map)} trigger area around " <>
          "non-walkable cell (#{warp.x}, #{warp.y}) has no walkable cell; dropping"
      )

      :drop
    end
  end

  # A warp fires from anywhere in its `(2*xs+1) x (2*ys+1)` trigger box, so it is
  # reachable as long as at least one cell in that box is walkable. Checking only
  # the centre cell wrongly drops warps whose centre sits on a wall/door threshold
  # while the approach cells are open (e.g. prontera prt08).
  @spec span_walkable?(Warp.t(), MapData.t()) :: boolean()
  defp span_walkable?(%Warp{} = warp, map_data) do
    Enum.any?((warp.y - warp.ys)..(warp.y + warp.ys), fn cy ->
      Enum.any?((warp.x - warp.xs)..(warp.x + warp.xs), fn cx ->
        MapData.walkable?(map_data, cx, cy)
      end)
    end)
  end

  @spec warn_blocked_destination(Warp.t(), MapData.t()) :: :ok
  defp warn_blocked_destination(%Warp{} = warp, to_map_data) do
    unless MapData.walkable?(to_map_data, warp.to_x, warp.to_y) do
      Logger.debug(
        "warp #{inspect(warp.id)} destination cell (#{warp.to_x}, #{warp.to_y}) on " <>
          "#{inspect(warp.to_map)} is not walkable"
      )
    end

    :ok
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
end
