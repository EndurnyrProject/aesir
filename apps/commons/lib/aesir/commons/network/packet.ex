defmodule Aesir.Commons.Network.Packet do
  @moduledoc """
  Base module for packet definitions and parsing.

  This module provides the foundation for all packet types in the Ragnarok Online protocol.
  Packets follow a common structure:
  - 2 bytes: packet type (little-endian)
  - For variable-size packets: 2 bytes for length (little-endian)
  - Remaining bytes: packet data
  """
  import Bitwise

  @type packet_id :: 0x0000..0xFFFF
  @type packet_data :: binary()
  @type packet_size :: pos_integer() | :variable

  @doc """
  Behavior callback for parsing packet data.
  Returns {:ok, parsed_data} or {:error, reason}
  """
  @callback parse(packet_data()) :: {:ok, map() | :noop} | {:error, term()}

  @doc """
  Behavior callback for building a complete packet with header.
  """
  @callback build(map()) :: binary() | :noop

  @doc """
  Returns the packet ID for this packet type.
  """
  @callback packet_id() :: packet_id()

  @doc """
  Returns the size of this packet. :variable for variable-size packets.
  """
  @callback packet_size() :: packet_size()

  @doc """
  Helper to parse a packet header and determine its type and size.
  """
  def parse_header(<<packet_id::16-little, rest::binary>>) do
    {:ok, packet_id, rest}
  end

  def parse_header(_), do: {:error, :incomplete_header}

  @doc """
  Helper to parse variable-size packet header.
  """
  def parse_variable_header(<<packet_id::16-little, length::16-little, rest::binary>>) do
    {:ok, packet_id, length, rest}
  end

  def parse_variable_header(_), do: {:error, :incomplete_header}

  @doc """
  Helper to build a packet with header.
  """
  def build_packet(packet_id, data) when is_binary(data) do
    <<packet_id::16-little, data::binary>>
  end

  @doc """
  Helper to build a variable-size packet with header and length.
  """
  def build_variable_packet(packet_id, data) when is_binary(data) do
    length = byte_size(data) + 4
    <<packet_id::16-little, length::16-little, data::binary>>
  end

  def extract_string(binary) do
    case :binary.split(binary, <<0>>) do
      [string, _rest] -> string
      _ -> binary
    end
  end

  @doc """
  Create a null-terminated, fixed-length string.
  """
  def pack_string(string, length) when is_binary(string) do
    string_size = min(byte_size(string), length - 1)
    padding_size = length - string_size

    <<:binary.part(string, 0, string_size)::binary, 0::size(padding_size)-unit(8)>>
  end

  @doc """
  Encodes source and destination positions into 6 bytes.

  The encoding packs two positions into 6 bytes with 8,8 as cell offsets:
  - byte0: x0 >> 2
  - byte1: (x0 << 6) | (y0 >> 4)
  - byte2: (y0 << 4) | (x1 >> 6)
  - byte3: (x1 << 2) | (y1 >> 8)
  - byte4: y1 & 0xFF
  - byte5: (sx0 << 4) | sy0 (cell offsets, using 8,8 as per rAthena)
  """
  def encode_move_data(x0, y0, x1, y1) do
    byte0 = x0 >>> 2
    byte1 = (x0 <<< 6 ||| (y0 >>> 4 &&& 0x3F)) &&& 0xFF
    byte2 = (y0 <<< 4 ||| (x1 >>> 6 &&& 0x0F)) &&& 0xFF
    byte3 = (x1 <<< 2 ||| (y1 >>> 8 &&& 0x03)) &&& 0xFF
    byte4 = y1 &&& 0xFF
    byte5 = 8 <<< 4 ||| 8

    <<byte0, byte1, byte2, byte3, byte4, byte5>>
  end

  @doc """
  Encodes position and direction into 3 bytes.
  Uses WBUFPOS encoding from rAthena.
  """
  def encode_pos_dir(x, y, dir) do
    import Bitwise

    byte0 = x >>> 2 &&& 0xFF
    byte1 = (x <<< 6 ||| (y >>> 4 &&& 0x3F)) &&& 0xFF
    byte2 = (y <<< 4 ||| (dir &&& 0x0F)) &&& 0xFF

    <<byte0, byte1, byte2>>
  end

  @doc """
  Helper macro to define common packet fields.
  """
  defmacro __using__(_opts) do
    quote do
      import Aesir.Commons.Network.Packet

      @behaviour Aesir.Commons.Network.Packet

      @impl true
      def parse(_), do: {:ok, :noop}

      @impl true
      def build(_), do: :noop

      defoverridable parse: 1, build: 1
    end
  end
end
