defmodule Aesir.ZoneServer.Npc.Transpiler.SourceDiscovery do
  @moduledoc """
  Discovers enabled NPC source files and assigns their content scope.

  With no `:only` option, discovery traverses the renewal and pre-renewal
  `scripts_main.conf` roots. An `:only` glob instead selects files relative to
  `npc/`, including files disabled in those configuration graphs.
  """

  alias Aesir.ZoneServer.Npc.ContentScope

  @roots ["npc/re/scripts_main.conf", "npc/pre-re/scripts_main.conf"]
  @max_symlinks 40

  @type source() :: %{
          path: Path.t(),
          relative: Path.t(),
          scope: ContentScope.t()
        }

  @doc """
  Returns NPC sources in stable discovery order.
  """
  @spec discover!(Path.t(), keyword()) :: [source()]
  def discover!(rathena_root, opts \\ []) do
    root = Path.expand(rathena_root)
    canonical_root = canonical_path!(root)

    case Keyword.get(opts, :only) do
      nil -> discover_enabled(root, canonical_root)
      glob -> discover_only(root, canonical_root, glob)
    end
  end

  defp discover_only(root, canonical_root, glob) do
    npc_root = Path.join(root, "npc")
    allowed = npc_root |> Path.join(glob) |> Path.wildcard() |> MapSet.new()

    npc_root
    |> Path.join("**/*.txt")
    |> Path.wildcard()
    |> Enum.filter(&MapSet.member?(allowed, &1))
    |> Enum.sort()
    |> Enum.reduce({[], MapSet.new()}, fn path, {sources, seen} ->
      directive_path = Path.relative_to(path, root)

      {_path, _relative, canonical} =
        expand!(root, canonical_root, directive_path, :source, nil, [])

      unless File.regular?(path) do
        Mix.raise("only match #{directive_path} is not a regular file")
      end

      if MapSet.member?(seen, canonical) do
        {sources, seen}
      else
        {[source(path, npc_root) | sources], MapSet.put(seen, canonical)}
      end
    end)
    |> elem(0)
    |> Enum.reverse()
  end

  defp discover_enabled(root, canonical_root) do
    initial = {[], MapSet.new(), MapSet.new()}

    @roots
    |> Enum.reduce(initial, &visit_conf(root, canonical_root, &1, [], nil, &2))
    |> elem(0)
    |> Enum.reverse()
  end

  defp visit_conf(
         root,
         canonical_root,
         directive_path,
         stack,
         referred_by,
         {sources, files, confs} = state
       ) do
    {path, relative, canonical} =
      expand!(root, canonical_root, directive_path, :config, referred_by, stack)

    cond do
      Enum.any?(stack, fn {identity, _relative} -> identity == canonical end) ->
        {conf, line} = referred_by

        Mix.raise(
          "config cycle at #{relative} referenced by #{conf}:#{line}; " <>
            "include chain: #{include_chain(stack, [relative])}"
        )

      MapSet.member?(confs, canonical) ->
        state

      true ->
        confs = MapSet.put(confs, canonical)
        stack = stack ++ [{canonical, relative}]

        path
        |> read_conf!(relative, referred_by, stack)
        |> traverse_conf(root, canonical_root, relative, stack, {sources, files, confs})
    end
  end

  defp traverse_conf(content, root, canonical_root, conf, stack, state) do
    content
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.reduce(state, fn {line, number}, state ->
      case directive!(line, conf, number) do
        {:import, imported} ->
          visit_conf(root, canonical_root, imported, stack, {conf, number}, state)

        {:npc, terminal} ->
          add_source(root, canonical_root, terminal, conf, number, stack, state)

        :ignore ->
          state
      end
    end)
  end

  defp read_conf!(path, relative, referred_by, chain) do
    case File.read(path) do
      {:ok, content} ->
        content

      {:error, _reason} ->
        reference =
          case referred_by do
            {conf, line} -> " referenced by #{conf}:#{line}"
            nil -> ""
          end

        Mix.raise(
          "missing config #{relative}#{reference}; include chain: #{include_chain(chain)}"
        )
    end
  end

  defp directive!(line, conf, number) do
    active = line |> String.split("//", parts: 2) |> hd() |> String.trim()

    case Regex.run(~r/^(import|npc):\s*(\S+)\s*$/, active) do
      [_, "import", path] -> {:import, path}
      [_, "npc", path] -> {:npc, path}
      nil -> malformed_or_ignore!(active, conf, number)
    end
  end

  defp malformed_or_ignore!("import:" <> _ = line, conf, number),
    do: Mix.raise("malformed import directive #{inspect(line)} in #{conf}:#{number}")

  defp malformed_or_ignore!("npc:" <> _ = line, conf, number),
    do: Mix.raise("malformed npc directive #{inspect(line)} in #{conf}:#{number}")

  defp malformed_or_ignore!(_line, _conf, _number), do: :ignore

  defp add_source(
         root,
         canonical_root,
         directive_path,
         conf,
         line,
         stack,
         {sources, files, confs} = state
       ) do
    {path, _relative_to_root, canonical} =
      expand!(root, canonical_root, directive_path, :source, {conf, line}, stack)

    cond do
      not File.regular?(path) ->
        Mix.raise(
          "missing NPC source #{directive_path} referenced by #{conf}:#{line}; " <>
            "include chain: #{include_chain(stack)}"
        )

      MapSet.member?(files, canonical) ->
        state

      true ->
        source = source(path, Path.join(root, "npc"))
        {[source | sources], MapSet.put(files, canonical), confs}
    end
  end

  defp source(path, npc_root) do
    relative = Path.relative_to(path, npc_root)
    %{path: path, relative: relative, scope: scope(relative)}
  end

  defp expand!(root, canonical_root, directive_path, kind, referred_by, stack) do
    path = Path.expand(directive_path, root)
    relative = Path.relative_to(path, root)
    label = if(kind == :config, do: "config path", else: "NPC source path")
    reference = reference(referred_by)

    unless confined?(relative) do
      Mix.raise(
        "#{label} #{directive_path} escapes rAthena root#{reference}; " <>
          "include chain: #{include_chain(stack, [directive_path])}"
      )
    end

    canonical = canonical_path!(path)
    canonical_relative = Path.relative_to(canonical, canonical_root)

    unless confined?(canonical_relative) do
      Mix.raise(
        "#{label} #{directive_path} resolves outside canonical rAthena root#{reference}; " <>
          "include chain: #{include_chain(stack, [directive_path])}"
      )
    end

    {path, relative, canonical}
  end

  defp confined?(relative) do
    Path.type(relative) != :absolute and relative != ".." and
      not String.starts_with?(relative, "../")
  end

  defp include_chain(stack, tail \\ []) do
    stack
    |> Enum.map(&elem(&1, 1))
    |> Kernel.++(tail)
    |> Enum.join(" -> ")
  end

  defp canonical_path!(path), do: path |> Path.expand() |> resolve_path(0)

  defp resolve_path(path, symlinks) do
    [root | parts] = Path.split(path)
    resolve_parts(root, parts, symlinks)
  end

  defp resolve_parts(path, [], _symlinks), do: path

  defp resolve_parts(path, [part | rest], symlinks) do
    candidate = Path.join(path, part)

    case File.lstat(candidate) do
      {:ok, %File.Stat{type: :symlink}} ->
        follow_symlink!(candidate, path, rest, symlinks)

      {:ok, _stat} ->
        resolve_parts(candidate, rest, symlinks)

      {:error, :enoent} ->
        append_parts(candidate, rest)

      {:error, reason} ->
        Mix.raise("cannot resolve filesystem path #{candidate}: #{inspect(reason)}")
    end
  end

  defp follow_symlink!(candidate, _path, _rest, symlinks) when symlinks >= @max_symlinks,
    do: Mix.raise("too many symbolic links while resolving #{candidate}")

  defp follow_symlink!(candidate, path, rest, symlinks) do
    case File.read_link(candidate) do
      {:ok, target} ->
        target
        |> Path.expand(path)
        |> append_parts(rest)
        |> resolve_path(symlinks + 1)

      {:error, reason} ->
        Mix.raise("cannot resolve symbolic link #{candidate}: #{inspect(reason)}")
    end
  end

  defp append_parts(path, parts), do: Enum.reduce(parts, path, &Path.join(&2, &1))

  defp reference({conf, line}), do: " referenced by #{conf}:#{line}"
  defp reference(nil), do: ""

  defp scope("re/" <> _), do: :renewal
  defp scope("pre-re/" <> _), do: :pre_renewal
  defp scope(_), do: :shared
end
