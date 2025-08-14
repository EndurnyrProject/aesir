defmodule Aesir.ZoneServer.Map.GatLoader do
  @moduledoc """
  GAT (Ground Altitude) file loader for Ragnarok Online maps.
  GAT files contain terrain information for each cell in a map.
  """
  require Logger

  alias Aesir.ZoneServer.Map.MapData

  @gat_header_size 14
  @cell_data_size 20

  @doc """
  Loads a GAT file and returns a MapData structure.

  GAT file format:
  - Bytes 0-5: Magic "GRAT\x01\x01" 
  - Bytes 6-9: Width (xs) as int32
  - Bytes 10-13: Height (ys) as int32
  - Bytes 14+: Cell data (20 bytes per cell)
    - Bytes 0-3: Height for each corner (4 floats, 16 bytes total)
    - Bytes 16-19: Cell type (uint32)
  """
  @spec load_file(String.t()) :: {:ok, MapData.t()} | {:error, String.t()}
  def load_file(file_path) do
    map_name = Path.basename(file_path, ".gat")

    case File.read(file_path) do
      {:ok, data} ->
        parse_gat(data, map_name)

      {:error, reason} ->
        {:error, "Failed to read GAT file: #{inspect(reason)}"}
    end
  end

  @doc """
  Parses GAT binary data into a MapData structure.
  """
  @spec parse_gat(binary(), String.t()) :: {:ok, MapData.t()} | {:error, String.t()}
  def parse_gat(data, map_name) when byte_size(data) >= @gat_header_size do
    case data do
      # Check for GRAT magic header
      <<"GRAT", 0x01, 0x01, xs::little-32, ys::little-32, cells_data::binary>> ->
        parse_cells(cells_data, map_name, xs, ys)

      # Alternative: some GAT files might not have magic header
      <<_magic::binary-6, xs::little-32, ys::little-32, cells_data::binary>> ->
        Logger.warning(
          "GAT file for #{map_name} has non-standard header, attempting to parse anyway"
        )

        parse_cells(cells_data, map_name, xs, ys)

      _ ->
        {:error, "Invalid GAT file format"}
    end
  end

  def parse_gat(_, _), do: {:error, "GAT file too small"}

  defp parse_cells(cells_data, map_name, width, height) do
    expected_cells = width * height
    expected_size = expected_cells * @cell_data_size

    if byte_size(cells_data) < expected_size do
      {:error,
       "Insufficient cell data: expected #{expected_size} bytes, got #{byte_size(cells_data)}"}
    else
      map = MapData.new(map_name, width, height)

      cells =
        parse_cell_list(cells_data, expected_cells, [])
        |> Enum.reverse()

      gat_binary = :erlang.list_to_binary(cells)
      updated_map = MapData.load_from_gat_binary(map, gat_binary)

      {:ok, updated_map}
    end
  end

  defp parse_cell_list(_, 0, acc), do: acc

  defp parse_cell_list(data, remaining, acc) do
    case data do
      # Each cell: 4 height floats (16 bytes) + type (4 bytes) = 20 bytes
      <<_h1::little-float-32, _h2::little-float-32, _h3::little-float-32, _h4::little-float-32,
        cell_type::little-32, rest::binary>> ->
        parse_cell_list(rest, remaining - 1, [cell_type | acc])

      _ ->
        # If we can't parse, fill remaining with walls
        List.duplicate(1, remaining) ++ acc
    end
  end
end
