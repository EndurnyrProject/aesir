defmodule Aesir.ZoneServer.Map.MapCache do
  require Logger

  alias Aesir.ZoneServer.Map.CacheLoader
  alias Aesir.ZoneServer.Map.MapData

  import Aesir.ZoneServer.EtsTable, only: [table_for: 1]

  @doc """
  Initializes the map cache and loads all maps.
  """
  def init do
    cache_path = Path.join(:code.priv_dir(:zone_server), "maps.mcache")

    case CacheLoader.load_cache(cache_path) do
      {:ok, map_data} ->
        Enum.each(map_data, fn {map_name, data} ->
          :ets.insert(table_for(:map_cache), {map_name, data})
        end)

        Logger.info("MapCache initialized with #{map_size(map_data)} maps")

        :ok

      {:error, reason} ->
        raise "Failed to load map cache from #{cache_path}: #{inspect(reason)}"
    end
  end

  @doc """
  Gets map data by name.
  """
  def get(map_name) when is_binary(map_name) do
    clean_name = String.replace_suffix(map_name, ".gat", "")

    # Quick fix for rAthena cache naming: prontera -> pprontera
    cache_name =
      case clean_name do
        "prontera" -> "pprontera"
        _ -> clean_name
      end

    case :ets.lookup(table_for(:map_cache), cache_name) do
      [{^cache_name, map_data}] -> {:ok, map_data}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Gets map data by name, raises if not found.
  """
  def get!(map_name) do
    case get(map_name) do
      {:ok, map_data} -> map_data
      {:error, :not_found} -> raise "Map #{map_name} not found in cache"
    end
  end

  @doc """
  Checks if a map exists in the cache.
  """
  def exists?(map_name) do
    :ets.member(table_for(:map_cache), map_name)
  end

  @doc """
  Lists all cached map names.
  """
  def list_maps do
    :ets.select(table_for(:map_cache), [{{:"$1", :_}, [], [:"$1"]}])
  end

  @doc """
  Gets the size of a map.
  """
  def get_map_size(map_name) do
    case get(map_name) do
      {:ok, %MapData{xs: width, ys: height}} -> {:ok, {width, height}}
      error -> error
    end
  end

  @doc """
  Checks if a position is walkable on a map.
  """
  def walkable?(map_name, x, y) do
    case get(map_name) do
      {:ok, map_data} -> MapData.walkable?(map_data, x, y)
      {:error, _} -> false
    end
  end
end
