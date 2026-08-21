defmodule Aesir.Commons.Network.QuinnetCodec do
  @moduledoc """
  Wire framing compatible with the `bevy_quinnet` client library.

  `bevy_quinnet` layers its own channel multiplexing and message framing on top
  of QUIC. The server must reproduce that framing byte-for-byte. 
  The payload inside the framing is a single `Aesir.Net.Envelope` protobuf message 
  this module does not touch the payload, only the frame around it.

  ## Reliable channels (QUIC streams)

      <<length::32-big, channel_id::8, payload::binary>>

  `length` counts the channel-id byte plus the payload (`1 + byte_size(payload)`),
  big-endian, matching `bevy_quinnet`'s `QuinnetProtocolCodec`. A reliable channel
  is carried on its own QUIC stream; messages on the same stream are concatenated,
  so `decode_reliable/1` peels one frame and returns the remaining buffer.

  ## Unreliable channel (QUIC datagrams)

      <<channel_id::8, payload::binary>>

  No length prefix — the datagram boundary delimits the message.

  ## Client-id handshake

  With `bevy_quinnet`'s `shared-client-id` feature (a default), the client blocks
  right after the QUIC handshake waiting for the server to open a dedicated
  **bidirectional** stream and send it an assigned `ClientId` (`u64`). The frame
  is a plain `tokio_util` `LengthDelimitedCodec` frame (4-byte big-endian length
  prefix over an 8-byte big-endian id), *not* a channel frame:

      <<8::32-big, client_id::64-big>>

  ## Channels

  Logical channels map to fixed `bevy_quinnet` channel ids (assigned in creation
  order on both ends):

      0 control | 1 gameplay | 2 world | 3 bulk | 4 snapshots
  """

  @max_reliable_frame 8 * 1_024 * 1_024
  @client_id_byte_size 8

  @channel_ids %{control: 0, gameplay: 1, world: 2, bulk: 3, snapshots: 4}
  @channel_names Map.new(@channel_ids, fn {name, id} -> {id, name} end)

  @type channel :: :control | :gameplay | :world | :bulk | :snapshots
  @type channel_id :: 0..255
  @type decode_reliable_result ::
          {:ok, channel_id(), binary(), binary()}
          | {:more, binary()}
          | {:error, :frame_too_large | :invalid_frame}

  @doc "Returns every logical channel name, in channel-id order."
  @spec channels() :: [channel()]
  def channels, do: Enum.sort_by(Map.keys(@channel_ids), &Map.fetch!(@channel_ids, &1))

  @doc "Returns the numeric channel id for a logical channel name."
  @spec channel_id(channel()) :: channel_id()
  def channel_id(name) when is_map_key(@channel_ids, name), do: Map.fetch!(@channel_ids, name)

  @doc "Returns the logical channel name for a numeric channel id, or `:unknown`."
  @spec channel_name(channel_id()) :: channel() | :unknown
  def channel_name(id), do: Map.get(@channel_names, id, :unknown)

  @doc "Frames a payload for a reliable channel (length-prefixed, channel-tagged)."
  @spec encode_reliable(channel_id(), binary()) :: binary()
  def encode_reliable(channel_id, payload)
      when channel_id in 0..255 and is_binary(payload) do
    length = 1 + byte_size(payload)
    <<length::32-big, channel_id::8, payload::binary>>
  end

  @doc """
  Peels one reliable frame from a stream buffer.

  Returns `{:ok, channel_id, payload, rest}` with any trailing bytes, `{:more,
  buffer}` when the buffer holds less than a full frame, or `{:error, reason}`
  for a malformed/oversized frame.
  """
  @spec decode_reliable(binary()) :: decode_reliable_result()
  def decode_reliable(<<length::32-big, _::binary>>) when length > @max_reliable_frame,
    do: {:error, :frame_too_large}

  def decode_reliable(<<0::32-big, _::binary>>), do: {:error, :invalid_frame}

  def decode_reliable(<<length::32-big, rest::binary>> = buffer) do
    payload_len = length - 1

    case rest do
      <<channel_id::8, payload::binary-size(^payload_len), tail::binary>> ->
        {:ok, channel_id, payload, tail}

      _ ->
        {:more, buffer}
    end
  end

  def decode_reliable(buffer) when is_binary(buffer), do: {:more, buffer}

  @doc """
  Frames the `bevy_quinnet` client-id handshake message.

  Sent on a server-initiated bidirectional stream right after the connection is
  established; the client reads it with a plain `LengthDelimitedCodec` before it
  considers itself connected.
  """
  @spec encode_client_id(non_neg_integer()) :: binary()
  def encode_client_id(client_id) when client_id in 0..0xFFFF_FFFF_FFFF_FFFF do
    <<@client_id_byte_size::32-big, client_id::64-big>>
  end

  @doc "Builds a datagram for the unreliable channel (channel-tagged, no length prefix)."
  @spec encode_datagram(channel_id(), binary()) :: binary()
  def encode_datagram(channel_id, payload)
      when channel_id in 0..255 and is_binary(payload) do
    <<channel_id::8, payload::binary>>
  end

  @doc "Splits a datagram into its channel id and payload."
  @spec decode_datagram(binary()) :: {:ok, channel_id(), binary()} | {:error, :empty_datagram}
  def decode_datagram(<<channel_id::8, payload::binary>>), do: {:ok, channel_id, payload}
  def decode_datagram(<<>>), do: {:error, :empty_datagram}
end
