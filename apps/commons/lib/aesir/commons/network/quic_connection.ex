defmodule Aesir.Commons.Network.QuicConnection do
  @moduledoc """
  Per-connection owner process for a QUIC connection.

  One GenServer owns a single `erlang_quic` connection, holds the mutable
  `session_data`, demultiplexes channels via `QuinnetCodec`, decodes the
  `Aesir.Net.Envelope` payload, and routes each message to the server's
  `c:handle_message/3` callback. Responses returned by the handler are wrapped in
  an `Envelope`, framed, and sent back on the channel the request arrived on.

  The process becomes the connection owner when the listener's
  `connection_handler` transfers ownership to it, after which it receives the
  `{quic, Conn, Event}` messages documented by `erlang_quic`.

  A separate process can also push an outbound message asynchronously by sending
  the owner `{:send, channel, {oneof_tag, struct}}`; the owner wraps it in an
  `Envelope` and frames it on `channel` exactly like a synchronous response.

  The QUIC transport module is injectable (`:transport` option, default `:quic`)
  so the owner logic can be unit-tested without a live connection.
  """
  use GenServer, restart: :temporary

  require Logger

  alias Aesir.Commons.InterServer.PubSub
  alias Aesir.Commons.Network.QuinnetCodec
  alias Aesir.Net.Envelope

  @type response :: {atom(), struct()}

  @doc """
  Handle one decoded message from the client.

  Returns the (possibly updated) `session_data`, optionally with a list of
  `{oneof_tag, struct}` responses to send back on the same channel. `{:error,
  reason}` closes the connection.
  """
  @callback handle_message(
              message :: struct(),
              channel :: QuinnetCodec.channel(),
              session_data :: map()
            ) ::
              {:ok, map()} | {:ok, map(), [response()]} | {:error, term()}

  defmodule State do
    @moduledoc false

    @enforce_keys [:conn, :impl_module]
    defstruct conn: nil,
              impl_module: nil,
              transport: :quic,
              session_data: %{},
              stream_buffers: %{},
              out_streams: %{},
              out_seq: 0,
              client_id: nil,
              account_id: nil,
              session_monitor_ref: nil

    @type t() :: %__MODULE__{
            conn: pid(),
            impl_module: module(),
            transport: module(),
            session_data: map(),
            stream_buffers: %{integer() => binary()},
            out_streams: %{atom() => integer()},
            out_seq: non_neg_integer(),
            client_id: non_neg_integer() | nil,
            account_id: non_neg_integer() | nil,
            session_monitor_ref: reference() | nil
          }
  end

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts), do: GenServer.start_link(__MODULE__, opts)

  @impl GenServer
  def init(opts) do
    state = %State{
      conn: Keyword.fetch!(opts, :conn),
      impl_module: Keyword.fetch!(opts, :impl_module),
      transport: Keyword.get(opts, :transport, :quic),
      session_data: Keyword.get(opts, :session_data, %{})
    }

    Process.monitor(state.conn)
    {:ok, state}
  end

  @impl GenServer
  def handle_info({:quic, conn, {:stream_data, sid, data, _fin}}, %State{conn: conn} = state) do
    buffer = Map.get(state.stream_buffers, sid, <<>>) <> data

    case process_buffer(state, buffer) do
      {:ok, %State{} = state, leftover} ->
        {:noreply, %State{state | stream_buffers: Map.put(state.stream_buffers, sid, leftover)}}

      {:error, reason} ->
        Logger.warning("QuicConnection closing stream #{sid}: #{inspect(reason)}")
        {:stop, :normal, state}
    end
  end

  def handle_info({:quic, conn, {:datagram, data}}, %State{conn: conn} = state) do
    snapshots_channel_id = QuinnetCodec.channel_id(:snapshots)

    case QuinnetCodec.decode_datagram(data) do
      {:ok, ^snapshots_channel_id, payload} ->
        case dispatch(state, snapshots_channel_id, payload) do
          {:ok, state} ->
            {:noreply, state}

          {:error, reason} ->
            Logger.warning("QuicConnection dropping bad datagram: #{inspect(reason)}")
            {:noreply, state}
        end

      {:ok, _channel_id, _payload} ->
        {:noreply, state}

      {:error, :empty_datagram} ->
        {:noreply, state}
    end
  end

  def handle_info({:quic, conn, {:connected, info}}, %State{conn: conn} = state) do
    Logger.debug("QuicConnection established: #{inspect(info)}")
    {:noreply, send_client_id(state)}
  end

  def handle_info({:quic, conn, {:closed, reason}}, %State{conn: conn} = state) do
    Logger.debug("QuicConnection closed: #{inspect(reason)}")
    {:stop, :normal, state}
  end

  def handle_info({:quic, conn, {:transport_error, code, reason}}, %State{conn: conn} = state) do
    Logger.warning("QuicConnection transport error #{inspect(code)}: #{inspect(reason)}")
    {:stop, :normal, state}
  end

  def handle_info({:quic, conn, _event}, %State{conn: conn} = state) do
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, conn, _reason}, %State{conn: conn} = state) do
    {:stop, :normal, state}
  end

  def handle_info(
        {:DOWN, ref, :process, _pid, reason},
        %State{session_monitor_ref: ref} = state
      ) do
    Logger.debug("QuicConnection closing: player session ended (#{inspect(reason)})")
    {:stop, :normal, state}
  end

  def handle_info({:send, channel, {_tag, _message} = response}, %State{} = state) do
    {:noreply, send_response(state, channel, response)}
  end

  def handle_info(
        {:player_event, %{event: "kick_connection", account_id: aid} = event},
        %State{account_id: aid} = state
      ) do
    Logger.info("QuicConnection kicked for account #{aid}, reason: #{inspect(event[:reason])}")
    {:stop, :kicked, state}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  @impl GenServer
  def terminate(_reason, %State{} = state) do
    state.transport.close(state.conn, :normal)
    :ok
  rescue
    _ -> :ok
  end

  @spec process_buffer(State.t(), binary()) :: {:ok, State.t(), binary()} | {:error, term()}
  defp process_buffer(%State{} = state, buffer) do
    case QuinnetCodec.decode_reliable(buffer) do
      {:ok, channel_id, payload, rest} ->
        case dispatch(state, channel_id, payload) do
          {:ok, state} -> process_buffer(state, rest)
          {:error, _} = error -> error
        end

      {:more, leftover} ->
        {:ok, state, leftover}

      {:error, _} = error ->
        error
    end
  end

  @spec dispatch(State.t(), QuinnetCodec.channel_id(), binary()) ::
          {:ok, State.t()} | {:error, term()}
  defp dispatch(%State{} = state, channel_id, payload) do
    channel = QuinnetCodec.channel_name(channel_id)

    case Envelope.decode(payload) do
      {:ok, %Envelope{body: {_tag, message}}} ->
        apply_handler(state, channel, message)

      {:ok, %Envelope{body: nil}} ->
        Logger.warning("QuicConnection: empty envelope body on #{channel}")
        {:ok, state}

      {:error, reason} ->
        {:error, {:decode, reason}}
    end
  end

  @spec apply_handler(State.t(), QuinnetCodec.channel(), struct()) ::
          {:ok, State.t()} | {:error, term()}
  defp apply_handler(%State{} = state, channel, message) do
    case state.impl_module.handle_message(message, channel, state.session_data) do
      {:ok, session_data} ->
        {:ok, post_handle(state, session_data)}

      {:ok, session_data, responses} ->
        state = post_handle(state, session_data)
        {:ok, Enum.reduce(responses, state, &send_response(&2, channel, &1))}

      {:error, reason} ->
        {:error, {:handler, reason}}
    end
  end

  @spec post_handle(State.t(), map()) :: State.t()
  defp post_handle(%State{} = state, session_data) do
    %State{state | session_data: session_data}
    |> maybe_subscribe_player_events()
    |> maybe_monitor_session()
  end

  @spec maybe_subscribe_player_events(State.t()) :: State.t()
  defp maybe_subscribe_player_events(%State{account_id: account_id} = state)
       when is_integer(account_id),
       do: state

  defp maybe_subscribe_player_events(%State{session_data: %{account_id: account_id}} = state)
       when is_integer(account_id) do
    PubSub.subscribe_to_player_events()
    %State{state | account_id: account_id}
  end

  defp maybe_subscribe_player_events(%State{} = state), do: state

  # Once a server hands this connection a long-lived session process (the zone
  # server stores it as `:player_session_pid`), monitor it so the connection is
  # torn down when that process dies — including on a crash. Stopping the owner
  # closes the QUIC connection, disconnecting the client instead of leaving it
  # attached to a dead session.
  @spec maybe_monitor_session(State.t()) :: State.t()
  defp maybe_monitor_session(%State{session_monitor_ref: ref} = state) when is_reference(ref),
    do: state

  defp maybe_monitor_session(%State{session_data: %{player_session_pid: pid}} = state)
       when is_pid(pid) do
    %State{state | session_monitor_ref: Process.monitor(pid)}
  end

  defp maybe_monitor_session(%State{} = state), do: state

  @spec send_response(State.t(), QuinnetCodec.channel(), response()) :: State.t()
  defp send_response(%State{} = state, channel, {tag, message}) do
    {:ok, iodata, _size} = Envelope.encode(%Envelope{seq: state.out_seq, body: {tag, message}})
    payload = IO.iodata_to_binary(iodata)
    state = %State{state | out_seq: state.out_seq + 1}
    send_on_channel(state, channel, payload)
  end

  @spec send_on_channel(State.t(), QuinnetCodec.channel(), binary()) :: State.t()
  defp send_on_channel(%State{} = state, :snapshots, payload) do
    datagram = QuinnetCodec.encode_datagram(QuinnetCodec.channel_id(:snapshots), payload)
    state.transport.send_datagram(state.conn, datagram)
    state
  end

  defp send_on_channel(%State{} = state, channel, payload) do
    case out_stream(state, channel) do
      {:ok, sid, state} ->
        frame = QuinnetCodec.encode_reliable(QuinnetCodec.channel_id(channel), payload)
        state.transport.send_data(state.conn, sid, frame, false)
        state

      {:error, reason} ->
        Logger.warning("QuicConnection failed to open #{channel} stream: #{inspect(reason)}")
        state
    end
  end

  @spec out_stream(State.t(), QuinnetCodec.channel()) ::
          {:ok, integer(), State.t()} | {:error, term()}
  defp out_stream(%State{} = state, channel) do
    case Map.fetch(state.out_streams, channel) do
      {:ok, sid} ->
        {:ok, sid, state}

      :error ->
        case state.transport.open_unidirectional_stream(state.conn) do
          {:ok, sid} ->
            {:ok, sid, %State{state | out_streams: Map.put(state.out_streams, channel, sid)}}

          {:error, _} = error ->
            error
        end
    end
  end

  @spec send_client_id(State.t()) :: State.t()
  defp send_client_id(%State{client_id: client_id} = state) when is_integer(client_id), do: state

  defp send_client_id(%State{} = state) do
    case state.transport.open_stream(state.conn) do
      {:ok, sid} ->
        client_id = :rand.uniform(0xFFFF_FFFF)

        state.transport.send_data(
          state.conn,
          sid,
          QuinnetCodec.encode_client_id(client_id),
          false
        )

        %State{state | client_id: client_id}

      {:error, reason} ->
        Logger.warning("QuicConnection failed to send client id: #{inspect(reason)}")
        state
    end
  end
end
