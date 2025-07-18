defmodule Aesir.AccountServer.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  require Logger

  @impl true
  def start(_type, _args) do
    ref = make_ref()

    children = [
      {Aesir.Commons.Network.Listener,
       connection_module: Aesir.AccountServer,
       packet_registry: Aesir.AccountServer.PacketRegistry,
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

      {:error, reason} ->
        Logger.error("Failed to start Aesir AccountServer: #{inspect(reason)}")
    end)
  end
end
