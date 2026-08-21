defmodule Mix.Tasks.Aesir.Gen.ProtoRouting do
  @shortdoc "Emits proto/routing.json from the aesir.proto routing annotations"
  @moduledoc """
  Transcribes the routing annotations of the `Envelope` `oneof body` block into a
  machine-readable sidecar next to the schema.

      mix aesir.gen.proto_routing [--check]

  The annotations (`// <direction> <servers> [channel]`) are the single source of
  truth, but they are comments: protox drops protobuf custom options, and with
  `import "google/protobuf/descriptor.proto"` in the file it stops generating the
  `Aesir.Net.*` structs entirely — so the metadata cannot ride on `FieldOptions`.
  This task hands non-Elixir consumers (the Rust client) the same table as JSON
  rather than asking them to parse comments, so both ends agree on which channel
  a message rides and which direction it travels.

  The output is deterministic (fields in `.proto` number order, keys in a fixed
  order) and the task is idempotent: re-running produces no git diff. `--check`
  verifies the checked-in file is current and fails when it is stale, which is
  how the test suite gates it.
  """
  use Mix.Task

  alias Aesir.Commons.Network.ProtoManifest
  alias Aesir.Commons.Network.QuinnetCodec

  @output Path.join(~w(proto routing.json))

  @impl Mix.Task
  def run(args) do
    {opts, _rest} = OptionParser.parse!(args, strict: [check: :boolean])
    path = output_path()

    if opts[:check] do
      check!(path)
    else
      File.write!(path, render())
      Mix.shell().info("wrote #{path}")
    end
  end

  @doc """
  Returns the sidecar path, whether the task runs from the umbrella root or from
  inside the `commons` app.
  """
  @spec output_path() :: Path.t()
  def output_path do
    case Mix.Project.apps_paths() do
      nil -> @output
      apps_paths -> apps_paths |> Map.fetch!(:commons) |> Path.join(@output)
    end
  end

  @doc "Renders the sidecar contents for the current annotations."
  @spec render() :: String.t()
  def render do
    channels =
      Enum.map_join(QuinnetCodec.channels(), ", ", fn channel ->
        ~s("#{channel}": #{QuinnetCodec.channel_id(channel)})
      end)

    messages = Enum.map_join(ProtoManifest.entries(), ",\n", &("    " <> render_entry(&1)))

    """
    {
      "generator": "mix aesir.gen.proto_routing",
      "source": "proto/aesir.proto",
      "channels": {#{channels}},
      "messages": [
    #{messages}
      ]
    }
    """
  end

  @doc "Returns true when the checked-in sidecar matches the current annotations."
  @spec current?() :: boolean()
  def current?, do: File.read(output_path()) == {:ok, render()}

  defp render_entry(entry) do
    servers = Enum.map_join(entry.servers, ", ", &~s("#{&1}"))

    fields = [
      ~s("field": #{entry.number}),
      ~s("tag": "#{entry.tag}"),
      ~s("message": "#{entry.module |> Module.split() |> List.last()}"),
      ~s("direction": "#{entry.direction}"),
      ~s("servers": [#{servers}])
    ]

    fields = if entry.channel, do: fields ++ [~s("channel": "#{entry.channel}")], else: fields

    "{" <> Enum.join(fields, ", ") <> "}"
  end

  defp check!(path) do
    if current?() do
      Mix.shell().info("#{path} is up to date")
    else
      Mix.raise("#{path} is stale — run `mix aesir.gen.proto_routing`")
    end
  end
end
