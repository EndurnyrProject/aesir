defmodule Aesir.ZoneServer.Npc.Transpiler do
  @moduledoc """
  Orchestrates the rAthena NPC transpile: file parsing, duplicate/function
  grouping, sprite resolution, manifest-driven regen decisions, codegen and
  file output.

  Driven by `mix aesir.import.npcs`; returns a result map the task renders
  into `_transpile_report.md`. Per-entry problems never abort the run — they
  are collected as failures.
  """

  alias Aesir.ZoneServer.Npc.Transpiler.Analyzer
  alias Aesir.ZoneServer.Npc.Transpiler.Codegen
  alias Aesir.ZoneServer.Npc.Transpiler.FileParser
  alias Aesir.ZoneServer.Npc.Transpiler.Manifest
  alias Aesir.ZoneServer.Npc.Transpiler.ModuleName
  alias Aesir.ZoneServer.Npc.Transpiler.Parser
  alias Aesir.ZoneServer.Npc.Transpiler.Resolver

  @generic_sprite 46
  @manifest_rel "priv/npc_transpile/manifest.json"

  @type result :: map()

  @doc """
  Runs the transpile.

  Options:
  - `:only` — glob (relative to `npc/re/`) limiting the source files
  - `:out_root` — zone_server app root the output paths hang off
    (default `apps/zone_server`)
  """
  @spec run(Path.t(), keyword()) :: result()
  def run(rathena_root, opts \\ []) do
    out_root = Keyword.get(opts, :out_root, Path.join("apps", "zone_server"))
    manifest_path = Path.join(out_root, @manifest_rel)
    manifest = Manifest.load(manifest_path)
    sprites = load_sprites(rathena_root)

    entries = parse_files(rathena_root, Keyword.get(opts, :only))
    {functions, scripts, duplicates, skipped, file_errors} = partition(entries)

    dup_index = Enum.group_by(duplicates, & &1.source)
    {fn_modules, fn_units} = function_units(functions)
    script_units = script_units(scripts, dup_index, sprites)

    state = %{
      manifest: manifest,
      out_root: out_root,
      functions: fn_modules,
      written: [],
      skipped: 0,
      conflicts: [],
      failures: [],
      stubs: %{},
      unresolved_sprites: MapSet.new()
    }

    state = Enum.reduce(fn_units ++ script_units, state, &process_unit/2)

    Manifest.save(state.manifest, manifest_path)

    orphans = Map.keys(dup_index) -- Enum.map(scripts, & &1.name)

    %{
      written: Enum.reverse(state.written),
      skipped: state.skipped,
      conflicts: Enum.reverse(state.conflicts),
      failures: Enum.reverse(state.failures) ++ file_errors,
      stubs: state.stubs,
      unresolved_sprites: Enum.sort(state.unresolved_sprites),
      skipped_types: Enum.frequencies_by(skipped, & &1.type),
      orphan_duplicates: orphans,
      totals: %{
        scripts: length(scripts),
        functions: length(functions),
        duplicates: length(duplicates)
      }
    }
  end

  # -- collection --------------------------------------------------------------

  defp load_sprites(root) do
    case Resolver.load_sprites(Path.join([root, "src", "map", "npc.hpp"])) do
      {:ok, sprites} -> sprites
      {:error, _} -> %{}
    end
  end

  defp parse_files(root, only) do
    base = Path.join([root, "npc", "re"])
    files = base |> Path.join("**/*.txt") |> Path.wildcard()

    files =
      case only do
        nil -> files
        glob -> base |> Path.join(glob) |> Path.wildcard() |> MapSet.new() |> intersect(files)
      end

    files
    |> Enum.sort()
    |> Enum.flat_map(fn file ->
      {:ok, entries} = FileParser.parse(File.read!(file), Path.relative_to(file, base))
      entries
    end)
  end

  defp intersect(allowed, files), do: Enum.filter(files, &MapSet.member?(allowed, &1))

  defp partition(entries) do
    groups = Enum.group_by(entries, & &1.kind)

    {
      Map.get(groups, :function, []),
      Map.get(groups, :script, []) ++ Map.get(groups, :floating, []),
      Map.get(groups, :duplicate, []),
      Map.get(groups, :skipped, []),
      groups |> Map.get(:error, []) |> Enum.map(&{:file, &1.file, &1.line, &1.reason})
    }
  end

  # -- unit building -----------------------------------------------------------

  defp function_units(functions) do
    units =
      functions
      |> dedupe_slugs(fn entry, slug ->
        %{
          entry: entry,
          kind: :function,
          module: ModuleName.module(:function, nil, slug),
          rel_path: ModuleName.path(:function, nil, slug),
          spawns: []
        }
      end)

    modules = Map.new(units, fn unit -> {unit.entry.name, unit.module} end)
    {modules, units}
  end

  defp script_units(scripts, dup_index, sprites) do
    dedupe_slugs(scripts, fn entry, slug ->
      kind = if entry.kind == :script, do: :script, else: :floating
      map = entry[:map]

      {spawns, unresolved} = build_spawns(entry, Map.get(dup_index, entry.name, []), sprites)

      %{
        entry: entry,
        kind: kind,
        module: ModuleName.module(kind, map, slug),
        rel_path: ModuleName.path(kind, map, slug),
        spawns: spawns,
        unresolved_sprites: unresolved
      }
    end)
  end

  # Slugs collide (same display name on one map, or across files); append the
  # placement coordinates, then an index, deterministically.
  defp dedupe_slugs(entries, build) do
    entries
    |> Enum.reduce({[], MapSet.new()}, fn entry, {units, seen} ->
      base = ModuleName.slug(ModuleName.display_name(entry.name))

      slug =
        [base, coord_slug(entry, base), "#{base}_#{MapSet.size(seen)}"]
        |> Enum.reject(&is_nil/1)
        |> Enum.find(&(not MapSet.member?(seen, {entry[:map], &1})))

      {[build.(entry, slug) | units], MapSet.put(seen, {entry[:map], slug})}
    end)
    |> elem(0)
    |> Enum.reverse()
  end

  defp coord_slug(%{x: x, y: y}, base), do: "#{base}_#{x}_#{y}"
  defp coord_slug(_entry, _base), do: nil

  defp build_spawns(entry, duplicates, sprites) do
    placements =
      if entry[:flag] do
        # CLOAKED/DISABLED/HIDDEN scripts are invisible until an event
        # enables them; without event wiring they must not spawn.
        []
      else
        Enum.filter([entry | duplicates], &placed?/1)
      end

    Enum.map_reduce(placements, MapSet.new(), fn placement, unresolved ->
      {sprite, unresolved} = resolve_sprite(placement.sprite, sprites, unresolved)

      {%{
         map: placement.map,
         x: placement.x,
         y: placement.y,
         dir: placement[:dir],
         sprite: sprite,
         name: ModuleName.display_name(placement.name)
       }, unresolved}
    end)
  end

  defp placed?(%{map: _} = entry), do: visible_sprite?(entry.sprite)
  defp placed?(_entry), do: false

  # Sprite -1 marks an invisible (event/trigger) NPC; it has no client visual.
  defp visible_sprite?(sprite) when is_integer(sprite), do: sprite > 0
  defp visible_sprite?(sprite) when is_binary(sprite), do: true
  defp visible_sprite?(_), do: false

  defp resolve_sprite(sprite, _sprites, unresolved) when is_integer(sprite),
    do: {sprite, unresolved}

  defp resolve_sprite(sprite, sprites, unresolved) when is_binary(sprite) do
    case Map.fetch(sprites, sprite) do
      {:ok, id} -> {id, unresolved}
      :error -> {@generic_sprite, MapSet.put(unresolved, sprite)}
    end
  end

  # -- per-unit processing -----------------------------------------------------

  defp process_unit(unit, state) do
    entry = unit.entry
    source_hash = Manifest.hash(entry.body <> inspect(unit.spawns))
    key = Manifest.key(entry)
    out_path = Path.join(state.out_root, unit.rel_path)

    case Manifest.decide(state.manifest[key], source_hash, output_state(out_path)) do
      :skip ->
        %{state | skipped: state.skipped + 1}

      :write ->
        write_unit(unit, key, source_hash, out_path, state)

      :conflict ->
        write_conflict(unit, state)
    end
  end

  defp output_state(path) do
    case File.read(path) do
      {:ok, content} -> {:present, Manifest.hash(content)}
      {:error, _} -> :missing
    end
  end

  defp write_unit(unit, key, source_hash, out_path, state) do
    case generate(unit, unit.module, unit.spawns, state) do
      {:ok, source, stubs} ->
        File.mkdir_p!(Path.dirname(out_path))
        File.write!(out_path, source)

        record = %{
          source_hash: source_hash,
          output_path: unit.rel_path,
          output_hash: Manifest.hash(source)
        }

        %{
          state
          | manifest: Map.put(state.manifest, key, record),
            written: [unit.rel_path | state.written],
            stubs: Map.merge(state.stubs, stubs, fn _, a, b -> a + b end),
            unresolved_sprites:
              MapSet.union(state.unresolved_sprites, unit[:unresolved_sprites] || MapSet.new())
        }

      {:error, reason} ->
        %{state | failures: [{:entry, unit.entry.file, unit.entry.line, reason} | state.failures]}
    end
  end

  # A conflicting unit is regenerated under the Conflicts namespace with no
  # spawns; the manifest record is left as-is so the conflict persists until
  # resolved by hand.
  defp write_conflict(unit, state) do
    {cmodule, crel_path} = ModuleName.conflict(unit.module, unit.rel_path)

    case generate(unit, cmodule, [], state) do
      {:ok, source, _stubs} ->
        out_path = Path.join(state.out_root, crel_path)
        File.mkdir_p!(Path.dirname(out_path))
        File.write!(out_path, source)
        %{state | conflicts: [{unit.rel_path, crel_path} | state.conflicts]}

      {:error, reason} ->
        %{state | failures: [{:entry, unit.entry.file, unit.entry.line, reason} | state.failures]}
    end
  end

  defp generate(unit, module, spawns, state) do
    entry = unit.entry

    opts = %{
      module: module,
      kind: unit.kind,
      spawns: spawns,
      functions: state.functions,
      source: "#{entry.file}:#{entry.line} (#{entry[:name]})"
    }

    with {:ok, source} <- Codegen.generate(entry.body, opts) do
      {:ok, source, stub_counts(entry.body)}
    end
  end

  defp stub_counts(body) do
    case Parser.parse_body(body) do
      {:ok, ast} -> Analyzer.analyze(ast).stubs
      {:error, _} -> %{}
    end
  end
end
