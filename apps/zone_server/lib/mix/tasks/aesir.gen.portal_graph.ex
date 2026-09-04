defmodule Mix.Tasks.Aesir.Gen.PortalGraph do
  @shortdoc "Generates the mode-scoped portal graph caches"
  @moduledoc """
  Rebuilds the committed portal graph cache from the shipped warp databases and
  `priv/maps.mcache`.

      mix aesir.gen.portal_graph
      mix aesir.gen.portal_graph --mode re
      mix aesir.gen.portal_graph --mode pre-re

  Without `--mode`, both renewal and pre-renewal graphs are generated. Pass a
  mode to rebuild only that graph.
  """
  use Mix.Task

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Db.Layout
  alias Aesir.ZoneServer.Db.Source
  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Mmo.Woe.CastleDb
  alias Aesir.ZoneServer.Navigation.Exclusions
  alias Aesir.ZoneServer.Navigation.PortalGraph
  alias Aesir.ZoneServer.Navigation.PortalGraph.Builder
  alias Aesir.ZoneServer.Npc.Warps

  @mode_cache_keys [GameMode, CastleDb, Exclusions, PortalGraph, Warps]

  @impl Mix.Task
  def run(args) do
    modes = parse_modes!(args)
    previous_mode = Application.get_env(:commons, :game_mode)

    try do
      init_map_cache()
      Enum.each(modes, &generate/1)
    after
      restore_mode(previous_mode)
    end
  end

  @spec parse_modes!([String.t()]) :: [Layout.mode()]
  defp parse_modes!(args) do
    {options, positional, invalid} = OptionParser.parse(args, strict: [mode: :string])

    unless positional == [] and invalid == [] do
      Mix.raise("invalid arguments: #{inspect(positional ++ invalid)}")
    end

    case Keyword.get(options, :mode, "all") do
      "all" -> [:renewal, :pre_renewal]
      "re" -> [:renewal]
      "pre-re" -> [:pre_renewal]
      mode -> Mix.raise("invalid --mode #{inspect(mode)}; expected all, re or pre-re")
    end
  end

  @spec init_map_cache() :: :ok
  defp init_map_cache do
    table = EtsTable.table_for(:map_cache)

    if :ets.whereis(table) == :undefined do
      :ets.new(table, [:set, :public, :named_table, read_concurrency: true])
    end

    MapCache.init()
  end

  @spec generate(Layout.mode()) :: :ok
  defp generate(mode) do
    Application.put_env(:commons, :game_mode, mode)
    Enum.each(@mode_cache_keys, &:persistent_term.erase/1)
    :ok = Warps.reload()

    graph = Builder.load(force: true)
    output = Path.join([Source.base_dir("warps"), ".cache", "portal_graph.etf"])

    Mix.shell().info(
      "portal graph: #{mode_name(mode)} #{map_size(graph.portals)} portals -> #{output}"
    )
  end

  @spec mode_name(Layout.mode()) :: String.t()
  defp mode_name(:renewal), do: "renewal"
  defp mode_name(:pre_renewal), do: "pre-renewal"

  @spec restore_mode(nil | Layout.mode()) :: :ok
  defp restore_mode(nil), do: Application.delete_env(:commons, :game_mode)
  defp restore_mode(mode), do: Application.put_env(:commons, :game_mode, mode)
end
