defmodule Aesir.ZoneServer.Map.CacheLoader do
  @moduledoc """
  Map cache loader compatible with rAthena's map cache format.
  The cache contains compressed map cell data for faster loading.
  """
  require Logger

  alias Aesir.ZoneServer.Map.MapData

  @map_name_length 12

  @doc """
  Loads a specific map from the cache.
  """
  @spec load_map_from_cache(String.t(), String.t()) :: {:ok, MapData.t()} | {:error, String.t()}
  def load_map_from_cache(cache_path, map_name) do
    case load_cache(cache_path) do
      {:ok, cache_maps} ->
        case Map.get(cache_maps, map_name) do
          nil -> {:error, "Map #{map_name} not found in cache"}
          map_data -> {:ok, map_data}
        end

      error ->
        error
    end
  end

  @doc """
  Loads a map cache file and returns all available maps.

  Cache file format:
  - Main header:
    - uint32: file_size
    - uint16: map_count
  - For each map:
    - Map info header:
      - char[12]: map name
      - int16: xs (width)
      - int16: ys (height)  
      - int32: len (compressed data length)
    - Compressed cell data (zlib compressed array of GAT types)
  """
  @spec load_cache(String.t()) :: {:ok, map()} | {:error, String.t()}
  def load_cache(cache_path) do
    case File.read(cache_path) do
      {:ok, data} ->
        parse_cache(data)

      {:error, reason} ->
        {:error, "Failed to read cache file: #{inspect(reason)}"}
    end
  end

  defp parse_cache(data) do
    case data do
      <<file_size::little-32, map_count::little-16, _padding::binary-2, maps_data::binary>>
      when file_size > 0 and map_count > 0 ->
        Logger.info("Loading map cache: file_size=#{file_size}, map_count=#{map_count}")
        parse_maps(maps_data, map_count, [])

      _ ->
        {:error, "Invalid cache file format"}
    end
  end

  defp parse_maps(data, count, _acc) do
    case collect_map_entries(data, count, []) do
      {:ok, entries} ->
        process_entries_parallel(entries)

      error ->
        error
    end
  end

  defp collect_map_entries(_, 0, acc), do: {:ok, Enum.reverse(acc)}

  defp collect_map_entries(data, remaining, acc) do
    case parse_map_entry_header(data) do
      {:ok, entry_info, rest} ->
        collect_map_entries(rest, remaining - 1, [entry_info | acc])

      {:error, reason} ->
        {:error, "Failed to parse map entry: #{reason}"}
    end
  end

  defp process_entries_parallel(entries) do
    results =
      entries
      |> Task.async_stream(
        fn {map_name, xs, ys, compressed_data} ->
          case decompress_and_create_map(compressed_data, map_name, xs, ys) do
            {:ok, map_data} -> {:ok, {map_name, map_data}}
            error -> error
          end
        end,
        max_concurrency: System.schedulers_online() * 2,
        ordered: false,
        timeout: 10_000
      )
      |> Enum.reduce_while([], fn
        {:ok, {:ok, entry}}, acc -> {:cont, [entry | acc]}
        {:ok, {:error, reason}}, _acc -> {:halt, {:error, reason}}
        {:exit, reason}, _acc -> {:halt, {:error, "Task failed: #{inspect(reason)}"}}
      end)

    case results do
      {:error, _} = error -> error
      map_list -> {:ok, Map.new(map_list)}
    end
  end

  defp parse_map_entry_header(data) when byte_size(data) >= 20 do
    <<name_bytes::binary-@map_name_length, xs::little-signed-16, ys::little-signed-16,
      len::little-signed-32, rest::binary>> = data

    map_name =
      case :binary.split(name_bytes, <<0>>) do
        [name | _] -> name
        _ -> name_bytes
      end

    if xs <= 0 or ys <= 0 or len <= 0 do
      {:error, "Invalid map dimensions or data length"}
    else
      case rest do
        <<compressed_data::binary-size(len), remaining::binary>> ->
          {:ok, {map_name, xs, ys, compressed_data}, remaining}

        _ ->
          {:error, "Insufficient data for compressed map cells"}
      end
    end
  end

  defp parse_map_entry_header(_), do: {:error, "Insufficient data for map entry header"}

  defp decompress_and_create_map(compressed_data, map_name, width, height) do
    expected_size = width * height

    case :zlib.uncompress(compressed_data) do
      decompressed when byte_size(decompressed) == expected_size ->
        map = %MapData{
          name: map_name,
          xs: width,
          ys: height,
          cells: decompressed,
          dynamic_cells: %{},
          npcs: [],
          users: 0,
          zone: 0
        }

        {:ok, map}

      decompressed ->
        {:error,
         "Decompressed size mismatch: expected #{expected_size}, got #{byte_size(decompressed)}"}
    end
  rescue
    e ->
      {:error, "Decompression failed: #{inspect(e)}"}
  end
end
