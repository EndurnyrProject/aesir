defmodule Mix.Tasks.Aesir.Import.MapFlags do
  @shortdoc "Imports the GvG, battleground and restricted-zone map flags of rAthena's mapflag scripts"
  @moduledoc """
  Replays the `mapflag` lines of the scripts rAthena loads for a mode
  (`npc/scripts_mapflags.conf`, then `npc/re/` or `npc/pre-re/scripts_mapflags.conf`)
  and writes the resulting `gvg`, `gvg_te`, `gvg_castle`, `gvg_te_castle`,
  `gvg_dungeon`, `battleground` and `restricted` zone flags to
  `apps/zone_server/priv/db/<mode>/map_flags/scripts.yml`.

      mix aesir.import.map_flags [<rathena_root>] [--mode re|pre-re]

  Lines apply in load order with the reference's setter rules: setting `pvp`
  clears every GvG flag and `battleground`; `gvg`/`gvg_te` clear `pvp` and
  `battleground`; a castle flag clears the other castle flag and `pvp`;
  `gvg_dungeon` clears `pvp`; `battleground` clears `pvp`, `gvg`,
  `gvg_dungeon` and `gvg_castle`. A value of `off` unsets the flag, and
  `restricted off` clears every zone. `restricted <n>` adds zone bit
  `1 << (n + 4)`; a `restricted` line without a number is skipped. `pvp` takes
  part in the replay but is not written: the PvP maps are curated in
  `priv/db/map_flags.yml`. A line naming a map the server does not load (one
  absent from `priv/maps.mcache`) is skipped, as the reference skips an
  unknown map. Rows are sorted by map name.
  """
  use Mix.Task

  import Bitwise

  alias Aesir.ZoneServer.Map.CacheLoader
  alias Mix.Tasks.Aesir.Import

  @written [:battleground, :gvg, :gvg_castle, :gvg_dungeon, :gvg_te, :gvg_te_castle]
  @gvg_flags [:gvg, :gvg_te, :gvg_dungeon, :gvg_castle, :gvg_te_castle]

  @impl Mix.Task
  @spec run([String.t()]) :: :ok
  def run(args) do
    {source_root, mode} = Import.parse!(args)

    {:ok, loaded} = CacheLoader.load_cache(Path.join(~w(apps zone_server priv maps.mcache)))

    replayed =
      source_root
      |> script_files(mode)
      |> Enum.flat_map(&File.stream!/1)
      |> replay()

    {known, unknown} = Map.split_with(replayed, fn {map, _state} -> Map.has_key?(loaded, map) end)
    rows = to_rows(known)

    out = Import.path("map_flags/scripts.yml", mode)
    File.mkdir_p!(Path.dirname(out))
    File.write!(out, Ymlr.document!(rows, sort_maps: true))
    Mix.shell().info("map_flags: #{length(rows)} maps")

    unless unknown == %{} do
      Mix.shell().info(
        "  skipped unloaded maps: #{unknown |> Map.keys() |> Enum.sort() |> Enum.join(", ")}"
      )
    end

    :ok
  end

  @doc "Replays mapflag script lines into each map's flag set and restricted zone mask."
  @spec replay(Enumerable.t()) :: %{String.t() => %{flags: MapSet.t(atom()), zone: integer()}}
  def replay(lines) do
    Enum.reduce(lines, %{}, fn line, maps ->
      case parse(line) do
        {map, flag, value} ->
          Map.update(maps, map, apply_flag(empty(), flag, value), &apply_flag(&1, flag, value))

        nil ->
          maps
      end
    end)
  end

  @doc "Shapes replayed maps into the output rows."
  @spec to_rows(%{String.t() => %{flags: MapSet.t(atom()), zone: integer()}}) :: [map()]
  def to_rows(maps) do
    maps
    |> Enum.sort()
    |> Enum.flat_map(fn {map, %{flags: flags, zone: zone}} ->
      written = flags |> MapSet.to_list() |> Enum.filter(&(&1 in @written)) |> Enum.sort()

      cond do
        written == [] and zone == 0 -> []
        zone == 0 -> [%{"map" => map, "flags" => Enum.map(written, &Atom.to_string/1)}]
        true -> [%{"map" => map, "flags" => Enum.map(written, &Atom.to_string/1), "zone" => zone}]
      end
    end)
  end

  defp empty, do: %{flags: MapSet.new(), zone: 0}

  defp parse(line) do
    line = line |> String.split("//", parts: 2) |> hd() |> String.trim_trailing()

    case String.split(line, "\t", parts: 4) do
      [w1, "mapflag", name | rest] ->
        case flag(String.downcase(name)) do
          nil -> nil
          flag -> {w1 |> String.split(",") |> hd(), flag, rest |> List.first() |> value()}
        end

      _other ->
        nil
    end
  end

  @flags Map.new(@written ++ [:pvp, :restricted], &{Atom.to_string(&1), &1})
  defp flag(name), do: Map.get(@flags, name)

  defp value(nil), do: nil

  defp value(w4) do
    w4 = String.trim(w4)
    if String.downcase(w4) == "off", do: :off, else: w4
  end

  defp apply_flag(state, :restricted, :off), do: %{state | zone: 0}

  defp apply_flag(state, :restricted, value) do
    case value && Integer.parse(value) do
      {zone, _rest} -> %{state | zone: bor(state.zone, 1 <<< (zone + 1) <<< 3)}
      _ -> state
    end
  end

  defp apply_flag(state, flag, :off), do: update(state, &MapSet.delete(&1, flag))

  defp apply_flag(state, :pvp, _value),
    do: update(state, &(&1 |> drop([:battleground | @gvg_flags]) |> MapSet.put(:pvp)))

  defp apply_flag(state, flag, _value) when flag in [:gvg, :gvg_te],
    do: update(state, &(&1 |> drop([:pvp, :battleground]) |> MapSet.put(flag)))

  defp apply_flag(state, :gvg_castle, _value),
    do: update(state, &(&1 |> drop([:gvg_te_castle, :pvp]) |> MapSet.put(:gvg_castle)))

  defp apply_flag(state, :gvg_te_castle, _value),
    do: update(state, &(&1 |> drop([:gvg_castle, :pvp]) |> MapSet.put(:gvg_te_castle)))

  defp apply_flag(state, :gvg_dungeon, _value),
    do: update(state, &(&1 |> drop([:pvp]) |> MapSet.put(:gvg_dungeon)))

  defp apply_flag(state, :battleground, _value) do
    update(state, fn flags ->
      flags |> drop([:pvp, :gvg, :gvg_dungeon, :gvg_castle]) |> MapSet.put(:battleground)
    end)
  end

  defp update(state, fun), do: %{state | flags: fun.(state.flags)}
  defp drop(flags, names), do: Enum.reduce(names, flags, &MapSet.delete(&2, &1))

  defp script_files(source_root, mode) do
    mode_dir = if mode == :renewal, do: "re", else: "pre-re"

    Enum.flat_map(
      ["npc/scripts_mapflags.conf", "npc/#{mode_dir}/scripts_mapflags.conf"],
      &conf_scripts(source_root, &1)
    )
  end

  defp conf_scripts(source_root, conf) do
    source_root
    |> Path.join(conf)
    |> File.stream!()
    |> Enum.flat_map(fn line ->
      case Regex.run(~r/^\s*npc:\s*(\S+)/, line) do
        [_, path] -> [Path.join(source_root, path)]
        nil -> []
      end
    end)
  end
end
