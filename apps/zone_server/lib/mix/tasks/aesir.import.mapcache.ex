defmodule Mix.Tasks.Aesir.Import.Mapcache do
  @shortdoc "Generates priv/maps.mcache from a directory of .gat files"
  @moduledoc """
  Builds an rAthena-compatible map cache (`maps.mcache`) from a directory of
  client `.gat` files.

      mix aesir.import.mapcache [<gat_dir>] [<output_path>]

  `<gat_dir>` defaults to `apps/zone_server/priv/maps`.
  `<output_path>` defaults to `apps/zone_server/priv/maps.mcache`.

  Each `.gat` is parsed by `Aesir.ZoneServer.Map.GatLoader` and its walkability
  cells are zlib-compressed into the cache the zone server loads at boot
  (`Aesir.ZoneServer.Map.MapCache`). Maps that fail to parse are logged and
  skipped; the run fails only when no valid `.gat` files are found. Overwrites
  the existing cache - run only when syncing client map data.
  """
  use Mix.Task

  alias Aesir.ZoneServer.Map.Loader

  @gat_dir Path.join(~w(apps zone_server priv maps))
  @out Path.join(~w(apps zone_server priv maps.mcache))

  @impl Mix.Task
  def run(args) do
    {gat_dir, out} = paths(args)
    ensure_gat_dir!(gat_dir)

    case Loader.create_cache_from_gat_files(gat_dir, out) do
      :ok ->
        Mix.shell().info("mapcache: #{gat_count(gat_dir)} gat files -> #{out}")

      {:error, reason} ->
        Mix.raise("failed to build map cache: #{reason}")
    end
  end

  @spec paths([String.t()]) :: {Path.t(), Path.t()}
  defp paths([gat_dir, out | _]), do: {gat_dir, out}
  defp paths([gat_dir]), do: {gat_dir, @out}
  defp paths([]), do: {@gat_dir, @out}

  @spec ensure_gat_dir!(Path.t()) :: :ok
  defp ensure_gat_dir!(gat_dir) do
    unless File.dir?(gat_dir) do
      Mix.raise("gat directory not found: #{gat_dir}")
    end

    :ok
  end

  @spec gat_count(Path.t()) :: non_neg_integer()
  defp gat_count(gat_dir) do
    gat_dir |> Path.join("*.gat") |> Path.wildcard() |> length()
  end
end
