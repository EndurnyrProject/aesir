defmodule Aesir.ZoneServer.Network.MessageRouter do
  @moduledoc """
  Maps every outbound (server -> client) `Aesir.Net.*` zone message to the
  `bevy_quinnet` channel it rides and the `Aesir.Net.Envelope` oneof tag that
  wraps it.

  This is the single seam that keeps the dispatch refactor mechanical: handlers
  build a struct and a lookup here decides reliable-vs-datagram channel and the
  `Envelope` oneof field. The returned `tag` equals the proto oneof field name so
  `Aesir.Commons.Network.QuicConnection.send_response/3` wraps it correctly.

  The table is not written by hand: every clause is generated from the routing
  annotations in `proto/aesir.proto` via `Aesir.Commons.Network.ProtoManifest`,
  so the schema is the single source of truth and a new `s2c zone` message is
  routable the moment it is declared. Inbound client intent structs are
  intentionally absent: they never pass through `route/1`.
  """

  alias Aesir.Commons.Network.ProtoManifest
  alias Aesir.Commons.Network.QuinnetCodec

  @doc """
  Returns the `{channel, oneof_tag}` for an outbound zone message struct.

  Raises `FunctionClauseError` for an unmapped struct so a forgotten mapping
  surfaces at development time rather than being silently swallowed.
  """
  @spec route(struct()) :: {QuinnetCodec.channel(), atom()}
  for {module, channel, tag} <- ProtoManifest.outbound(:zone) do
    def route(%unquote(module){}), do: {unquote(channel), unquote(tag)}
  end

  @doc "Returns the permitted delivery audience for an outbound message."
  @spec delivery_scope(struct()) :: :owner_only | :area
  def delivery_scope(%Aesir.Net.HomunculusResult{}), do: :owner_only
  def delivery_scope(%Aesir.Net.HomunculusPrivateState{}), do: :owner_only
  def delivery_scope(%Aesir.Net.WaitingRoomJoinResult{}), do: :owner_only
  def delivery_scope(_message), do: :area

  @doc """
  Routes `message` and pushes it to the owning `QuicConnection` `pid` as
  `{:send, channel, {tag, message}}` — the async outbound path every handler
  uses to send an `Aesir.Net.*` struct to its client.
  """
  @spec send_to(pid(), struct()) :: :ok
  def send_to(connection_pid, message) do
    {channel, tag} = route(message)
    send(connection_pid, {:send, channel, {tag, message}})
    :ok
  end
end
