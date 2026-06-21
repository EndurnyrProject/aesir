defmodule Aesir.Commons.Network.QuicConnectionTest do
  use ExUnit.Case, async: true

  alias Aesir.Commons.Network.QuicConnection
  alias Aesir.Commons.Network.QuinnetCodec
  alias Aesir.Net.CharAuthFailed
  alias Aesir.Net.Envelope
  alias Aesir.Net.Hello
  alias Aesir.Net.HelloAck

  defmodule FakeTransport do
    @moduledoc false
    def open_stream(_conn), do: {:ok, 100}

    def open_unidirectional_stream(_conn), do: {:ok, 200}

    def send_data(conn, sid, data, _fin) do
      send(conn, {:sent, sid, data})
      :ok
    end

    def send_datagram(conn, data) do
      send(conn, {:datagram_sent, data})
      :ok
    end

    def close(_conn, _reason), do: :ok
  end

  defmodule EchoHandler do
    @moduledoc false
    @behaviour Aesir.Commons.Network.QuicConnection

    @impl true
    def handle_message(%Hello{protocol_version: version}, :control, session_data) do
      {:ok, session_data, [{:hello_ack, %HelloAck{protocol_version: version, accepted: true}}]}
    end

    def handle_message(_message, _channel, session_data), do: {:ok, session_data}
  end

  defp start_owner do
    parent = self()

    {:ok, pid} =
      start_supervised(
        {QuicConnection, conn: parent, impl_module: EchoHandler, transport: FakeTransport}
      )

    {pid, parent}
  end

  defp control_frame(message, tag) do
    {:ok, iodata, _size} = Envelope.encode(%Envelope{seq: 1, body: {tag, message}})
    QuinnetCodec.encode_reliable(QuinnetCodec.channel_id(:control), IO.iodata_to_binary(iodata))
  end

  test "decodes a control Hello and frames a HelloAck back on the control channel" do
    {pid, parent} = start_owner()
    frame = control_frame(%Hello{protocol_version: 3, build: "dev"}, :hello)

    send(pid, {:quic, parent, {:stream_data, 0, frame, false}})

    assert_receive {:sent, _sid, out_frame}
    assert {:ok, 0, payload, ""} = QuinnetCodec.decode_reliable(out_frame)

    assert {:ok, %Envelope{body: {:hello_ack, %HelloAck{accepted: true, protocol_version: 3}}}} =
             Envelope.decode(payload)
  end

  test "reassembles a frame delivered across two stream_data chunks" do
    {pid, parent} = start_owner()
    frame = control_frame(%Hello{protocol_version: 9, build: "dev"}, :hello)
    split = div(byte_size(frame), 2)
    <<first::binary-size(^split), second::binary>> = frame

    send(pid, {:quic, parent, {:stream_data, 0, first, false}})
    refute_receive {:sent, _sid, _data}, 50

    send(pid, {:quic, parent, {:stream_data, 0, second, false}})
    assert_receive {:sent, _sid, out_frame}
    assert {:ok, 0, payload, ""} = QuinnetCodec.decode_reliable(out_frame)

    assert {:ok, %Envelope{body: {:hello_ack, %HelloAck{protocol_version: 9}}}} =
             Envelope.decode(payload)
  end

  test "stops the connection on a malformed frame" do
    {pid, parent} = start_owner()
    ref = Process.monitor(pid)

    send(pid, {:quic, parent, {:stream_data, 0, <<0::32-big, 0::8>>, false}})

    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}
  end

  test "sends the bevy_quinnet client-id handshake on a bidi stream when connected" do
    {pid, parent} = start_owner()

    send(pid, {:quic, parent, {:connected, %{}}})

    assert_receive {:sent, 100, <<8::32-big, client_id::64-big>>}
    assert client_id > 0
  end

  test "frames channel responses on a unidirectional stream" do
    {pid, parent} = start_owner()
    frame = control_frame(%Hello{protocol_version: 3, build: "dev"}, :hello)

    send(pid, {:quic, parent, {:stream_data, 0, frame, false}})

    assert_receive {:sent, 200, _out_frame}
  end

  test "stops when the connection reports closed" do
    {pid, parent} = start_owner()
    ref = Process.monitor(pid)

    send(pid, {:quic, parent, {:closed, :peer_closed}})

    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}
  end

  test "an external {:send, channel, msg} frames a reliable Envelope on that channel" do
    {pid, _parent} = start_owner()

    send(pid, {:send, :world, {:char_auth_failed, %CharAuthFailed{reason: 7}}})

    assert_receive {:sent, _sid, out_frame}
    assert {:ok, 2, payload, ""} = QuinnetCodec.decode_reliable(out_frame)

    assert {:ok, %Envelope{body: {:char_auth_failed, %CharAuthFailed{reason: 7}}}} =
             Envelope.decode(payload)
  end

  test "an external {:send, :snapshots, msg} sends a datagram on the snapshots channel" do
    {pid, _parent} = start_owner()

    send(pid, {:send, :snapshots, {:hello_ack, %HelloAck{protocol_version: 5, accepted: true}}})

    assert_receive {:datagram_sent, <<4::8, payload::binary>>}

    assert {:ok, %Envelope{body: {:hello_ack, %HelloAck{protocol_version: 5}}}} =
             Envelope.decode(payload)
  end
end
