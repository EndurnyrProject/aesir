defmodule Aesir.Commons.Network.QuinnetCodecTest do
  use ExUnit.Case, async: true

  alias Aesir.Commons.Network.QuinnetCodec

  describe "channel mapping" do
    test "maps names to ids and back" do
      assert QuinnetCodec.channel_id(:control) == 0
      assert QuinnetCodec.channel_id(:snapshots) == 4
      assert QuinnetCodec.channel_name(0) == :control
      assert QuinnetCodec.channel_name(4) == :snapshots
      assert QuinnetCodec.channel_name(99) == :unknown
    end
  end

  describe "reliable framing" do
    test "length prefix counts the channel-id byte" do
      <<length::32-big, channel_id::8, payload::binary>> = QuinnetCodec.encode_reliable(1, "abc")
      assert length == 4
      assert channel_id == 1
      assert payload == "abc"
    end

    test "round-trips a frame with no trailing bytes" do
      frame = QuinnetCodec.encode_reliable(2, "hello world")
      assert {:ok, 2, "hello world", ""} = QuinnetCodec.decode_reliable(frame)
    end

    test "round-trips an empty payload" do
      frame = QuinnetCodec.encode_reliable(0, "")
      assert {:ok, 0, "", ""} = QuinnetCodec.decode_reliable(frame)
    end

    test "decodes two concatenated frames in sequence" do
      buffer =
        QuinnetCodec.encode_reliable(0, "first") <> QuinnetCodec.encode_reliable(1, "second")

      assert {:ok, 0, "first", rest} = QuinnetCodec.decode_reliable(buffer)
      assert {:ok, 1, "second", ""} = QuinnetCodec.decode_reliable(rest)
    end

    test "returns {:more, buffer} on a header-only partial buffer" do
      <<partial::binary-size(2), _::binary>> = QuinnetCodec.encode_reliable(0, "data")
      assert {:more, ^partial} = QuinnetCodec.decode_reliable(partial)
    end

    test "returns {:more, buffer} when the payload is incomplete" do
      <<partial::binary-size(6), _::binary>> = QuinnetCodec.encode_reliable(0, "abcdef")
      assert {:more, ^partial} = QuinnetCodec.decode_reliable(partial)
    end

    test "rejects a frame larger than the max" do
      oversized = <<16_777_217::32-big, 0::8>>
      assert {:error, :frame_too_large} = QuinnetCodec.decode_reliable(oversized)
    end

    test "rejects a zero-length frame" do
      assert {:error, :invalid_frame} = QuinnetCodec.decode_reliable(<<0::32-big, 0::8>>)
    end
  end

  describe "client-id handshake" do
    test "frames an 8-byte id behind a length-delimited 4-byte prefix" do
      assert <<8::32-big, 42::64-big>> = QuinnetCodec.encode_client_id(42)
    end
  end

  describe "datagram framing" do
    test "round-trips a datagram" do
      datagram = QuinnetCodec.encode_datagram(4, "snapshot")
      assert {:ok, 4, "snapshot"} = QuinnetCodec.decode_datagram(datagram)
    end

    test "datagram carries no length prefix" do
      assert <<4::8, "x">> = QuinnetCodec.encode_datagram(4, "x")
    end

    test "rejects an empty datagram" do
      assert {:error, :empty_datagram} = QuinnetCodec.decode_datagram(<<>>)
    end
  end
end
