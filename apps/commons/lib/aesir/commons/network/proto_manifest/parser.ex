defmodule Aesir.Commons.Network.ProtoManifest.Parser do
  @moduledoc """
  Reads the routing annotations off the `Envelope` `oneof body` block of a
  `.proto` source.

  Each field declaration in that block must carry a trailing
  `// <direction> <servers> [channel]` comment; the grammar is documented in
  `proto/aesir.proto` itself. Anything unannotated, malformed, or naming an
  unknown direction/server/channel raises
  `Aesir.Commons.Network.ProtoManifest.ParseError` — which, since the parse runs
  while `Aesir.Commons.Network.ProtoManifest` compiles, fails the build.
  """

  alias Aesir.Commons.Network.ProtoManifest.ParseError
  alias Aesir.Commons.Network.QuinnetCodec

  @type entry :: %{
          number: pos_integer(),
          tag: atom(),
          module: module(),
          direction: :s2c | :c2s,
          servers: [atom()],
          channel: QuinnetCodec.channel() | nil
        }

  @directions ~w(s2c c2s)
  @servers ~w(zone account char)

  @field_regex ~r/^\s*(?<type>\w+)\s+(?<name>\w+)\s*=\s*(?<number>\d+);(?<rest>.*)$/

  @doc "Parses the annotations of the `.proto` at `path`."
  @spec parse_file!(Path.t()) :: [entry()]
  # Compile-time: reads `proto/aesir.proto` from this app's own source tree.
  # sobelow_skip ["Traversal.FileModule"]
  def parse_file!(path), do: path |> File.read!() |> parse_source!(path)

  @doc """
  Parses the annotations of a `.proto` `source`.

  `path` is only used to make error messages point at the offending file.
  """
  @spec parse_source!(String.t(), Path.t()) :: [entry()]
  def parse_source!(source, path \\ "aesir.proto") do
    namespace = parse_namespace!(source, path)

    source
    |> oneof_body!(path)
    |> String.split("\n")
    |> Enum.flat_map(&parse_line!(&1, namespace, path))
    |> Enum.sort_by(& &1.number)
  end

  @doc """
  Raises unless `entries` covers exactly `expected_tags`.

  `expected_tags` is the oneof field set of the compiled `Envelope`, so a field
  the parser missed — or an annotation for a field that no longer exists — is a
  build failure rather than a routing hole discovered at runtime.
  """
  @spec validate_coverage!([entry()], Enumerable.t()) :: [entry()]
  def validate_coverage!(entries, expected_tags) do
    parsed = MapSet.new(entries, & &1.tag)
    expected = MapSet.new(expected_tags)

    missing = MapSet.difference(expected, parsed)
    unknown = MapSet.difference(parsed, expected)

    if Enum.empty?(missing) and Enum.empty?(unknown) do
      entries
    else
      raise ParseError,
            "routing annotations out of sync with the Envelope oneof: " <>
              "missing #{inspect(MapSet.to_list(missing))}, " <>
              "unknown #{inspect(MapSet.to_list(unknown))}"
    end
  end

  defp parse_namespace!(source, path) do
    case Regex.run(~r/^package\s+([\w.]+);/m, source) do
      [_, package] ->
        package |> String.split(".") |> Enum.map(&Macro.camelize/1) |> Module.concat()

      nil ->
        raise ParseError, "#{path}: no `package` declaration found"
    end
  end

  defp oneof_body!(source, path) do
    case Regex.run(~r/oneof body \{(.*?)\n  \}/s, source, capture: :all_but_first) do
      [body] -> body
      nil -> raise ParseError, "#{path}: no `oneof body` block found in message Envelope"
    end
  end

  # sobelow_skip ["DOS.StringToAtom"]
  defp parse_line!(line, namespace, path) do
    case Regex.named_captures(@field_regex, line) do
      nil ->
        []

      %{"type" => type, "name" => name, "number" => number, "rest" => rest} ->
        {direction, servers, channel} = parse_annotation!(rest, name, path)

        [
          %{
            number: String.to_integer(number),
            tag: String.to_atom(name),
            module: Module.concat(namespace, type),
            direction: direction,
            servers: servers,
            channel: channel
          }
        ]
    end
  end

  defp parse_annotation!(rest, name, path) do
    case rest |> String.trim() |> String.split("//", parts: 2) do
      ["", annotation] -> annotation |> String.split() |> build_annotation!(name, path)
      _ -> raise ParseError, "#{path}: field `#{name}` has no routing annotation"
    end
  end

  defp build_annotation!([direction, servers | rest], name, path) do
    {parse_direction!(direction, name, path), parse_servers!(servers, name, path),
     parse_channel!(rest, direction, name, path)}
  end

  defp build_annotation!(_parts, name, path) do
    raise ParseError,
          "#{path}: field `#{name}` has a malformed routing annotation, " <>
            "expected `// <direction> <servers> [channel]`"
  end

  # sobelow_skip ["DOS.StringToAtom"]
  defp parse_direction!(direction, _name, _path) when direction in @directions,
    do: String.to_atom(direction)

  defp parse_direction!(direction, name, path) do
    raise ParseError,
          "#{path}: field `#{name}` has unknown direction #{inspect(direction)}, " <>
            "expected one of #{inspect(@directions)}"
  end

  # sobelow_skip ["DOS.StringToAtom"]
  defp parse_servers!(servers, name, path) do
    servers
    |> String.split(",")
    |> Enum.map(fn
      server when server in @servers ->
        String.to_atom(server)

      server ->
        raise ParseError,
              "#{path}: field `#{name}` names unknown server #{inspect(server)}, " <>
                "expected a comma-separated subset of #{inspect(@servers)}"
    end)
  end

  defp parse_channel!([], "c2s", _name, _path), do: nil

  # sobelow_skip ["DOS.StringToAtom"]
  defp parse_channel!([channel], "s2c", name, path) do
    legal = Enum.map(QuinnetCodec.channels(), &Atom.to_string/1)

    if channel in legal do
      String.to_atom(channel)
    else
      raise ParseError,
            "#{path}: field `#{name}` names unknown channel #{inspect(channel)}, " <>
              "expected one of #{inspect(legal)}"
    end
  end

  defp parse_channel!(_rest, "s2c", name, path) do
    raise ParseError, "#{path}: s2c field `#{name}` must declare exactly one channel"
  end

  defp parse_channel!(_rest, "c2s", name, path) do
    raise ParseError,
          "#{path}: c2s field `#{name}` must not declare a channel — " <>
            "the client picks the inbound channel"
  end
end
