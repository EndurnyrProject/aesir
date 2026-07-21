defmodule Aesir.Commons.Network.QuicConnectionTest do
  use ExUnit.Case, async: true

  @moduletag :capture_log

  # These tests drive the owner GenServer purely through message passing and
  # assert on frames it sends back. Under a loaded parallel scheduler the owner
  # can take longer than the 100ms default to be scheduled, so give the
  # round-trip assertions a generous deadline to keep them from flaking.
  @receive_timeout 1_000

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

  defp start_owner(extra_opts \\ []) do
    parent = self()

    {:ok, pid} =
      start_supervised(
        {QuicConnection,
         [conn: parent, impl_module: EchoHandler, transport: FakeTransport] ++ extra_opts}
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

    assert_receive {:sent, _sid, out_frame}, @receive_timeout
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
    assert_receive {:sent, _sid, out_frame}, @receive_timeout
    assert {:ok, 0, payload, ""} = QuinnetCodec.decode_reliable(out_frame)

    assert {:ok, %Envelope{body: {:hello_ack, %HelloAck{protocol_version: 9}}}} =
             Envelope.decode(payload)
  end

  test "stops the connection on a malformed frame" do
    {pid, parent} = start_owner()
    ref = Process.monitor(pid)

    send(pid, {:quic, parent, {:stream_data, 0, <<0::32-big, 0::8>>, false}})

    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, @receive_timeout
  end

  test "sends the bevy_quinnet client-id handshake on a bidi stream when connected" do
    {pid, parent} = start_owner()

    send(pid, {:quic, parent, {:connected, %{}}})

    assert_receive {:sent, 100, <<8::32-big, client_id::64-big>>}, @receive_timeout
    assert client_id > 0
  end

  test "frames channel responses on a unidirectional stream" do
    {pid, parent} = start_owner()
    frame = control_frame(%Hello{protocol_version: 3, build: "dev"}, :hello)

    send(pid, {:quic, parent, {:stream_data, 0, frame, false}})

    assert_receive {:sent, 200, _out_frame}, @receive_timeout
  end

  test "stops when the connection reports closed" do
    {pid, parent} = start_owner()
    ref = Process.monitor(pid)

    send(pid, {:quic, parent, {:closed, :peer_closed}})

    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, @receive_timeout
  end

  test "closes the connection when the monitored player session dies" do
    session = spawn(fn -> Process.sleep(:infinity) end)
    {pid, parent} = start_owner(session_data: %{player_session_pid: session})
    ref = Process.monitor(pid)

    # Drive one message so the owner picks up :player_session_pid and monitors it.
    frame = control_frame(%Hello{protocol_version: 3, build: "dev"}, :hello)
    send(pid, {:quic, parent, {:stream_data, 0, frame, false}})
    assert_receive {:sent, _sid, _out_frame}, @receive_timeout

    Process.exit(session, :kill)

    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, @receive_timeout
  end

  test "an external {:send, channel, msg} frames a reliable Envelope on that channel" do
    {pid, _parent} = start_owner()

    send(pid, {:send, :world, {:char_auth_failed, %CharAuthFailed{reason: 7}}})

    assert_receive {:sent, _sid, out_frame}, @receive_timeout
    assert {:ok, 2, payload, ""} = QuinnetCodec.decode_reliable(out_frame)

    assert {:ok, %Envelope{body: {:char_auth_failed, %CharAuthFailed{reason: 7}}}} =
             Envelope.decode(payload)
  end

  test "an external {:send, :snapshots, msg} sends a datagram on the snapshots channel" do
    {pid, _parent} = start_owner()

    send(pid, {:send, :snapshots, {:hello_ack, %HelloAck{protocol_version: 5, accepted: true}}})

    assert_receive {:datagram_sent, <<4::8, payload::binary>>}, @receive_timeout

    assert {:ok, %Envelope{body: {:hello_ack, %HelloAck{protocol_version: 5}}}} =
             Envelope.decode(payload)
  end
end
