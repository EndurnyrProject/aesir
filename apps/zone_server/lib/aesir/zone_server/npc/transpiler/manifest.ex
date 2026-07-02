defmodule Aesir.ZoneServer.Npc.Transpiler.Manifest do
  @moduledoc """
  Tracks what the NPC transpiler generated, so re-imports are incremental and
  never clobber hand-edited work.

  One JSON file (`priv/npc_transpile/manifest.json`) maps a stable entry key
  (source file + entry identity) to the source-body hash, the output path and
  the hash of the file as generated. `decide/3` implements the regen policy:

  | Situation                                             | Decision    |
  |-------------------------------------------------------|-------------|
  | Source unchanged                                       | `:skip`     |
  | New entry, target path free                            | `:write`    |
  | New entry, target exists outside the manifest          | `:conflict` |
  | Source changed, output still as generated              | `:write`    |
  | Source changed, output hand-edited or missing          | `:conflict` |
  """

  @type entry_record :: %{
          source_hash: String.t(),
          output_path: String.t(),
          output_hash: String.t()
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
           output_hash: rec["output_hash"]
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

  @spec hash(binary()) :: String.t()
  def hash(content), do: :sha256 |> :crypto.hash(content) |> Base.encode16(case: :lower)

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
