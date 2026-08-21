defmodule Aesir.Commons.Network.ProtoManifest do
  @moduledoc """
  Compile-time routing manifest parsed from the `Envelope` `oneof body` block of
  `proto/aesir.proto`.

  Every `body` field carries a trailing routing annotation
  (`// <direction> <servers> [channel]`, documented in the `.proto` itself). This
  module is the reader for it: it turns those annotations into lookup tables so a
  server can generate its outbound routing table instead of hand-maintaining a
  parallel copy of the schema.

      ProtoManifest.outbound(:zone)
      #=> [{Aesir.Net.NavigateTo, :world, :navigate_to}, ...]

      ProtoManifest.inbound(:zone)
      #=> [Aesir.Net.MoveRequest, ...]

  The annotations are validated while this module compiles, so the build fails on
  a missing annotation, an unknown direction/server/channel, a channel on a `c2s`
  field, or a field name that is not an `Envelope` oneof member. A new message
  therefore cannot reach runtime without a declared direction, server and channel.
  """

  alias Aesir.Commons.Network.ProtoManifest.Parser
  alias Aesir.Commons.Network.QuinnetCodec

  @proto_file "proto/aesir.proto"
  @external_resource @proto_file

  @type server :: :zone | :account | :char
  @type direction :: :s2c | :c2s
  @type outbound_entry :: {module(), QuinnetCodec.channel(), atom()}

  @servers [:zone, :account, :char]

  Code.ensure_compiled!(Aesir.Net.Envelope)

  @envelope_tags for {name, field} <- Aesir.Net.Envelope.schema().fields,
                     match?(%Protox.OneOf{parent: :body}, field.kind),
                     do: name

  @entries @proto_file |> Parser.parse_file!() |> Parser.validate_coverage!(@envelope_tags)

  @outbound Map.new(@servers, fn server ->
              entries =
                for %{direction: :s2c, servers: servers, module: mod, channel: ch, tag: tag} <-
                      @entries,
                    server in servers,
                    do: {mod, ch, tag}

              {server, entries}
            end)

  @inbound Map.new(@servers, fn server ->
             entries =
               for %{direction: :c2s, servers: servers, module: mod} <- @entries,
                   server in servers,
                   do: mod

             {server, entries}
           end)

  @doc """
  Returns `{module, channel, oneof_tag}` for every message `server` sends to the
  client, in `.proto` field-number order.
  """
  @spec outbound(server()) :: [outbound_entry()]
  def outbound(server) when server in @servers, do: Map.fetch!(@outbound, server)

  @doc "Returns every message module `server` accepts from the client."
  @spec inbound(server()) :: [module()]
  def inbound(server) when server in @servers, do: Map.fetch!(@inbound, server)

  @doc "Returns the known server names."
  @spec servers() :: [server()]
  def servers, do: @servers

  @doc """
  Returns every annotated `Envelope` body field, in `.proto` field-number order.

  The raw table behind `outbound/1` and `inbound/1`; `mix aesir.gen.proto_routing`
  renders it as the `proto/routing.json` sidecar the client consumes.
  """
  @spec entries() :: [Parser.entry()]
  def entries, do: @entries
end
