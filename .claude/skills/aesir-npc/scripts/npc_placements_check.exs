# Placement check for an imported NPC module.
#
# Usage (plain elixir, no Mix, no compiled project needed), from the repo root:
#
#     elixir .agents/skills/aesir-npc/scripts/npc_placements_check.exs <module path> [...]
#
# The rAthena checkout defaults to ~/Development/personal/rathena; override it
# with RATHENA_ROOT. Several module paths share one pass over the reference tree,
# which is the slow part (~15 s).
#
# Compares the module's `spawn:` list with the reference script. A body reaches the
# map either through its own `script` placement row or through `duplicate(<exname>)`
# rows in the scoped scripts, so both are the reference; the manifest's recorded
# spawns are not, because a targeted (`--only`) run can write a record before the
# scoped duplicates are in scope and that stale record is never revisited while the
# source stays unchanged.
#
# Output, one line per module:
#
#     x.ex: module_placements=N reference_placements=M mismatches=K
#
# followed by one MISSING/EXTRA line per diverging placement (map, coordinates,
# direction, sprite, unique name, scope). Any of those is a real divergence: fix
# the module's `spawn:` list before refactoring its body. Exit status is 1 when it
# diverges.
#
# Sprites are compared after resolving the reference's `4_F_01`-style constants
# through `enum e_job_types` in `<rathena>/src/map/npc.hpp`, the table the
# importer uses. A constant missing from that table is printed unresolved.

