defmodule Aesir.ZoneServer.Npc.Transpiler.FileParser do
  @moduledoc """
  Splits an rAthena `npc/*.txt` file into top-level entries.

  Recognizes placed and floating `script` NPCs, `duplicate()` placements and
  `function` definitions (returned with their raw `{...}` bodies for the
  lexer/parser), records `shop`-family and `mapflag` lines as `:skipped`
  (they have dedicated importers or are out of scope), silently drops
  `warp`/`monster` lines (already imported), and returns malformed headers as
  `:error` entries without aborting the rest of the file.

  Comments are stripped up front (newlines preserved, string literals
  respected) so header detection and brace matching never trip over them.

  A few upstream files carry legacy EUC-KR bytes (Korean NPC names); those
  are not representable without a codec, so invalid UTF-8 bytes are scrubbed
  to `?` byte-for-byte up front, keeping every downstream string (names,
  bodies, generated source) valid UTF-8 with positions intact.
  """

  @skipped_types ~w(shop cashshop itemshop pointshop marketshop mapflag)
  @dropped_types ~w(warp warp2 monster boss_monster)

  @typedoc """
  One top-level entry. `:kind` is `:script`, `:floating`, `:duplicate`,
  `:function`, `:skipped` or `:error`; the other keys depend on the kind.
  Every entry carries `:file` and `:line`.
  """
  @type entry :: %{required(:kind) => atom(), optional(atom()) => term()}

  @spec parse(binary(), Path.t()) :: {:ok, [entry()]}
  def parse(source, path \\ "nofile") do
    entries =
      source
      |> scrub_utf8()
      |> strip_comments()
      |> scan(1, path, [])
      |> Enum.reverse()

    {:ok, entries}
  end

  defp scrub_utf8(source) do
    if String.valid?(source) do
      source
    else
      source |> String.chunk(:valid) |> Enum.map_join(&scrub_chunk/1)
    end
  end

  defp scrub_chunk(chunk) do
    if String.valid?(chunk), do: chunk, else: String.duplicate("?", byte_size(chunk))
  end

  defp scan("", _line_no, _path, acc), do: acc

  defp scan(text, line_no, path, acc) do
    {line, rest} = take_line(text)

    case classify(String.trim(line)) do
      :blank ->
        scan(rest, line_no + 1, path, acc)

      {:inline, entry} ->
        scan(rest, line_no + 1, path, [finish(entry, line_no, path) | acc])

      {:with_body, entry, brace_part} ->
        case extract_body(brace_part <> "\n" <> rest) do
          {:ok, body, newlines, remainder} ->
            entry = finish(Map.put(entry, :body, body), line_no, path)
            scan(remainder, line_no + newlines, path, [entry | acc])

          {:error, reason} ->
            [finish(%{kind: :error, reason: reason}, line_no, path) | acc]
        end

      {:error, reason} ->
        scan(rest, line_no + 1, path, [
          finish(%{kind: :error, reason: reason}, line_no, path) | acc
        ])
    end
  end

  defp finish(entry, line_no, path), do: Map.merge(entry, %{line: line_no, file: path})

  defp take_line(text) do
    case :binary.split(text, "\n") do
      [line, rest] -> {line, rest}
      [line] -> {line, ""}
    end
  end

  defp classify(""), do: :blank

  defp classify(line) do
    case String.split(line, "\t", trim: true) do
      [] -> :blank
      fields -> classify_fields(fields, line)
    end
  end

  defp classify_fields(["function", "script", name | _], line) do
    with_body(%{kind: :function, name: name}, line)
  end

  # The script keyword may carry a state flag: `script(CLOAKED|DISABLED|HIDDEN)`.
  defp classify_fields([pos, "script" <> flag, name, _tail | _], line)
       when flag == "" or binary_part(flag, 0, 1) == "(" do
    case parse_placement(pos) do
      :floating ->
        with_body(%{kind: :floating, name: name, sprite: sprite_of(line)}, line)

      {:ok, placement} ->
        %{
          kind: :script,
          name: name,
          sprite: sprite_of(line),
          touch: touch_of(line),
          flag: parse_flag(flag)
        }
        |> Map.merge(placement)
        |> with_body(line)

      :error ->
        # Still consume the body so one bad header does not cascade into a
        # per-line error for every statement in it.
        with_body(%{kind: :error, reason: {:bad_placement, pos}}, line)
    end
  end

  defp classify_fields([pos, "duplicate(" <> source, name, tail | _], _line) do
    {sprite, touch} = parse_sprite_tail(tail)
    source = String.trim_trailing(source, ")")
    entry = %{kind: :duplicate, source: source, name: name, sprite: sprite, touch: touch}

    case parse_placement(pos) do
      {:ok, placement} -> {:inline, Map.merge(entry, placement)}
      :floating -> {:inline, entry}
      :error -> {:error, {:bad_placement, pos}}
    end
  end

  defp classify_fields([_pos, type | _], line) do
    # `warp`/`shop`-family keywords may carry a `(DISABLED)`-style flag too.
    case type |> :binary.split("(") |> hd() do
      base when base in @skipped_types -> {:inline, %{kind: :skipped, type: base}}
      base when base in @dropped_types -> :blank
      _ -> {:error, {:unrecognized, String.slice(line, 0, 60)}}
    end
  end

  defp classify_fields(_fields, line), do: {:error, {:unrecognized, String.slice(line, 0, 60)}}

  defp parse_flag(""), do: nil
  defp parse_flag(flag), do: flag |> String.trim_leading("(") |> String.trim_trailing(")")

  # Splits the header line at its first `{` so the body walker can take over;
  # the brace is required on the header line in rAthena's format.
  defp with_body(entry, line) do
    case :binary.split(line, "{") do
      [_head, tail] -> {:with_body, entry, "{" <> tail}
      [_no_brace] -> {:error, :missing_body_brace}
    end
  end

  # The sprite id sits between the last header tab and the first `,` of the
  # tail; it may be numeric or a constant name (resolved later).
  defp sprite_of(line) do
    line
    |> String.split("\t", trim: true)
    |> List.last()
    |> parse_sprite_tail()
    |> elem(0)
  end

  defp touch_of(line) do
    line
    |> String.split("\t", trim: true)
    |> List.last()
    |> parse_sprite_tail()
    |> elem(1)
  end

  # Tail forms: `<sprite>`, `<sprite>,{`, `<sprite>,<tx>,<ty>` or
  # `<sprite>,<tx>,<ty>,{`.
  defp parse_sprite_tail(tail) do
    case tail |> :binary.split("{") |> hd() |> String.split(",", trim: true) do
      [sprite, tx, ty | _] -> {parse_sprite(sprite), parse_touch(tx, ty)}
      [sprite | _] -> {parse_sprite(sprite), nil}
      [] -> {nil, nil}
    end
  end

  defp parse_sprite(sprite) do
    sprite = String.trim(sprite)

    case Integer.parse(sprite) do
      {n, ""} -> n
      _ -> sprite
    end
  end

  defp parse_touch(tx, ty) do
    with {x, ""} <- Integer.parse(String.trim(tx)),
         {y, ""} <- Integer.parse(String.trim(ty)) do
      {x, y}
    else
      _ -> nil
    end
  end

  defp parse_placement("-"), do: :floating

  # Trailing extra fields after the facing (rare, tolerated by rAthena) are
  # ignored.
  defp parse_placement(pos) do
    case String.split(pos, ",") do
      [map, x, y] -> build_placement(map, x, y, "0")
      [map, x, y, dir | _extra] -> build_placement(map, x, y, dir)
      _ -> :error
    end
  end

  defp build_placement(map, x, y, dir) do
    with {x, ""} <- Integer.parse(String.trim(x)),
         {y, ""} <- Integer.parse(String.trim(y)),
         {dir, ""} <- Integer.parse(String.trim(dir)) do
      {:ok, %{map: String.trim(map), x: x, y: y, dir: dir}}
    else
      _ -> :error
    end
  end

  # -- body extraction ---------------------------------------------------------

  # `text` starts at the opening `{`. Walks it with string awareness, returning
  # the body between the outer braces, the number of newlines consumed, and the
  # remaining text after the closing brace.
  defp extract_body("{" <> rest), do: walk_body(rest, 1, false, 0, [])
  defp extract_body(_), do: {:error, :missing_body_brace}

  defp walk_body("", _depth, _in_str, _nl, _acc), do: {:error, :unterminated_body}

  defp walk_body(<<?\\, c, rest::binary>>, depth, true, nl, acc),
    do: walk_body(rest, depth, true, nl, [<<?\\, c>> | acc])

  defp walk_body(<<?", rest::binary>>, depth, in_str, nl, acc),
    do: walk_body(rest, depth, not in_str, nl, [?" | acc])

  defp walk_body(<<?{, rest::binary>>, depth, false, nl, acc),
    do: walk_body(rest, depth + 1, false, nl, [?{ | acc])

  defp walk_body(<<?}, rest::binary>>, 1, false, nl, acc),
    do: {:ok, acc |> Enum.reverse() |> IO.iodata_to_binary(), nl, rest}

  defp walk_body(<<?}, rest::binary>>, depth, false, nl, acc),
    do: walk_body(rest, depth - 1, false, nl, [?} | acc])

  defp walk_body(<<?\n, rest::binary>>, depth, in_str, nl, acc),
    do: walk_body(rest, depth, in_str, nl + 1, [?\n | acc])

  defp walk_body(<<c, rest::binary>>, depth, in_str, nl, acc),
    do: walk_body(rest, depth, in_str, nl, [c | acc])

  # -- comment stripping -------------------------------------------------------

  # Replaces `//` and `/* */` comment content with spaces (newlines preserved,
  # strings respected) so downstream line/brace scanning stays position-exact.
  defp strip_comments(source), do: strip(source, :code, [])

  defp strip("", _state, acc), do: acc |> Enum.reverse() |> IO.iodata_to_binary()

  defp strip(<<?", rest::binary>>, :code, acc), do: strip(rest, :str, [?" | acc])
  defp strip(<<?\\, c, rest::binary>>, :str, acc), do: strip(rest, :str, [<<?\\, c>> | acc])
  defp strip(<<?", rest::binary>>, :str, acc), do: strip(rest, :code, [?" | acc])

  defp strip(<<"//", rest::binary>>, :code, acc), do: strip(rest, :line_comment, acc)
  defp strip(<<"/*", rest::binary>>, :code, acc), do: strip(rest, :block_comment, acc)

  defp strip(<<?\n, rest::binary>>, :line_comment, acc), do: strip(rest, :code, [?\n | acc])
  defp strip(<<_c, rest::binary>>, :line_comment, acc), do: strip(rest, :line_comment, acc)

  defp strip(<<"*/", rest::binary>>, :block_comment, acc), do: strip(rest, :code, acc)

  defp strip(<<?\n, rest::binary>>, :block_comment, acc),
    do: strip(rest, :block_comment, [?\n | acc])

  defp strip(<<_c, rest::binary>>, :block_comment, acc), do: strip(rest, :block_comment, acc)

  defp strip(<<c, rest::binary>>, state, acc), do: strip(rest, state, [c | acc])
end
