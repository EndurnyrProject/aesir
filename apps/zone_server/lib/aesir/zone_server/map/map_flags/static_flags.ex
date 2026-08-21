defmodule Aesir.ZoneServer.Map.MapFlags.StaticFlags do
  @moduledoc """
  Loads per-map PvP flags from `priv/db/map_flags.yml` into a static index.

  Returns `%{map_name => %{flag => true}}`. `MapFlags.build_static/0` merges
  this over the CastleDb-derived WoE flags, so boot-time PvP map data loads
  without a GM toggle. The file is parsed with `YamlElixir.read_from_file!/1`:
  a missing file raises `YamlElixir.FileNotFoundError` and malformed YAML
  raises `YamlElixir.ParsingError` — load fails loudly at boot. Unknown flags,
  non-map rows, and non-binary map names raise `ArgumentError`; the static
  loader is deliberately stricter than the inert runtime overlay, which lets
  live toggles ignore typos.
  """

  alias Aesir.ZoneServer.Db.Source
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.DataLoader

  @typedoc "A static per-map flag index: map name => flag => `true`."
  @type static_index :: %{MapFlags.map_name() => %{MapFlags.flag() => true}}

  @doc """
  Loads `priv/db/map_flags.yml` from the zone server's app dir.
  """
  @spec load() :: static_index()
  def load do
    "map_flags.yml"
    |> Source.sources()
    |> Enum.flat_map(&YamlElixir.read_from_file!/1)
    |> DataLoader.merge_by_key(& &1["map"])
    |> to_index!()
  end

  @doc """
  Loads a map-flags YAML file into a static index.

  The file is a list of `%{"map" => name, "flags" => [...]}` rows. Each row's
  flags are validated against `MapFlags.whitelist()` and fail loudly on an
  unknown flag; repeated rows for one map are merged into a single flag set.
  """
  @spec load(Path.t()) :: static_index()
  def load(path) do
    path
    |> YamlElixir.read_from_file!()
    |> to_index!()
  end

  @spec to_index!([map()]) :: static_index()
  defp to_index!(rows) when is_list(rows) do
    Enum.reduce(rows, %{}, fn row, index -> merge_row(index, row_flags!(row)) end)
  end

  defp to_index!(_rows) do
    raise ArgumentError, "map_flags.yml must be a list of {map:, flags:} rows"
  end

  @spec row_flags!(term()) :: {MapFlags.map_name(), [MapFlags.flag()]}
  defp row_flags!(row) when is_map(row) do
    map_name = Map.fetch!(row, "map")

    if is_binary(map_name) do
      {map_name, validate_flags!(Map.fetch!(row, "flags"))}
    else
      raise ArgumentError, "map_flags.yml row map name must be a string, got #{inspect(map_name)}"
    end
  end

  defp row_flags!(_row) do
    raise ArgumentError, "map_flags.yml row must be a %{map:, flags:} row"
  end

  @spec validate_flags!(term()) :: [MapFlags.flag()]
  defp validate_flags!(flags) when is_list(flags) do
    lookup = Map.new(MapFlags.whitelist(), fn flag -> {Atom.to_string(flag), flag} end)
    Enum.map(flags, fn flag -> validate_flag!(flag, lookup) end)
  end

  defp validate_flags!(_flags) do
    raise ArgumentError, "map_flags.yml row flags must be a list of flags"
  end

  @spec validate_flag!(term(), %{String.t() => MapFlags.flag()}) :: MapFlags.flag()
  defp validate_flag!(flag, lookup) when is_binary(flag) do
    case Map.fetch(lookup, flag) do
      {:ok, valid_flag} -> valid_flag
      :error -> raise ArgumentError, "unknown map flag #{inspect(flag)} in map_flags.yml"
    end
  end

  defp validate_flag!(flag, _lookup) do
    raise ArgumentError, "map_flags.yml flag must be a string, got #{inspect(flag)}"
  end

  @spec merge_row(static_index(), {MapFlags.map_name(), [MapFlags.flag()]}) :: static_index()
  defp merge_row(index, {map_name, flags}) do
    flags_map = Map.new(flags, &{&1, true})
    Map.update(index, map_name, flags_map, fn existing -> Map.merge(existing, flags_map) end)
  end
end
