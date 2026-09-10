defmodule Aesir.ZoneServer.Map.Loader do
  @moduledoc """
  Unified map loader that supports both GAT files and rAthena map cache.
  """

  require Logger

  alias Aesir.ZoneServer.Map.GatLoader
  alias Aesir.ZoneServer.Map.MapData

  @doc """
  Creates a map cache file from GAT files in a directory.
  This can be used to generate a rAthena-compatible map cache.
  """
  @spec create_cache_from_gat_files(String.t(), String.t()) :: :ok | {:error, String.t()}
  def create_cache_from_gat_files(gat_directory, output_cache_path) do
    case File.ls(gat_directory) do
      {:ok, files} ->
        gat_files = Enum.filter(files, &String.ends_with?(&1, ".gat"))

        maps =
          Enum.reduce(gat_files, [], fn file, acc ->
            path = Path.join(gat_directory, file)
            map_name = Path.basename(file, ".gat")

            # credo:disable-for-next-line Credo.Check.Refactor.Nesting
            case GatLoader.load_file(path) do
              {:ok, map_data} ->
                Logger.debug("Loaded GAT file: #{map_name}")
                [{map_name, map_data} | acc]

              {:error, reason} ->
                Logger.error("Failed to load GAT file #{file}: #{reason}")
                acc
            end
          end)

        if maps != [] do
          write_cache_file(output_cache_path, maps)
        else
          {:error, "No valid GAT files found"}
        end

      {:error, reason} ->
        {:error, "Failed to list GAT directory: #{inspect(reason)}"}
    end
  end

  # Writes the map cache to a path the server itself derives from priv.
  # sobelow_skip ["Traversal.FileModule"]
  defp write_cache_file(path, maps) do
    map_count = length(maps)
    cache_data = build_cache_binary(maps, map_count)

    case File.write(path, cache_data) do
      :ok ->
        Logger.info("Created map cache with #{map_count} maps at #{path}")
        :ok

      {:error, reason} ->
        {:error, "Failed to write cache file: #{inspect(reason)}"}
    end
  end

  defp build_cache_binary(maps, map_count) do
    maps_binary =
      Enum.reduce(maps, <<>>, fn {map_name, map_data}, acc ->
        acc <> build_map_entry(map_name, map_data)
      end)

    file_size = 8 + byte_size(maps_binary)

    <<file_size::little-32, map_count::little-16, 0::16>> <> maps_binary
  end

  defp build_map_entry(map_name, %MapData{xs: width, ys: height, cells: cells}) do
    compressed = :zlib.compress(cells)

    # Build map name (padded to 12 bytes)
    name_binary =
      String.pad_trailing(map_name, 12, <<0>>)
      |> :erlang.binary_to_list()
      |> Enum.take(12)
      |> :erlang.list_to_binary()

    <<name_binary::binary-12, width::little-signed-16, height::little-signed-16,
      byte_size(compressed)::little-signed-32, compressed::binary>>
  end
end