defmodule PlacementsCheck do
  @moduledoc false

  def run(module_paths) do
    rathena_root = System.get_env("RATHENA_ROOT", Path.expand("~/Development/personal/rathena"))
    sprites = sprite_constants(rathena_root)

    reference_index =
      rathena_root
      |> Path.join("npc/**/*.txt")
      |> Path.wildcard()
      |> Enum.flat_map(&placement_rows(&1, rathena_root, sprites))
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))

    failures = Enum.count(module_paths, &(check(&1, reference_index) != :ok))

    if failures > 0, do: exit({:shutdown, 1})
  end

  defp check(module_path, reference_index) do
    source = File.read!(module_path)

    module_placements =
      source
      |> spawn_block()
      |> module_rows()

    module_scope = module_scope(source)

    reference =
      reference_index
      |> Map.get(body_name(module_path), [])
      |> Enum.filter(&(module_scope == "shared" or elem(&1, 6) == module_scope))
      |> MapSet.new()

    module_set = MapSet.new(module_placements)
    missing = Enum.sort(MapSet.difference(reference, module_set))
    extra = Enum.sort(MapSet.difference(module_set, reference))

    IO.puts(
      "#{Path.basename(module_path)}: module_placements=#{MapSet.size(module_set)} " <>
        "reference_placements=#{MapSet.size(reference)} " <>
        "mismatches=#{length(missing) + length(extra)}"
    )

    for placement <- missing, do: IO.puts("  MISSING from module: #{format(placement)}")
    for placement <- extra, do: IO.puts("  EXTRA in module    : #{format(placement)}")

    if missing == [] and extra == [], do: :ok, else: :diverged
  end

  # -- the module's spawn list ---------------------------------------------------

  # A mode-scoped body is only active in its own mode, so only that mode's placements count. A
  # shared body may be placed by both scoped scripts and is compared against all of them.
  defp module_scope(source) do
    case Regex.run(~r/use Aesir\.ZoneServer\.Npc,\s*scope: :(\w+)/, source) do
      [_, scope] -> scope
      nil -> "shared"
    end
  end

  # A one- or multi-line `spawn:` list; the list itself holds no brackets.
  defp spawn_block(source) do
    case Regex.run(~r/spawn: \[(.*?)\]/s, source) do
      [_, block] -> block
      nil -> ""
    end
  end

  defp module_rows(block) do
    block
    |> String.split("%{")
    |> Enum.flat_map(&module_row/1)
  end

  defp module_row(chunk) do
    with [_, map] <- Regex.run(~r/map:\s*"([^"]*)"/, chunk),
         [_, x] <- Regex.run(~r/\bx:\s*(-?\d+)/, chunk),
         [_, y] <- Regex.run(~r/\by:\s*(-?\d+)/, chunk),
         [_, sprite] <- Regex.run(~r/\bsprite:\s*(-?\d+)/, chunk),
         [_, name] <- Regex.run(~r/\bname:\s*"([^"]*)"/, chunk) do
      dir = capture(~r/\bdir:\s*(-?\d+)/, chunk, "0")
      scope = capture(~r/\bscope:\s*:(\w+)/, chunk, "shared")
      unique = capture(~r/\bunique_name:\s*"([^"]*)"/, chunk, name)

      [
        {map, String.to_integer(x), String.to_integer(y), String.to_integer(dir),
         String.to_integer(sprite), unique, scope}
      ]
    else
      _ -> []
    end
  end

  # -- the reference placements --------------------------------------------------

  defp body_name(module_path) do
    repo_root = Path.expand("../../../..", __DIR__)
    manifest = Path.join(repo_root, "apps/zone_server/priv/npc_transpile/manifest.json")
    target = Path.expand(module_path)

    record =
      manifest
      |> File.read!()
      |> :json.decode()
      |> Enum.find(fn {_key, record} ->
        Path.expand(record["output_path"], Path.join(repo_root, "apps/zone_server")) == target
      end)

    case record do
      nil ->
        nil

      {key, _record} ->
        key |> String.split("|") |> Enum.at(2, "") |> String.split("::", parts: 2) |> List.last()
    end
  end

  defp placement_rows(path, rathena_root, sprites) do
    scope =
      case path |> Path.relative_to(Path.join(rathena_root, "npc")) |> Path.split() |> hd() do
        "re" -> "renewal"
        "pre-re" -> "pre_renewal"
        _ -> "shared"
      end

    path
    |> File.read!()
    |> :binary.split("\n", [:global])
    |> Enum.filter(
      &(String.valid?(&1) and not String.starts_with?(String.trim_leading(&1), "//"))
    )
    |> Enum.flat_map(&placement_row(&1, scope, sprites))
  end

  defp placement_row(line, scope, sprites) do
    duplicate_row(line, scope, sprites) ++ script_row(line, scope, sprites)
  end

  # A body placed directly on a map carries its own `script` row; a floating body has none and is
  # placed only through `duplicate` rows.
  defp script_row(line, scope, sprites) do
    with [position, "script", name | rest] <- String.split(line, "\t"),
         [map, x, y, dir] <- String.split(position, ",") do
      [
        {exname(name),
         {map, to_int(x), to_int(y), to_int(dir), sprite(Enum.at(rest, 0, ""), sprites),
          exname(name), scope}}
      ]
    else
      _ -> []
    end
  end

  defp duplicate_row(line, scope, sprites) do
    with [position, "duplicate(" <> duplicate | rest] <- String.split(line, "\t"),
         [map, x, y, dir] <- String.split(position, ",") do
      body = duplicate |> String.trim_trailing(")") |> exname()
      name = rest |> Enum.at(0, "") |> String.trim() |> exname()

      [
        {body,
         {map, to_int(x), to_int(y), to_int(dir), sprite(Enum.at(rest, 1, ""), sprites), name,
          scope}}
      ]
    else
      _ -> []
    end
  end

  defp exname(name), do: name |> String.split("::", parts: 2) |> List.last()

  defp to_int(value) do
    case Integer.parse(String.trim(value)) do
      {int, ""} -> int
      _ -> String.trim(value)
    end
  end

  # A duplicate row's sprite field may carry the touch area after the sprite
  # (`-1,1,1`: sprite -1, trigger 1x1); only the sprite is compared here.
  defp sprite(value, sprites) do
    value = value |> String.split(",") |> hd() |> String.trim()

    case Integer.parse(value) do
      {int, ""} -> int
      _ -> Map.get(sprites, value, value)
    end
  end

  defp capture(regex, chunk, default) do
    case Regex.run(regex, chunk) do
      [_, value] -> value
      nil -> default
    end
  end

  defp format({map, x, y, dir, sprite, name, scope}) do
    "#{map} #{x},#{y} dir=#{dir} sprite=#{sprite} unique_name=#{inspect(name)} scope=#{scope}"
  end

  # `enum e_job_types` mirrors the importer's parser: `JT_`-prefixed names only,
  # an explicit numeric anchor resets the counter, and a symbolic anchor
  # (`= OTHER_CONST`) neither adds an entry nor advances the counter.
  defp sprite_constants(rathena_root) do
    with {:ok, source} <- File.read(Path.join([rathena_root, "src/map/npc.hpp"])),
         [_, body] <- Regex.run(~r/enum e_job_types\s*\{(.*?)\};/s, source) do
      body
      |> String.replace(~r{//[^\n]*}, "")
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reduce({%{}, 0}, &sprite_entry/2)
      |> elem(0)
    else
      _ -> %{}
    end
  end

  defp sprite_entry(entry, {acc, next}) do
    case Regex.run(~r/^(\w+)\s*(?:=\s*(-?\w+))?/, entry) do
      [_, name] -> {put_sprite(acc, name, next), next + 1}
      [_, name, value] -> with_value(acc, name, value, next)
      nil -> {acc, next}
    end
  end

  defp with_value(acc, name, value, next) do
    case Integer.parse(value) do
      {int, ""} -> {put_sprite(acc, name, int), int + 1}
      _ -> {acc, next}
    end
  end

  defp put_sprite(acc, "JT_" <> name, value), do: Map.put(acc, name, value)
  defp put_sprite(acc, _other, _value), do: acc
end

PlacementsCheck.run(System.argv())
