defmodule Aesir.ZoneServer.Npc.Transpiler do
  @moduledoc """
  Orchestrates the rAthena NPC transpile: file parsing, duplicate/function
  grouping, sprite resolution, manifest-driven regen decisions, codegen and
  file output.

  Driven by `mix aesir.import.npcs`; returns a result map the task renders
  into `_transpile_report.md`. Per-entry parse/codegen problems are collected
  as failures; structural helper and duplicate ambiguity stops all writes.
  """

  alias Aesir.ZoneServer.Npc.Transpiler.Analyzer
  alias Aesir.ZoneServer.Npc.Transpiler.Codegen
  alias Aesir.ZoneServer.Npc.Transpiler.CommandMap
  alias Aesir.ZoneServer.Npc.Transpiler.FileParser
  alias Aesir.ZoneServer.Npc.Transpiler.FunctionIndex
  alias Aesir.ZoneServer.Npc.Transpiler.Manifest
  alias Aesir.ZoneServer.Npc.Transpiler.ModuleName
  alias Aesir.ZoneServer.Npc.Transpiler.Parser
  alias Aesir.ZoneServer.Npc.Transpiler.Resolver
  alias Aesir.ZoneServer.Npc.Transpiler.SourceDiscovery

  @generic_sprite 46
  @manifest_rel "priv/npc_transpile/manifest.json"

  @type result :: map()

  @doc """
  Runs the transpile.

  With no `:only`, sources come from both enabled mode configuration graphs.

  Options:
  - `:only` — non-authoritative glob relative to `npc`, limiting the source files
  - `:force` — regenerate even when the source is unchanged (codegen changed);
    hand-edited outputs still divert to `_conflicts/`
  - `:out_root` — zone_server app root the output paths hang off
    (default `apps/zone_server`)
  """
  @spec run(Path.t(), keyword()) :: result()
  def run(rathena_root, opts \\ []) do
    out_root = Keyword.get(opts, :out_root, Path.join("apps", "zone_server"))
    only = Keyword.get(opts, :only)
    manifest_path = Path.join(out_root, @manifest_rel)
    loaded_manifest = Manifest.load(manifest_path)
    sources = SourceDiscovery.discover!(rathena_root, only: only)
    {active_manifest, stale_manifest} = manifest_views(loaded_manifest, sources, only)

    {active_manifest, active_groups, active_path_failures} =
      normalize_manifest_outputs(active_manifest, out_root, :active)

    {stale_manifest, stale_groups, stale_path_failures} =
      normalize_manifest_outputs(stale_manifest, out_root, :stale)

    active_ownership_failures = active_ownership_failures(active_groups)
    manifest = Map.merge(active_manifest, stale_manifest)
    sprites = load_sprites(rathena_root)

    entries = parse_files(sources)
    {functions, scripts, duplicates, skipped, file_errors} = partition(entries)

    owners = build_ownership(manifest, out_root)
    {function_targets, function_units} = function_units(functions, owners)
    local_function_keys = MapSet.new(function_units, &Manifest.key(&1.entry))

    helper_targets =
      function_targets ++ manifest_function_targets(active_manifest, local_function_keys)

    {function_index, helper_failures} = build_function_index(helper_targets)

    local_script_keys = MapSet.new(scripts, &Manifest.key/1)
    manifest_sources = manifest_script_sources(active_manifest, local_script_keys)
    source_targets = local_script_sources(scripts) ++ manifest_sources

    {duplicate_links, orphan_duplicates, duplicate_failures} =
      link_duplicates(duplicates, source_targets)

    script_units = script_units(scripts, duplicate_links, sprites, owners)

    {cross_units, cross_failures} =
      cross_run_units(manifest_sources, duplicate_links, sprites, rathena_root)

    units = function_units ++ script_units ++ cross_units
    incompatible_helpers = incompatible_helper_failures(units, function_index)

    structural_failures =
      duplicate_failures ++ helper_failures ++ cross_failures ++ incompatible_helpers

    {stale_keys, stale_outputs, stale_failures} =
      preflight_stale(stale_groups, active_groups)

    path_failures = active_path_failures ++ stale_path_failures ++ active_ownership_failures
    blocking_failures = path_failures ++ structural_failures ++ stale_failures

    state = %{
      manifest: manifest,
      out_root: out_root,
      force: Keyword.get(opts, :force, false),
      functions: function_index,
      sprites: sprites,
      written: [],
      skipped: 0,
      conflicts: [],
      failures: Enum.reverse(blocking_failures),
      stubs: %{},
      unresolved_sprites: MapSet.new()
    }

    state =
      if blocking_failures == [] do
        units
        |> Enum.reduce(state, &process_unit/2)
        |> reconcile_stale(stale_keys, stale_outputs)
      else
        state
      end

    if blocking_failures == [] do
      Manifest.save(state.manifest, manifest_path)
    end

    %{
      written: Enum.reverse(state.written),
      skipped: state.skipped,
      conflicts: Enum.reverse(state.conflicts),
      failures: Enum.reverse(state.failures) ++ file_errors,
      stubs: state.stubs,
      unresolved_sprites: Enum.sort(state.unresolved_sprites),
      skipped_types: Enum.frequencies_by(skipped, & &1.type),
      orphan_duplicates: orphan_duplicates,
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

  defp parse_files(sources) do
    Enum.flat_map(sources, fn source ->
      {:ok, entries} = FileParser.parse(File.read!(source.path), source.relative)
      Enum.map(entries, &Map.put(&1, :scope, source.scope))
    end)
  end

  defp manifest_views(manifest, _sources, only) when not is_nil(only), do: {manifest, %{}}

  defp manifest_views(manifest, sources, nil) do
    enabled = MapSet.new(sources, & &1.relative)

    Enum.split_with(manifest, fn {key, _record} ->
      MapSet.member?(enabled, Manifest.source_file(key))
    end)
    |> then(fn {active, stale} -> {Map.new(active), Map.new(stale)} end)
  end

  defp normalize_manifest_outputs(manifest, out_root, context) do
    Enum.reduce(manifest, {%{}, %{}, []}, fn {key, record}, {manifest, groups, failures} ->
      case normalize_output_path(out_root, record.output_path) do
        {:ok, relative, output} ->
          record = %{record | output_path: relative}
          group = %{path: output, records: [{key, record}]}

          {
            Map.put(manifest, key, record),
            Map.update(groups, relative, group, &%{&1 | records: [{key, record} | &1.records]}),
            failures
          }

        {:error, reason} ->
          failure = invalid_output_failure(context, key, record.output_path, reason)
          {manifest, groups, [failure | failures]}
      end
    end)
  end

  defp active_ownership_failures(groups) do
    groups
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.flat_map(fn {output_path, group} ->
      owners =
        group.records
        |> Enum.map(fn {key, _record} -> {key, Manifest.source_file(key)} end)
        |> Enum.uniq()
        |> Enum.sort()

      case owners do
        [{_key, _source}] ->
          []

        [{_key, source} | _rest] ->
          [{:active, source, 0, {:multiple_output_owners, output_path, owners}}]
      end
    end)
  end

  defp build_ownership(manifest, out_root) do
    Enum.reduce(manifest, %{by_key: %{}, by_path: %{}, out_root: out_root}, fn {key, record},
                                                                               acc ->
      %{
        acc
        | by_key: Map.put(acc.by_key, key, record.output_path),
          by_path:
            Map.update(acc.by_path, record.output_path, MapSet.new([key]), &MapSet.put(&1, key))
      }
    end)
  end

  defp preflight_stale(stale_groups, active_groups) do
    Enum.reduce(stale_groups, {[], [], []}, fn {relative, group}, acc ->
      case active_groups[relative] do
        nil -> preflight_stale_group(group, acc)
        active_group -> active_stale_collision(group, active_group, acc)
      end
    end)
  end

  defp active_stale_collision(group, active_group, {keys, outputs, failures}) do
    active_sources =
      active_group.records
      |> Enum.map(fn {key, _record} -> Manifest.source_file(key) end)
      |> Enum.uniq()
      |> Enum.sort()

    collision_failures =
      Enum.map(group.records, fn {key, record} ->
        {:stale, Manifest.source_file(key), 0,
         {:output_owned_by_active, record.output_path, active_sources}}
      end)

    {keys, outputs, collision_failures ++ failures}
  end

  defp normalize_output_path(_out_root, output_path) when not is_binary(output_path),
    do: {:error, :non_string}

  defp normalize_output_path(out_root, output_path) do
    root = Path.expand(out_root)

    case Path.type(output_path) do
      :relative -> safe_relative_output(root, output_path)
      _type -> {:error, :non_relative}
    end
  end

  defp safe_relative_output(root, output_path) do
    case Path.safe_relative(output_path, root) do
      {:ok, ""} ->
        {:error, :output_root}

      {:ok, relative} ->
        if symlink_component?(root, relative) do
          {:error, :symlink}
        else
          {:ok, relative, Path.join(root, relative)}
        end

      :error ->
        if symlink_component?(root, output_path),
          do: {:error, :symlink},
          else: {:error, :outside_root}
    end
  end

  defp symlink_component?(root, relative) do
    relative
    |> Path.split()
    |> Enum.reduce_while(root, fn component, parent ->
      path = Path.join(parent, component)

      case File.lstat(path) do
        {:ok, %File.Stat{type: :symlink}} -> {:halt, :symlink}
        _other -> {:cont, path}
      end
    end)
    |> Kernel.==(:symlink)
  end

  defp preflight_stale_group(group, {keys, outputs, failures}) do
    case File.read(group.path) do
      {:ok, content} ->
        preflight_present_group(group, content, {keys, outputs, failures})

      {:error, :enoent} ->
        {group_keys(group) ++ keys, outputs, failures}

      {:error, reason} ->
        read_failures =
          Enum.map(group.records, fn {key, record} ->
            {:stale, Manifest.source_file(key), 0,
             {:output_read_failed, record.output_path, reason}}
          end)

        {keys, outputs, read_failures ++ failures}
    end
  end

  defp preflight_present_group(group, content, {keys, outputs, failures}) do
    hash = Manifest.hash(content)

    modified_failures =
      for {key, record} <- group.records, record.output_hash != hash do
        {:stale, Manifest.source_file(key), 0, {:output_modified, record.output_path}}
      end

    if modified_failures == [] do
      {group_keys(group) ++ keys, [group | outputs], failures}
    else
      {keys, outputs, modified_failures ++ failures}
    end
  end

  defp invalid_output_failure(context, key, output_path, reason) do
    {context, Manifest.source_file(key), 0, {:invalid_output_path, output_path, reason}}
  end

  defp group_keys(group), do: Enum.map(group.records, &elem(&1, 0))

  defp reconcile_stale(state, stale_keys, stale_outputs) do
    state = %{state | manifest: Map.drop(state.manifest, stale_keys)}
    Enum.reduce(stale_outputs, state, &remove_stale_output/2)
  end

  defp remove_stale_output(group, state) do
    case File.rm(group.path) do
      :ok ->
        state

      {:error, reason} ->
        manifest =
          Enum.reduce(group.records, state.manifest, fn {key, record}, acc ->
            Map.put(acc, key, record)
          end)

        failures =
          Enum.map(group.records, fn {key, record} ->
            {:stale, Manifest.source_file(key), 0,
             {:output_remove_failed, record.output_path, reason}}
          end)

        %{state | manifest: manifest, failures: failures ++ state.failures}
    end
  end

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
    path_fun = fn entry, slug ->
      ModuleName.path(:function, nil, slug, entry.scope)
    end

    units =
      dedupe_slugs(functions, owners, path_fun, fn entry, slug ->
        %{
          entry: entry,
          kind: :function,
          module: ModuleName.module(:function, nil, slug, entry.scope),
          rel_path: ModuleName.path(:function, nil, slug, entry.scope),
          spawns: []
        }
      end)

    targets =
      Enum.map(units, fn unit ->
        %{name: unit.entry.name, scope: unit.entry.scope, module: unit.module}
      end)

    {targets, units}
  end

  defp script_units(scripts, duplicate_links, sprites, owners) do
    path_fun = fn entry, slug ->
      ModuleName.path(unit_kind(entry), entry, slug, entry.scope)
    end

    dedupe_slugs(scripts, owners, path_fun, fn entry, slug ->
      kind = unit_kind(entry)
      duplicates = Map.get(duplicate_links, Manifest.key(entry), [])
      {spawns, unresolved} = build_spawns(entry, duplicates, sprites)

      %{
        entry: entry,
        kind: kind,
        module: ModuleName.module(kind, entry, slug, entry.scope),
        rel_path: ModuleName.path(kind, entry, slug, entry.scope),
        spawns: spawns,
        unresolved_sprites: unresolved
      }
    end)
  end

  defp unit_kind(entry), do: if(entry.kind == :script, do: :script, else: :floating)

  defp manifest_function_targets(manifest, local_keys) do
    Enum.flat_map(manifest, &manifest_function_target(&1, local_keys))
  end

  defp manifest_function_target({key, rec}, local_keys) do
    case String.split(key, "|") do
      [_file, "function", name | _rest] ->
        build_manifest_function_target(key, rec, name, MapSet.member?(local_keys, key))

      _other ->
        []
    end
  end

  defp build_manifest_function_target(_key, _rec, _name, true), do: []

  defp build_manifest_function_target(key, rec, name, false) do
    scope = Manifest.body_scope(key)
    slug = Path.basename(rec.output_path, ".ex")

    module =
      case rec.module do
        nil -> ModuleName.module(:function, nil, slug, scope)
        module -> module
      end

    [%{name: name, scope: scope, module: module}]
  end

  defp build_function_index(targets) do
    case FunctionIndex.build(targets) do
      {:ok, index} ->
        {index, []}

      {:error, errors} ->
        failures = Enum.map(errors, &{:link, "global functions", 0, &1})
        {%{}, failures}
    end
  end

  defp local_script_sources(scripts) do
    Enum.map(scripts, fn entry ->
      %{
        key: Manifest.key(entry),
        ref: ref_name(entry),
        scope: entry.scope,
        file: entry.file,
        record: nil
      }
    end)
  end

  defp manifest_script_sources(manifest, local_keys) do
    Enum.flat_map(manifest, &manifest_script_source(&1, local_keys))
  end

  defp manifest_script_source({key, rec}, local_keys) do
    case String.split(key, "|") do
      [_file, kind, name | _] when kind in ["script", "floating"] ->
        build_manifest_script_source(key, rec, name, MapSet.member?(local_keys, key))

      _other ->
        []
    end
  end

  defp build_manifest_script_source(_key, _rec, _name, true), do: []

  defp build_manifest_script_source(key, rec, name, false) do
    [
      %{
        key: key,
        ref: ref_name(name),
        scope: Manifest.body_scope(key),
        file: Manifest.source_file(key),
        record: rec
      }
    ]
  end

  defp link_duplicates(duplicates, sources) do
    source_index = Enum.group_by(sources, & &1.ref)

    {links, orphans, failures} =
      Enum.reduce(duplicates, {%{}, [], []}, fn duplicate, {links, orphans, failures} ->
        compatible =
          source_index
          |> Map.get(duplicate.source, [])
          |> Enum.filter(&compatible_source?(&1.scope, duplicate.scope))

        case compatible do
          [source] ->
            links = Map.update(links, source.key, [duplicate], &[duplicate | &1])
            {links, orphans, failures}

          [] ->
            orphan = "#{duplicate.source} [#{duplicate.scope}]"
            {links, [orphan | orphans], failures}

          many ->
            candidates = Enum.map(many, &{&1.file, &1.scope})

            failure =
              {:link, duplicate.file, duplicate.line,
               {:ambiguous_duplicate, duplicate.source, duplicate.scope, candidates}}

            {links, orphans, [failure | failures]}
        end
      end)

    links = Map.new(links, fn {key, entries} -> {key, Enum.reverse(entries)} end)
    {links, Enum.reverse(orphans), Enum.reverse(failures)}
  end

  defp compatible_source?(:shared, _duplicate_scope), do: true
  defp compatible_source?(scope, scope), do: true
  defp compatible_source?(_source_scope, _duplicate_scope), do: false

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
        [preferred_slug(entry, owners, path_fun), base, coord_slug(entry, base)]
        |> Enum.reject(&is_nil/1)
        |> Enum.uniq()
        |> Stream.concat(Stream.map(0..1_000_000//1, &"#{base}_#{&1}"))
        |> Enum.find(&slug_free?(&1, entry, seen, owners, path_fun))

      {[build.(entry, slug) | units], MapSet.put(seen, {dedupe_key(entry), slug})}
    end)
    |> elem(0)
    |> Enum.reverse()
  end

  defp preferred_slug(entry, owners, path_fun) do
    with relative when is_binary(relative) <- owners.by_key[Manifest.key(entry)],
         slug = Path.basename(relative, ".ex"),
         {:ok, generated, _output} <-
           normalize_output_path(owners.out_root, path_fun.(entry, slug)),
         true <- generated == relative do
      slug
    else
      _other -> nil
    end
  end

  defp slug_free?(slug, entry, seen, owners, path_fun) do
    {:ok, relative, _output} = normalize_output_path(owners.out_root, path_fun.(entry, slug))
    owner_keys = Map.get(owners.by_path, relative, MapSet.new())

    not MapSet.member?(seen, {dedupe_key(entry), slug}) and
      (MapSet.size(owner_keys) == 0 or owner_keys == MapSet.new([Manifest.key(entry)]))
  end

  defp dedupe_key(%{kind: :script} = entry), do: ModuleName.dir_slug(entry)
  defp dedupe_key(entry), do: {entry.kind, entry.scope}

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
          name: ModuleName.display_name(placement.name),
          scope: placement.scope
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

  defp cross_run_units(manifest_sources, duplicate_links, sprites, rathena_root) do
    {units, failures} =
      Enum.reduce(manifest_sources, {[], []}, fn source, acc ->
        collect_cross_run_unit(source, duplicate_links, sprites, rathena_root, acc)
      end)

    {Enum.reverse(units), Enum.reverse(failures)}
  end

  defp collect_cross_run_unit(source, duplicate_links, sprites, rathena_root, acc) do
    case Map.get(duplicate_links, source.key, []) do
      [] -> acc
      duplicates -> build_cross_run_unit(source, duplicates, sprites, rathena_root, acc)
    end
  end

  defp build_cross_run_unit(source, duplicates, sprites, rathena_root, {units, failures}) do
    case recover_cross_run_unit(source, duplicates, sprites, rathena_root) do
      {:ok, unit} -> {[unit | units], failures}
      {:error, failure} -> {units, [failure | failures]}
    end
  end

  defp recover_cross_run_unit(source, duplicates, sprites, rathena_root) do
    case recover_entry(rathena_root, source.key) do
      {:ok, entry} ->
        kind = unit_kind(entry)
        {new_spawns, unresolved} = resolve_duplicate_spawns(entry, duplicates, sprites)

        module =
          source.record.module ||
            ModuleName.module(
              kind,
              entry,
              Path.basename(source.record.output_path, ".ex"),
              entry.scope
            )

        {:ok,
         %{
           entry: entry,
           kind: kind,
           module: module,
           rel_path: source.record.output_path,
           spawns: merge_spawns(source.record.spawns, new_spawns),
           unresolved_sprites: unresolved
         }}

      {:error, _reason} when is_nil(source.record.module) ->
        {:error,
         {:link, source.file, 0,
          {:missing_manifest_module, source.key, source.file, source.scope}}}

      {:error, reason} ->
        {:error,
         {:link, source.file, 0,
          {:unrecoverable_duplicate_source, source.key, source.scope, reason}}}
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
        entry -> {:ok, Map.put(entry, :scope, Manifest.body_scope(key))}
      end
    else
      _ -> {:error, :source_unavailable}
    end
  end

  # Merges stored spawns with newly resolved duplicates, keeping the first
  # placement per scoped location so re-running the same batch stays idempotent.
  defp merge_spawns(prior, new) do
    {merged, _seen} =
      Enum.reduce(prior ++ new, {[], MapSet.new()}, fn spawn, {acc, seen} ->
        key = {spawn.map, spawn.x, spawn.y, spawn.scope}

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

    source_hash =
      Manifest.hash(
        entry.body <> inspect(unit.spawns) <> helper_link_hash(entry, state.functions)
      )

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

  defp incompatible_helper_failures(units, functions) do
    Enum.flat_map(units, fn unit ->
      for {name, {:missing, scopes}} <- helper_resolutions(unit.entry, functions), scopes != [] do
        {:link, unit.entry.file, unit.entry.line,
         {:incompatible_helper, name, unit.entry.scope, scopes}}
      end
    end)
  end

  defp helper_link_hash(entry, functions) do
    case helper_resolutions(entry, functions) do
      [] -> ""
      dependencies -> :erlang.term_to_binary(dependencies, [:deterministic])
    end
  end

  defp helper_resolutions(entry, functions) do
    case Parser.parse_body(entry.body) do
      {:ok, ast} ->
        Enum.map(literal_helper_dependencies(ast), fn name ->
          {name, helper_resolution(functions, name, entry.scope)}
        end)

      {:error, reason} ->
        [{:parse_error, reason}]
    end
  end

  defp helper_resolution(functions, name, scope) do
    case FunctionIndex.resolve(functions, name, scope) do
      :missing ->
        scopes = functions |> Map.get(name, %{}) |> Map.keys() |> Enum.sort()
        {:missing, scopes}

      resolved ->
        resolved
    end
  end

  defp literal_helper_dependencies(ast) do
    ast
    |> collect_literal_helpers(MapSet.new())
    |> MapSet.to_list()
    |> Enum.sort()
  end

  defp collect_literal_helpers({kind, "callfunc", [{:str, name} | args]}, found)
       when kind in [:cmd, :call] do
    found =
      if command_map_handles?(kind, name), do: found, else: MapSet.put(found, name)

    collect_literal_helpers(args, found)
  end

  defp collect_literal_helpers(tuple, found) when is_tuple(tuple) do
    tuple
    |> Tuple.to_list()
    |> collect_literal_helpers(found)
  end

  defp collect_literal_helpers(list, found) when is_list(list) do
    Enum.reduce(list, found, &collect_literal_helpers/2)
  end

  defp collect_literal_helpers(_term, found), do: found

  defp command_map_handles?(kind, name) do
    expected = if(kind == :cmd, do: :command, else: :read)
    match?({:ok, %{kind: ^expected}}, CommandMap.function(name))
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
      scope: entry.scope,
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
