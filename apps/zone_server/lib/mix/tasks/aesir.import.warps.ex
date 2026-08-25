defmodule Mix.Tasks.Aesir.Import.Warps do
  @shortdoc "Imports selected rAthena warps into mode-scoped YAML"
  @moduledoc """
  Converts enabled warp scripts from shared `npc/scripts_warps.conf` and
  selected `npc/{re,pre-re}/scripts_warps.conf` into
  `apps/zone_server/priv/db/<mode>/warps/*.yml`.

      mix aesir.import.warps [<rathena_root>] [--mode re|pre-re]

  `<rathena_root>` defaults to `../rathena`. Every warp is checked against the
  live `maps.mcache`: a warp whose source or destination map is missing, or
  whose own cell is non-walkable, is dropped at import so the data files stay
  clean (`Aesir.ZoneServer.Npc.Warps.sanitize/1` drops any that still slip
  through at runtime, with a warning). The run prints how
  many warps were written and how many were skipped, by reason. Run only when
  syncing rAthena.
  """
  use Mix.Task

  alias Mix.Tasks.Aesir.Import

  alias Aesir.ZoneServer.Db.Layout
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Npc.Warps.Importer

  @shared_conf Path.join(~w(npc scripts_warps.conf))
  @mode_conf "scripts_warps.conf"

  @impl Mix.Task
  def run(args) do
    {rathena, mode} = Import.parse!(args)
    out_dir = Import.path("warps", mode)
    boot_map_cache!()

    files = warp_files(rathena, mode)
    {warps, errors} = parse_files(files)
    Enum.each(errors, fn {file, line, reason} -> report_error(file, line, reason) end)

    classified = Enum.map(warps, fn warp -> {warp, skip_reason(warp)} end)
    kept = for {warp, nil} <- classified, do: warp
    skipped = for {warp, reason} <- classified, not is_nil(reason), do: {warp, reason}

    write!(kept, out_dir)
    report(files, warps, kept, skipped, errors, out_dir)
  end

  @spec boot_map_cache!() :: :ok
  defp boot_map_cache! do
    :ets.new(:map_cache, [:set, :public, :named_table, read_concurrency: true])
    MapCache.init()
  end

  @spec warp_files(Path.t(), Layout.mode()) :: [Path.t()]
  defp warp_files(rathena, mode) do
    mode_conf = Path.join(["npc", Layout.mode_dir(mode), @mode_conf])

    [@shared_conf, mode_conf]
    |> Enum.map(&Path.join(rathena, &1))
    |> Enum.flat_map(&conf_files(&1, rathena))
    |> Enum.uniq()
  end

  @spec conf_files(Path.t(), Path.t()) :: [Path.t()]
  defp conf_files(conf, rathena) do
    conf
    |> File.read!()
    |> String.split("\n")
    |> Enum.flat_map(&conf_entry(&1, rathena))
  end

  @spec conf_entry(String.t(), Path.t()) :: [Path.t()]
  defp conf_entry(line, rathena) do
    case Regex.run(~r/^\s*npc:\s*(\S+\.txt)\s*$/, line) do
      [_, rel] -> [Path.join(rathena, rel)]
      nil -> []
    end
  end

  @spec parse_files([Path.t()]) :: {[Importer.warp_map()], [{Path.t(), pos_integer(), term()}]}
  defp parse_files(files) do
    Enum.reduce(files, {[], []}, fn file, {warps, errors} ->
      {file_warps, file_errors} = parse_file(file)
      {warps ++ file_warps, errors ++ file_errors}
    end)
  end

  @spec parse_file(Path.t()) :: {[Importer.warp_map()], [{Path.t(), pos_integer(), term()}]}
  defp parse_file(file) do
    file
    |> File.read!()
    |> then(&:binary.split(&1, "\n", [:global]))
    |> Enum.with_index(1)
    |> Enum.reduce({[], []}, fn {line, number}, {warps, errors} ->
      case Importer.parse_line(line) do
        {:ok, warp} -> {[warp | warps], errors}
        :skip -> {warps, errors}
        {:error, reason} -> {warps, [{file, number, reason} | errors]}
      end
    end)
    |> then(fn {warps, errors} -> {Enum.reverse(warps), Enum.reverse(errors)} end)
  end

  @spec skip_reason(Importer.warp_map()) :: atom() | nil
  defp skip_reason(%{
         "map" => map,
         "x" => x,
         "y" => y,
         "xs" => xs,
         "ys" => ys,
         "to" => %{"map" => to_map}
       }) do
    cond do
      not map_known?(map) -> :unknown_source_map
      not span_walkable?(map, x, y, xs, ys) -> :blocked_source_cell
      not map_known?(to_map) -> :unknown_dest_map
      true -> nil
    end
  end

  @spec map_known?(String.t()) :: boolean()
  defp map_known?(map), do: match?({:ok, _}, MapCache.get(map))

  # A warp fires from anywhere in its `(2*xs+1) x (2*ys+1)` trigger box, so it is
  # reachable as long as at least one cell in that box is walkable. Requiring the
  # exact centre cell to be walkable wrongly drops warps whose centre sits on a
  # door threshold / wall while the approach cells are open (e.g. prontera prt08).
  @spec span_walkable?(String.t(), integer(), integer(), integer(), integer()) :: boolean()
  defp span_walkable?(map, x, y, xs, ys) do
    Enum.any?((y - ys)..(y + ys), fn cy ->
      Enum.any?((x - xs)..(x + xs), fn cx -> MapCache.walkable?(map, cx, cy) end)
    end)
  end

  @spec write!([Importer.warp_map()], Path.t()) :: :ok
  defp write!(kept, out_dir) do
    File.mkdir_p!(out_dir)
    clear_existing!(out_dir)

    kept
    |> Enum.group_by(& &1["map"])
    |> Enum.each(fn {map, warps} ->
      File.write!(Path.join(out_dir, "#{map}.yml"), Ymlr.document!(warps))
    end)
  end

  @spec clear_existing!(Path.t()) :: :ok
  defp clear_existing!(out_dir) do
    File.rm_rf!(Path.join(out_dir, ".cache"))
    out_dir |> Path.join("*.yml") |> Path.wildcard() |> Enum.each(&File.rm!/1)
    :ok
  end

  @spec report(
          [Path.t()],
          [Importer.warp_map()],
          [Importer.warp_map()],
          skipped,
          errors,
          Path.t()
        ) :: :ok
        when skipped: [{Importer.warp_map(), atom()}],
             errors: [{Path.t(), pos_integer(), term()}]
  defp report(files, warps, kept, skipped, errors, out_dir) do
    maps = kept |> Enum.map(& &1["map"]) |> Enum.uniq() |> length()
    Mix.shell().info("warps: parsed #{length(warps)} from #{length(files)} files")
    Mix.shell().info("  wrote #{length(kept)} across #{maps} maps -> #{out_dir}")

    unless skipped == [] do
      freq = skipped |> Enum.map(fn {_warp, reason} -> reason end) |> Enum.frequencies()
      Mix.shell().info("  skipped #{length(skipped)} to keep boot safe: #{inspect(freq)}")
    end

    unless errors == [] do
      Mix.shell().error("  #{length(errors)} malformed lines (listed above)")
    end

    :ok
  end

  @spec report_error(Path.t(), pos_integer(), term()) :: :ok
  defp report_error(file, line, reason) do
    Mix.shell().error("  malformed #{file}:#{line} #{inspect(reason)}")
  end
end
