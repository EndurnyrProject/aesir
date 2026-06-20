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
    children = [
      {DynamicSupervisor, name: Aesir.AccountServer.QuicConnSup, strategy: :one_for_one},
      {Aesir.Commons.Network.QuicListener,
       name: :account_server_quic,
       port: NetworkConfig.port(),
       impl_module: Aesir.AccountServer,
       conn_sup: Aesir.AccountServer.QuicConnSup}
    ]

    opts = [strategy: :one_for_one, name: Aesir.AccountServer.Supervisor]

    children
    |> Supervisor.start_link(opts)
    |> tap(fn
      {:ok, _pid} ->
        ip = NetworkConfig.bind_ip()
        port = NetworkConfig.port()

        Logger.info("Aesir AccountServer (QUIC) started at #{:inet.ntoa(ip)}:#{port}")

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
