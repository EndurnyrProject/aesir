defmodule Aesir.Commons.Network.Listener do
  @moduledoc """
  Ranch listener supervisor for managing TCP server sockets.
  """

  require Logger

  alias Aesir.Commons.Network.ListenerOptions

  @type opts :: [
          ref: atom(),
          port: non_neg_integer(),
          connection_module: module(),
          acceptors: non_neg_integer(),
          max_connections: non_neg_integer()
        ]

  def child_spec(opts) do
    {ref, registry, connection_mod, transport_opts} = ListenerOptions.validate!(opts)

    :ranch.child_spec(
      ref,
      :ranch_tcp,
      transport_opts,
      connection_mod,
      registry: registry
    )
  end

  @doc """
  Start a new listener.
  """
  def start_listener(opts) do
    {ref, registry, connection_mod, transport_opts} = ListenerOptions.validate!(opts)

    case :ranch.start_listener(
           ref,
           :ranch_tcp,
           transport_opts,
           connection_mod,
           registry: registry
         ) do
      {:ok, pid} ->
        port = :ranch.get_port(ref)
        {:ok, pid, port}

      {:error, reason} = error ->
        Logger.error("Failed to start listener #{inspect(ref)}: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Get information about a listener.
  """
  def get_info(ref) do
    port = :ranch.get_port(ref)
    max_connections = :ranch.get_max_connections(ref)
    status = :ranch.get_status(ref)

    {:ok,
     %{
       port: port,
       status: status,
       max_connections: max_connections
     }}
  end

  @doc """
  Update max connections for a listener.
  """
  def set_max_connections(ref, max) do
    :ranch.set_max_connections(ref, max)
  end

  @doc """
  Get all connection PIDs for a listener.
  """
  def get_connections(ref) do
    :ranch.procs(ref, :connections)
  end
end
