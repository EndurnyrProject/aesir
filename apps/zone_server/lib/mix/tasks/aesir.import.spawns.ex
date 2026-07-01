defmodule Mix.Tasks.Aesir.Import.Spawns do
  @shortdoc "Imports rAthena mob-spawn scripts into priv/db/spawns/*.yml"
  @moduledoc """
  One-time importer: converts the rAthena mob-spawn scripts listed in
  `npc/re/scripts_monsters.conf` into our own-schema YAML under
  `apps/zone_server/priv/db/spawns/`, one file per source map.

      mix aesir.import.spawns [<rathena_root>]

  `<rathena_root>` defaults to `../rathena`. Only `monster` lines are imported
  (`boss_monster` is skipped - no MVP model yet). Every spawn is checked against
  the live `maps.mcache` and `Mobs`: a spawn on an unknown map, referencing an
  unknown mob id, or a fixed single-cell spawn on a non-walkable cell is dropped
  at import so `Spawns.load` stays boot-safe. The run prints how many spawns were
  written, across how many maps, and how many were skipped, by reason. Run only
  when syncing rAthena.
  """
  use Mix.Task

  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Mmo.MobManagement.Mobs
  alias Aesir.ZoneServer.Mmo.MobManagement.Spawns.Importer

  @out_dir Path.join(~w(apps zone_server priv db spawns))
  @conf Path.join(~w(npc re scripts_monsters.conf))

  @impl Mix.Task
  def run(args) do
    rathena = List.first(args) || "../rathena"
    boot_map_cache!()

    files = spawn_files(rathena)
    {parsed, errors} = parse_files(files)
    Enum.each(errors, fn {file, line, reason} -> report_error(file, line, reason) end)

    spawns = Enum.map(parsed, &resolve_mob/1)
    classified = Enum.map(spawns, fn spawn -> {spawn, skip_reason(spawn)} end)
    kept = for {spawn, nil} <- classified, do: spawn
    skipped = for {spawn, reason} <- classified, not is_nil(reason), do: {spawn, reason}

    write!(kept)
    report(files, spawns, kept, skipped, errors)
  end

  @spec boot_map_cache!() :: :ok
  defp boot_map_cache! do
    :ets.new(:map_cache, [:set, :public, :named_table, read_concurrency: true])
    MapCache.init()
  end

  @spec spawn_files(Path.t()) :: [Path.t()]
  defp spawn_files(rathena) do
    conf = Path.join(rathena, @conf)

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

  @spec parse_files([Path.t()]) :: {[Importer.spawn_map()], [{Path.t(), pos_integer(), term()}]}
  defp parse_files(files) do
    Enum.reduce(files, {[], []}, fn file, {spawns, errors} ->
      {file_spawns, file_errors} = parse_file(file)
      {spawns ++ file_spawns, errors ++ file_errors}
    end)
  end

  @spec parse_file(Path.t()) :: {[Importer.spawn_map()], [{Path.t(), pos_integer(), term()}]}
  defp parse_file(file) do
    file
    |> File.read!()
    |> then(&:binary.split(&1, "\n", [:global]))
    |> Enum.with_index(1)
    |> Enum.reduce({[], []}, fn {line, number}, {spawns, errors} ->
      case Importer.parse_line(line) do
        {:ok, spawn} -> {[spawn | spawns], errors}
        :skip -> {spawns, errors}
        {:error, reason} -> {spawns, [{file, number, reason} | errors]}
      end
    end)
    |> then(fn {spawns, errors} -> {Enum.reverse(spawns), Enum.reverse(errors)} end)
  end

  @spec resolve_mob(Importer.spawn_map()) :: Importer.spawn_map()
  defp resolve_mob(%{"spawns" => [%{"mob" => mob} = spawn]} = spawn_map) when is_binary(mob) do
    resolved =
      case Mobs.by_name(mob) do
        {:ok, %{id: id}} -> id
        :error -> mob
      end

    %{spawn_map | "spawns" => [%{spawn | "mob" => resolved}]}
  end

  defp resolve_mob(spawn_map), do: spawn_map

  @spec skip_reason(Importer.spawn_map()) :: atom() | nil
  defp skip_reason(%{"map" => map, "spawns" => [%{"mob" => mob, "area" => area}]}) do
    %{"x" => x, "y" => y, "xs" => xs, "ys" => ys} = area

    cond do
      not map_known?(map) -> :unknown_map
      not mob_known?(mob) -> :unknown_mob
      blocked_cell?(map, x, y, xs, ys) -> :blocked_cell
      true -> nil
    end
  end

  @spec map_known?(String.t()) :: boolean()
  defp map_known?(map), do: match?({:ok, _}, MapCache.get(map))

  @spec mob_known?(integer() | String.t()) :: boolean()
  defp mob_known?(mob) when is_integer(mob), do: match?({:ok, _}, Mobs.by_id(mob))
  defp mob_known?(_mob), do: false

  @spec blocked_cell?(String.t(), integer(), integer(), integer(), integer()) :: boolean()
  defp blocked_cell?(map, x, y, 0, 0) when {x, y} != {0, 0}, do: not MapCache.walkable?(map, x, y)
  defp blocked_cell?(_map, _x, _y, _xs, _ys), do: false

  @spec write!([Importer.spawn_map()]) :: :ok
  defp write!(kept) do
    File.mkdir_p!(@out_dir)
    clear_existing!()

    kept
    |> Enum.group_by(& &1["map"])
    |> Enum.each(fn {map, spawn_maps} ->
      spawns = Enum.flat_map(spawn_maps, & &1["spawns"])
      entry = [%{"map" => map, "spawns" => spawns}]
      File.write!(Path.join(@out_dir, "#{map}.yml"), Ymlr.document!(entry))
    end)
  end

  @spec clear_existing!() :: :ok
  defp clear_existing! do
    File.rm_rf!(Path.join(@out_dir, ".cache"))
    @out_dir |> Path.join("*.yml") |> Path.wildcard() |> Enum.each(&File.rm!/1)
    :ok
  end

  @spec report([Path.t()], [Importer.spawn_map()], [Importer.spawn_map()], skipped, errors) :: :ok
        when skipped: [{Importer.spawn_map(), atom()}],
             errors: [{Path.t(), pos_integer(), term()}]
  defp report(files, spawns, kept, skipped, errors) do
    maps = kept |> Enum.map(& &1["map"]) |> Enum.uniq() |> length()
    Mix.shell().info("spawns: parsed #{length(spawns)} from #{length(files)} files")
    Mix.shell().info("  wrote #{length(kept)} across #{maps} maps -> #{@out_dir}")

    unless skipped == [] do
      freq = skipped |> Enum.map(fn {_spawn, reason} -> reason end) |> Enum.frequencies()
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
