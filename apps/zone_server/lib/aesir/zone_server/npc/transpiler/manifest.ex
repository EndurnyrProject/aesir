defmodule Aesir.ZoneServer.Npc.Transpiler.Manifest do
  @moduledoc """
  Tracks what the NPC transpiler generated, so re-imports are incremental and
  never clobber hand-edited work.

  One JSON file (`priv/npc_transpile/manifest.json`) maps a stable entry key
  (source file + entry identity) to the source-body hash, the output path and
  the hash of the file as generated. Placement scopes use the closed strings
  `shared`, `renewal`, and `pre_renewal`; legacy spawns without scope inherit
  the body scope derived from their stable key. This fallback is deterministic
  but cannot recover previously merged cross-scope placements, so the generated
  corpus still requires clean regeneration before pre-renewal deployment.

  `decide/3` implements the regen policy:

  | Situation                                             | Decision    |
  |-------------------------------------------------------|-------------|
  | Source unchanged                                       | `:skip`     |
  | New entry, target path free                            | `:write`    |
  | New entry, target exists outside the manifest          | `:conflict` |
  | Source changed, output still as generated              | `:write`    |
  | Source changed, output hand-edited or missing          | `:conflict` |
  """

  alias Aesir.ZoneServer.Npc.ContentScope

  @type entry_record :: %{
          source_hash: String.t(),
          output_path: String.t(),
          output_hash: String.t(),
          spawns: [map()],
          module: String.t() | nil
        }
  @type t :: %{String.t() => entry_record()}
  @type output_state :: :missing | {:present, String.t()}
  @type decision :: :skip | :write | :conflict

  @spec load(Path.t()) :: t()
  def load(path) do
    with {:ok, json} <- File.read(path),
         {:ok, data} <- Jason.decode(json) do
      Map.new(data, fn {key, rec} ->
        {key,
         %{
           source_hash: rec["source_hash"],
           output_path: rec["output_path"],
           output_hash: rec["output_hash"],
           spawns: decode_spawns(rec["spawns"], body_scope(key)),
           module: rec["module"]
         }}
      end)
    else
      _ -> %{}
    end
  end

  @spec save(t(), Path.t()) :: :ok
  def save(manifest, path) do
    File.mkdir_p!(Path.dirname(path))

    json =
      manifest
      |> Enum.sort_by(&elem(&1, 0))
      |> Enum.map(fn {key, rec} ->
        {key,
         Jason.OrderedObject.new(
           module: rec.module,
           output_hash: rec.output_hash,
           output_path: rec.output_path,
           source_hash: rec.source_hash,
           spawns: Enum.map(rec.spawns, &encode_spawn/1)
         )}
      end)
      |> Jason.OrderedObject.new()
      |> Jason.encode!(pretty: true)

    File.write!(path, json <> "\n")
  end

  @doc "A stable key for an entry: source file plus entry identity."
  @spec key(map()) :: String.t()
  def key(entry) do
    placement =
      case entry do
        %{map: map, x: x, y: y} -> "#{map}:#{x}:#{y}"
        _ -> "-"
      end

    "#{entry.file}|#{entry.kind}|#{entry[:name]}|#{placement}"
  end

  @doc "Returns the NPC-root-relative source file stored in a manifest key."
  @spec source_file(String.t()) :: Path.t()
  def source_file(key) do
    case String.split(key, "|", parts: 2) do
      [file, _entry] when file != "" -> file
      _ -> raise ArgumentError, "invalid NPC manifest key: #{inspect(key)}"
    end
  end

  @doc "Returns the script body's content scope derived from its stable manifest key."
  @spec body_scope(String.t()) :: ContentScope.t()
  def body_scope(key) do
    case source_file(key) do
      "re/" <> _path -> :renewal
      "pre-re/" <> _path -> :pre_renewal
      _path -> :shared
    end
  end

  @spec hash(binary()) :: String.t()
  def hash(content), do: :sha256 |> :crypto.hash(content) |> Base.encode16(case: :lower)

  # Spawn maps round-trip through JSON as string-keyed objects with `trigger`
  # tuples serialized to arrays; decode them back to the exact atom-keyed shape
  # `resolve_placements` produces so regen hashes stay stable across runs.
  defp decode_spawns(nil, _body_scope), do: []

  defp decode_spawns(spawns, body_scope) when is_list(spawns) do
    Enum.map(spawns, fn spawn ->
      %{
        map: spawn["map"],
        x: spawn["x"],
        y: spawn["y"],
        dir: spawn["dir"],
        sprite: spawn["sprite"],
        name: spawn["name"]
      }
      |> put_present(:unique_name, spawn["unique_name"])
      |> put_present(:trigger, decode_trigger(spawn["trigger"]))
      |> Map.put(:scope, decode_spawn_scope(spawn, body_scope))
    end)
  end

  defp put_present(map, _key, nil), do: map
  defp put_present(map, key, value), do: Map.put(map, key, value)

  defp decode_trigger(nil), do: nil
  defp decode_trigger([tx, ty]), do: {tx, ty}

  defp decode_spawn_scope(spawn, body_scope) do
    case Map.fetch(spawn, "scope") do
      :error -> body_scope
      {:ok, scope} -> decode_scope(scope)
    end
  end

  defp decode_scope("shared"), do: :shared
  defp decode_scope("renewal"), do: :renewal
  defp decode_scope("pre_renewal"), do: :pre_renewal

  defp decode_scope(scope),
    do: raise(ArgumentError, "unknown NPC manifest placement scope #{inspect(scope)}")

  defp encode_spawn(spawn) do
    spawn
    |> encode_trigger()
    |> encode_spawn_scope()
  end

  defp encode_trigger(%{trigger: {tx, ty}} = spawn), do: %{spawn | trigger: [tx, ty]}
  defp encode_trigger(spawn), do: spawn

  defp encode_spawn_scope(%{scope: scope} = spawn), do: %{spawn | scope: encode_scope(scope)}
  defp encode_spawn_scope(spawn), do: spawn

  defp encode_scope(:shared), do: "shared"
  defp encode_scope(:renewal), do: "renewal"
  defp encode_scope(:pre_renewal), do: "pre_renewal"

  defp encode_scope(scope),
    do: raise(ArgumentError, "unknown NPC manifest placement scope #{inspect(scope)}")

  @doc """
  Regen decision for one entry given its manifest record (or `nil` for a new
  entry), the current source hash, and the state of the output file on disk.
  """
  @spec decide(entry_record() | nil, String.t(), output_state()) :: decision()
  def decide(nil, _source_hash, :missing), do: :write
  def decide(nil, _source_hash, {:present, _}), do: :conflict

  def decide(%{source_hash: same}, same, _output_state), do: :skip

  def decide(%{output_hash: generated}, _source_hash, {:present, generated}), do: :write
  def decide(%{}, _source_hash, _output_state), do: :conflict
end
