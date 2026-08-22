defmodule Aesir.ZoneServer.Navigation.Exclusions do
  @moduledoc """
  Maps the navigation router must not route into or through.

  Split in two tiers because the world graph is built once and cached, while
  `Map.MapFlags` keeps a runtime ETS overlay that WoE writes `:gvg` into long
  after that build:

    * `statically_excluded?/1` answers at **graph-build** time - castle maps,
      the hostile `pvp`/`gvg_castle` flags, and the hand-authored
      `priv/db/navigation.yml` denylist. These maps never enter the graph at
      all, so no route can reach them.
    * `runtime_excluded/0` answers **per routing request** and returns only the
      dynamic delta - the maps currently toggled hostile since boot. Without
      it a route could cross a castle that turned hostile after the graph was
      built.

  The tiers are deliberately **not** unioned: the router skips the runtime set
  while walking a graph the static set was already removed from, so neither
  return value is the complete exclusion set on its own.
  """

  import Aesir.ZoneServer.EtsTable, only: [table_for: 1]

  alias Aesir.ZoneServer.Db.Source
  alias Aesir.ZoneServer.Map.MapFlags.StaticFlags
  alias Aesir.ZoneServer.Mmo.Woe.CastleDb

  @pt_key __MODULE__
  @hostile_flags [:gvg_castle, :pvp, :pvp_noparty, :pvp_noguild]

  @typedoc "A map name."
  @type map_name :: String.t()

  @doc "Returns the static-tier source paths so dependent caches can invalidate."
  @spec sources() :: [Path.t()]
  def sources do
    ["navigation.yml", "map_flags.yml", "castles"]
    |> Enum.flat_map(&Source.sources/1)
  end

  @doc "Returns whether a map is excluded when the navigation graph is built."
  @spec statically_excluded?(map_name()) :: boolean()
  def statically_excluded?(map_name), do: MapSet.member?(static_excluded(), map_name)

  @doc "Returns maps currently marked hostile by the runtime WoE overlay."
  @spec runtime_excluded() :: MapSet.t(map_name())
  def runtime_excluded do
    :map_flag_overrides
    |> table_for()
    |> :ets.match_object({{:_, :gvg}, true})
    |> MapSet.new(fn {{map_name, :gvg}, true} -> map_name end)
  end

  @doc "Rebuilds the static exclusion set after navigation data changes."
  @spec reload() :: :ok
  def reload do
    :persistent_term.put(@pt_key, build_static())
    :ok
  end

  @spec static_excluded() :: MapSet.t(map_name())
  defp static_excluded do
    case :persistent_term.get(@pt_key, nil) do
      nil ->
        excluded = build_static()
        :persistent_term.put(@pt_key, excluded)
        excluded

      excluded ->
        excluded
    end
  end

  @spec build_static() :: MapSet.t(map_name())
  defp build_static do
    castle_maps = CastleDb.all() |> MapSet.new(& &1.map)

    flagged_maps =
      StaticFlags.load()
      |> Enum.filter(fn {_map_name, flags} ->
        Enum.any?(@hostile_flags, &Map.get(flags, &1, false))
      end)
      |> MapSet.new(fn {map_name, _flags} -> map_name end)

    MapSet.union(castle_maps, flagged_maps)
    |> MapSet.union(navigation_maps())
  end

  @spec navigation_maps() :: MapSet.t(map_name())
  defp navigation_maps do
    "navigation.yml"
    |> Source.sources()
    |> Enum.flat_map(&load_navigation_file!/1)
    |> MapSet.new()
  end

  @spec load_navigation_file!(Path.t()) :: [map_name()]
  defp load_navigation_file!(path) do
    case YamlElixir.read_from_file!(path) do
      maps when is_list(maps) -> Enum.map(maps, &validate_map_name!/1)
      _ -> raise ArgumentError, "navigation.yml must be a list of map names"
    end
  end

  @spec validate_map_name!(term()) :: map_name()
  defp validate_map_name!(map_name) when is_binary(map_name), do: map_name

  defp validate_map_name!(map_name) do
    raise ArgumentError, "navigation.yml map name must be a string, got #{inspect(map_name)}"
  end
end
