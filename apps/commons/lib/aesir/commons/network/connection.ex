defmodule Aesir.Commons.Network.Connection do
  @moduledoc """
  Ranch protocol handler for RO client connections.
  Manages socket communication, packet buffering, and session state.

  ## Usage

      defmodule MyServer.Connection do
        use Aesir.Commons.Network.Connection
        
        @impl Aesir.Commons.Network.Connection
        def handle_packet(packet_id, parsed_data, session_data) do
          # Handle the packet and return updated session data
          {:ok, session_data}
        end
      end
  """
  use GenServer

  require Logger

  @behaviour :ranch_protocol

  @callback handle_packet(packet_id :: integer(), parsed_data :: any(), session_data :: any()) ::
              {:ok, session_data :: any()}
              | {:ok, session_data :: any(), response_packets :: list()}
              | {:error, reason :: any()}

  defmacro __using__(_opts) do
    quote do
      @behaviour Aesir.Commons.Network.Connection
      @behaviour :ranch_protocol

      @impl :ranch_protocol
      def start_link(ref, transport, opts) do
        opts = Keyword.put(opts, :impl_module, __MODULE__)
        Aesir.Commons.Network.Connection.start_link(ref, transport, opts)
      end

      defdelegate send_packet(conn_pid, packet), to: Aesir.Commons.Network.Connection
      defdelegate get_session_data(conn_pid), to: Aesir.Commons.Network.Connection
      defdelegate set_session_data(conn_pid, session_data), to: Aesir.Commons.Network.Connection

      defdelegate init(args), to: Aesir.Commons.Network.Connection
      defdelegate handle_continue(msg, state), to: Aesir.Commons.Network.Connection
      defdelegate handle_info(msg, state), to: Aesir.Commons.Network.Connection
      defdelegate handle_call(msg, from, state), to: Aesir.Commons.Network.Connection
      defdelegate terminate(reason, state), to: Aesir.Commons.Network.Connection

      defoverridable handle_continue: 2, handle_info: 2, handle_call: 3, terminate: 2
    end
  end

  @read_timeout 60_000
  @timeout 5000

  defstruct [
    :socket,
    :transport,
    :client_addr,
    :session_data,
    :impl_module,
    read_buffer: <<>>,
    write_buffer: <<>>,
    rdata_tick: nil,
    wdata_tick: nil,
    connected_at: nil,
    state: :connected,
    packet_registry: nil
  ]

  @impl :ranch_protocol
  def start_link(ref, transport, opts) do
    {:ok, :proc_lib.spawn_link(__MODULE__, :init, [{ref, transport, opts}])}
  end

  @impl GenServer
  def init({ref, transport, opts}) do
    {:ok, socket} = :ranch.handshake(ref, 5000)

    :ok = transport.setopts(socket, [{:active, :once}, {:packet, :raw}, :binary])

    {:ok, {client_ip, client_port}} = transport.peername(socket)

    dbg(opts)

    state = %__MODULE__{
      socket: socket,
      transport: transport,
      client_addr: {client_ip, client_port},
      impl_module: Keyword.get(opts, :impl_module),
      session_data: %{},
      connected_at: System.system_time(:millisecond),
      rdata_tick: System.system_time(:millisecond),
      packet_registry: Keyword.get(opts, :registry)
    }

    Logger.info("New connection from #{:inet.ntoa(client_ip)}:#{client_port}")

    :gen_server.enter_loop(__MODULE__, [], state, @timeout)
  end

  # Public API

  def send_packet(conn_pid, packet) do
    module = packet.__struct__
    packet_data = module.build(packet)
    GenServer.call(conn_pid, {:send_packet, packet_data})
  end

  def get_session_data(conn_pid) do
    GenServer.call(conn_pid, :get_session_data)
  end

  def set_session_data(conn_pid, session_data) do
    GenServer.call(conn_pid, {:set_session_data, session_data})
  end

  # Callbacks

  @impl GenServer
  def handle_continue(:init, state) do
    Process.send_after(self(), :check_timeout, @read_timeout)
    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:tcp, socket, data}, %{socket: socket} = state) do
    hex_formatted =
      data
      |> Base.encode16()
      |> String.graphemes()
      |> Enum.chunk_every(2)
      |> Enum.map(&Enum.join/1)
      |> Enum.join(" ")

    Logger.info("Received data (#{byte_size(data)} bytes): #{hex_formatted}")

    state = %{
      state
      | read_buffer: state.read_buffer <> data,
        rdata_tick: System.system_time(:millisecond)
    }

    case process_packets(state) do
      {:ok, new_state} ->
        :ok = state.transport.setopts(socket, [{:active, :once}])

        case flush_write_buffer(new_state) do
          {:ok, flushed_state} -> {:noreply, flushed_state}
          {:error, reason} -> {:stop, {:error, reason}, new_state}
        end

      {:error, reason} ->
        Logger.error("Packet processing error: #{inspect(reason)}")
        {:stop, {:error, reason}, state}
    end
  end

  def handle_info({:tcp_closed, socket}, %{socket: socket} = state) do
    Logger.info("Connection closed by client")
    {:stop, :normal, state}
  end

  def handle_info({:tcp_error, socket, reason}, %{socket: socket} = state) do
    Logger.error("Socket error: #{inspect(reason)}")
    {:stop, {:socket_error, reason}, state}
  end

  def handle_info(_, %{socket: socket} = state) do
    state.transport.close(socket)
    {:stop, :shutdown, state}
  end

  @impl GenServer
  def handle_call({:send_packet, packet_data}, _from, state) do
    new_state = %{
      state
      | write_buffer: state.write_buffer <> packet_data,
        wdata_tick: System.system_time(:millisecond)
    }

    case flush_write_buffer(new_state) do
      {:ok, flushed_state} -> {:reply, :ok, flushed_state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call(:get_session_data, _from, state) do
    {:reply, state.session_data, state}
  end

  def handle_call({:set_session_data, session_data}, _from, state) do
    {:reply, :ok, %{state | session_data: session_data}}
  end

  @impl GenServer
  def terminate(reason, state) do
    Logger.debug("Connection terminating: #{inspect(reason)}")
    state.transport.close(state.socket)
    :ok
  end

  defp process_packets(%{read_buffer: buffer} = state) when byte_size(buffer) < 2 do
    {:ok, state}
  end

  defp process_packets(%{read_buffer: buffer, packet_registry: registry} = state) do
    with {:ok, packet_id, packet_data, rest} <- parse_next_packet(registry, buffer),
         {:ok, new_state} <- handle_packet(packet_id, packet_data, state) do
      process_packets(%{new_state | read_buffer: rest})
    else
      {:need_more, _} ->
        {:ok, state}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_next_packet(_registry, buffer) when byte_size(buffer) < 2 do
    {:need_more, 2}
  end

  defp parse_next_packet(registry, <<packet_id::16-little, _rest::binary>> = buffer) do
    case registry.get_packet_info(packet_id) do
      {:ok, %{module: _module, size: size}} ->
        cond do
          size == -1 ->
            if byte_size(buffer) >= 4 do
              <<_id::16-little, length::16-little, _::binary>> = buffer

              if byte_size(buffer) >= length do
                <<full_packet::binary-size(length), rest::binary>> = buffer
                {:ok, packet_id, full_packet, rest}
              else
                {:need_more, length}
              end
            else
              {:need_more, 4}
            end

          byte_size(buffer) >= size ->
            <<full_packet::binary-size(size), rest::binary>> = buffer
            {:ok, packet_id, full_packet, rest}

          true ->
            {:need_more, size}
        end

      {:error, :unknown_packet} ->
        Logger.warning("Unknown packet ID: 0x#{Integer.to_string(packet_id, 16)}")
        # Skip this packet by advancing 2 bytes
        <<skipped::binary-size(2), rest::binary>> = buffer
        {:ok, packet_id, skipped, rest}
    end
  end

  defp handle_packet(packet_id, packet_data, state) do
    case state.packet_registry.get_module(packet_id) do
      nil ->
        handle_unknown_packet(packet_id, state)

      module ->
        handle_packet_with_module(packet_id, packet_data, module, state)
    end
  end

  defp handle_unknown_packet(packet_id, state) do
    Logger.warning("No handler for packet #{format_packet_id(packet_id)}")
    {:ok, state}
  end

  defp handle_packet_with_module(packet_id, packet_data, module, state) do
    case module.parse(packet_data) do
      {:ok, parsed_data} ->
        process_parsed_packet(packet_id, parsed_data, state)

      {:error, reason} ->
        Logger.error("Failed to parse packet #{format_packet_id(packet_id)}: #{inspect(reason)}")
        {:error, {:parse_error, reason}}
    end
  end

  defp process_parsed_packet(packet_id, parsed_data, %{impl_module: impl_module} = state) do
    case impl_module.handle_packet(packet_id, parsed_data, state.session_data) do
      {:ok, session_data} ->
        {:ok, %{state | session_data: session_data}}

      {:ok, session_data, response_packets} when is_list(response_packets) ->
        handle_packet_with_responses(state, session_data, response_packets)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp handle_packet_with_responses(state, session_data, response_packets) do
    encoded_packets = encode_response_packets(response_packets)

    new_state = %{
      state
      | session_data: session_data,
        write_buffer: state.write_buffer <> IO.iodata_to_binary(encoded_packets)
    }

    {:ok, new_state}
  end

  defp encode_response_packets(response_packets) do
    Enum.map(response_packets, fn packet ->
      module = packet.__struct__
      module.build(packet)
    end)
  end

  defp format_packet_id(packet_id) do
    "0x#{Integer.to_string(packet_id, 16)}"
  end

  defp flush_write_buffer(%{write_buffer: <<>>} = state) do
    {:ok, state}
  end

  defp flush_write_buffer(%{write_buffer: buffer} = state) when byte_size(buffer) > 0 do
    case state.transport.send(state.socket, buffer) do
      :ok ->
        dbg(:sent)
        {:ok, %{state | write_buffer: <<>>, wdata_tick: System.system_time(:millisecond)}}

      {:error, reason} ->
        Logger.error("Failed to send data: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
