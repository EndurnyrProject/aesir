defmodule Aesir.AccountServer.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  require Logger

  alias Aesir.AccountServer.Config.Network, as: NetworkConfig
  alias Aesir.Commons.InterServer.PubSub
  alias Aesir.Commons.SessionManager

  @impl true
  def start(_type, _args) do
    ref = make_ref()

    children = [
      {Aesir.Commons.Network.Listener,
       connection_module: Aesir.AccountServer,
       packet_registry: Aesir.AccountServer.PacketRegistry,
       transport_opts: %{
         socket_opts: [
           port: NetworkConfig.port(),
           ip: NetworkConfig.bind_ip()
         ]
       },
       ref: ref}
    ]

    opts = [strategy: :one_for_one, name: Aesir.AccountServer.Supervisor]

    children
    |> Supervisor.start_link(opts)
    |> tap(fn
      {:ok, _pid} ->
        {ip, port} = :ranch.get_addr(ref)

        Logger.info(
          "Aesir AccountServer (ref: #{inspect(ref)}) started at #{:inet.ntoa(ip)}:#{port}"
        )

        server_id = "account_server_#{Node.self()}"

        SessionManager.register_server(
          server_id,
          :account_server,
          ip,
          port,
          1000,
          %{}
        )

        PubSub.subscribe_to_player_events()

      {:error, reason} ->
        Logger.error("Failed to start Aesir AccountServer: #{inspect(reason)}")
    end)
  end
end
