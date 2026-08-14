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
  - `:only` — glob (relative to `npc`) limiting the source files
  - `:force` — regenerate even when the source is unchanged (codegen changed);
    hand-edited outputs still divert to `_conflicts/`
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
    owners = Map.new(manifest, fn {key, rec} -> {rec.output_path, key} end)
    manifest_scripts = manifest_scripts(manifest)
    {fn_modules, fn_units} = function_units(functions, owners)
    script_units = script_units(scripts, dup_index, sprites, owners)
    cross_units = cross_run_units(scripts, dup_index, manifest_scripts, sprites, rathena_root)

    state = %{
      manifest: manifest,
      out_root: out_root,
      force: Keyword.get(opts, :force, false),
      functions: Map.merge(manifest_functions(manifest), fn_modules),
      sprites: sprites,
      written: [],
      skipped: 0,
      conflicts: [],
      failures: [],
      stubs: %{},
      unresolved_sprites: MapSet.new()
    }

    state = Enum.reduce(fn_units ++ script_units ++ cross_units, state, &process_unit/2)

    Manifest.save(state.manifest, manifest_path)

    orphans =
      Map.keys(dup_index) -- (Enum.map(scripts, &ref_name/1) ++ Map.keys(manifest_scripts))

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
    base = Path.join([root, "npc"])
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

  defp function_units(functions, owners) do
    path_fun = fn _entry, slug -> ModuleName.path(:function, nil, slug) end

    units =
      dedupe_slugs(functions, owners, path_fun, fn entry, slug ->
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

  defp script_units(scripts, dup_index, sprites, owners) do
    path_fun = fn entry, slug ->
      ModuleName.path(unit_kind(entry), entry, slug)
    end

    dedupe_slugs(scripts, owners, path_fun, fn entry, slug ->
      kind = unit_kind(entry)

      {spawns, unresolved} = build_spawns(entry, Map.get(dup_index, ref_name(entry), []), sprites)

      %{
        entry: entry,
        kind: kind,
        module: ModuleName.module(kind, entry, slug),
        rel_path: ModuleName.path(kind, entry, slug),
        spawns: spawns,
        unresolved_sprites: unresolved
      }
    end)
  end

  defp unit_kind(entry), do: if(entry.kind == :script, do: :script, else: :floating)

  # Global functions transpiled by earlier runs, recovered from the manifest
  # (key `file|function|Name|-`, module from the output slug), so a `callfunc`
  # into another import batch resolves to its module instead of a stub.
  defp manifest_functions(manifest) do
    manifest
    |> Enum.flat_map(fn {key, rec} ->
      case String.split(key, "|") do
        [_file, "function", name | _rest] ->
          [{name, ModuleName.module(:function, nil, Path.basename(rec.output_path, ".ex"))}]

        _other ->
          []
      end
    end)
    |> Map.new()
  end

  # Script/floating NPCs transpiled by earlier runs, recovered from the manifest
  # (keyed by their reference/export name), so a `duplicate(X)` in a later batch
  # attaches to the already-transpiled source instead of being reported orphaned.
  defp manifest_scripts(manifest) do
    manifest
    |> Enum.flat_map(fn {key, rec} ->
      case String.split(key, "|") do
        [_file, kind, name | _] when kind in ["script", "floating"] ->
          [{ref_name(name), {key, rec}}]

        _other ->
          []
      end
    end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
  end

  # Slugs collide (same display name on one map, or across files); append the
  # placement coordinates, then an index, deterministically. A candidate is
  # also rejected when its output path is already owned by a *different*
  # manifest entry — a cross-run collision (e.g. kafras.txt "Kafra Service"
  # vs the imported cities "Kafra Service#alde" on the same map), which would
  # otherwise land in `_conflicts/` despite being two distinct NPCs.
  defp dedupe_slugs(entries, owners, path_fun, build) do
    entries
    |> Enum.reduce({[], MapSet.new()}, fn entry, {units, seen} ->
      base = ModuleName.slug(ModuleName.display_name(entry.name))

      slug =
        [base, coord_slug(entry, base)]
        |> Enum.reject(&is_nil/1)
        |> Stream.concat(Stream.map(0..1_000_000//1, &"#{base}_#{&1}"))
        |> Enum.find(&slug_free?(&1, entry, seen, owners, path_fun))

      {[build.(entry, slug) | units], MapSet.put(seen, {dedupe_key(entry), slug})}
    end)
    |> elem(0)
    |> Enum.reverse()
  end

  defp slug_free?(slug, entry, seen, owners, path_fun) do
    not MapSet.member?(seen, {dedupe_key(entry), slug}) and
      Map.get(owners, path_fun.(entry, slug), :free) in [:free, Manifest.key(entry)]
  end

  defp dedupe_key(%{kind: :script} = entry), do: ModuleName.dir_slug(entry)
  defp dedupe_key(_entry), do: nil

  defp coord_slug(%{x: x, y: y}, base), do: "#{base}_#{x}_#{y}"
  defp coord_slug(_entry, _base), do: nil

  # `duplicate(X)` references the source NPC's export name: the part after
  # `::` (even with an empty display prefix, as in `::Guard_izlude`);
  # scripts without one are referenced by their full name.
  defp ref_name(%{name: name}), do: ref_name(name)

  defp ref_name(name) do
    case String.split(name, "::", parts: 2) do
      [_prefix, exname] -> exname
      _ -> name
    end
  end

  defp build_spawns(entry, duplicates, sprites) do
    placements =
      if entry[:flag] do
        # CLOAKED/DISABLED/HIDDEN scripts are invisible until an event
        # enables them; without event wiring they must not spawn.
        []
      else
        Enum.filter([entry | duplicates], &placed?/1)
      end

    resolve_placements(placements, sprites)
  end

  # Resolves a cross-run source's new `duplicate()` placements alone; the source
  # entry's own placement was already resolved and stored by the earlier run.
  defp resolve_duplicate_spawns(entry, duplicates, sprites) do
    if entry[:flag] do
      {[], MapSet.new()}
    else
      resolve_placements(Enum.filter(duplicates, &placed?/1), sprites)
    end
  end

  defp resolve_placements(placements, sprites) do
    Enum.map_reduce(placements, MapSet.new(), fn placement, unresolved ->
      {sprite, unresolved} = resolve_sprite(placement.sprite, sprites, unresolved)

      spawn =
        %{
          map: placement.map,
          x: placement.x,
          y: placement.y,
          dir: placement[:dir],
          sprite: sprite,
          name: ModuleName.display_name(placement.name)
        }
        |> maybe_put(:unique_name, unique_name(placement.name))
        |> maybe_put(:trigger, placement[:touch])

      {spawn, unresolved}
    end)
  end

  # rAthena's exname — what `donpcevent`/`strnpcinfo` target: the part after
  # `::` when present, else the full name including the `#hidden` fragment.
  # Omitted when it equals the display name (the Placement fallback).
  defp unique_name(name) do
    unique = ModuleName.exname(name) || String.trim_leading(name, ":")

    if unique == ModuleName.display_name(name), do: nil, else: unique
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

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

  # -- cross-run duplicate resolution -------------------------------------------

  # Sources transpiled by an earlier run are not in this run's script list, but
  # their `duplicate()` placements still need to land on them. For each such
  # source, re-parse its recorded source file to recover the body, resolve the
  # new duplicates, merge them with the stored spawns, and hand the resulting
  # unit to the normal regen pipeline.
  defp cross_run_units(scripts, dup_index, manifest_scripts, sprites, rathena_root) do
    local_refs = MapSet.new(Enum.map(scripts, &ref_name/1))

    manifest_scripts
    |> Enum.flat_map(fn {source, manifest_entries} ->
      cross_run_units_for(source, manifest_entries, local_refs, dup_index, sprites, rathena_root)
    end)
  end

  defp cross_run_units_for(source, manifest_entries, local_refs, dup_index, sprites, rathena_root) do
    duplicates = Map.get(dup_index, source, [])

    if duplicates == [] or MapSet.member?(local_refs, source) do
      []
    else
      Enum.flat_map(manifest_entries, fn {key, rec} ->
        build_cross_run_unit(key, rec, duplicates, sprites, rathena_root)
      end)
    end
  end

  defp build_cross_run_unit(key, rec, duplicates, sprites, rathena_root) do
    with true <- is_binary(rec.module),
         {:ok, entry} <- recover_entry(rathena_root, key) do
      {new_spawns, unresolved} = resolve_duplicate_spawns(entry, duplicates, sprites)

      [
        %{
          entry: entry,
          kind: unit_kind(entry),
          module: rec.module,
          rel_path: rec.output_path,
          spawns: merge_spawns(rec.spawns, new_spawns),
          unresolved_sprites: unresolved
        }
      ]
    else
      _ -> []
    end
  end

  # Re-parses the source file recorded in a manifest key and returns the entry
  # that reproduced that exact key, recovering the body codegen needs without
  # persisting it in the manifest.
  defp recover_entry(rathena_root, key) do
    with [file | _] <- String.split(key, "|"),
         {:ok, source} <- File.read(Path.join([rathena_root, "npc", file])),
         {:ok, entries} <- FileParser.parse(source, file) do
      case Enum.find(entries, &(Manifest.key(&1) == key)) do
        nil -> {:error, :entry_not_found}
        entry -> {:ok, entry}
      end
    else
      _ -> {:error, :source_unavailable}
    end
  end

  # Merges stored spawns with newly resolved duplicates, keeping the first
  # placement per {map, x, y} so re-running the same batch stays idempotent.
  defp merge_spawns(prior, new) do
    {merged, _seen} =
      Enum.reduce(prior ++ new, {[], MapSet.new()}, fn spawn, {acc, seen} ->
        key = {spawn.map, spawn.x, spawn.y}

        if MapSet.member?(seen, key) do
          {acc, seen}
        else
          {[spawn | acc], MapSet.put(seen, key)}
        end
      end)

    Enum.reverse(merged)
  end

  # -- per-unit processing -----------------------------------------------------

  defp process_unit(unit, state) do
    entry = unit.entry
    source_hash = Manifest.hash(entry.body <> inspect(unit.spawns))
    key = Manifest.key(entry)
    out_path = Path.join(state.out_root, unit.rel_path)

    case Manifest.decide(record(state, key), source_hash, output_state(out_path)) do
      :skip ->
        %{state | skipped: state.skipped + 1}

      :write ->
        write_unit(unit, key, source_hash, out_path, state)

      :conflict ->
        write_conflict(unit, state)
    end
  end

  # Under `:force` the manifest record is presented as source-changed so the
  # skip short-circuit never fires; the output-hash policy still applies.
  defp record(%{force: true} = state, key) do
    case state.manifest[key] do
      nil -> nil
      rec -> %{rec | source_hash: :forced}
    end
  end

  defp record(state, key), do: state.manifest[key]

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
          output_hash: Manifest.hash(source),
          spawns: unit.spawns,
          module: unit.module
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
      sprites: state.sprites,
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
