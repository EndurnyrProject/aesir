defmodule Aesir.Commons.Network.QuicListener do
  @moduledoc """
  QUIC listener child spec for accepting client connections.

  `child_spec/1` builds an `erlang_quic` server child spec (via `:quic.server_spec/3`)
  whose `connection_handler` starts a `Aesir.Commons.Network.QuicConnection` owner
  under a `DynamicSupervisor` and transfers ownership to it. Embed both the
  connection supervisor and this listener in an application's supervision tree:

      children = [
        {DynamicSupervisor, name: MyApp.QuicConnSup, strategy: :one_for_one},
        {Aesir.Commons.Network.QuicListener,
         name: :my_app_quic,
         port: 6900,
         impl_module: MyApp,
         conn_sup: MyApp.QuicConnSup}
      ]

  ## Options

    * `:name` - required, atom naming the QUIC server
    * `:port` - required, listen port (`0` for an ephemeral port)
    * `:impl_module` - required, module implementing `c:Aesir.Commons.Network.QuicConnection.handle_message/3`
    * `:conn_sup` - required, the `DynamicSupervisor` connections are started under
    * `:alpn` - ALPN protocol id binary, default `"aesir/1"`
    * `:cert_dir` - directory holding `cert.der`/`key.der`, default the commons `priv/quic_cert`
    * `:max_datagram_frame_size` - default `65_535`
  """
  alias Aesir.Commons.Network.QuicConnection

  @default_alpn "aesir/1"
  @default_max_datagram_frame_size 65_535

  @spec child_spec(keyword()) :: :supervisor.child_spec()
  def child_spec(opts) do
    name = Keyword.fetch!(opts, :name)
    port = Keyword.fetch!(opts, :port)
    impl_module = Keyword.fetch!(opts, :impl_module)
    conn_sup = Keyword.fetch!(opts, :conn_sup)
    {cert, key} = load_credentials(opts)

    quic_opts = %{
      cert: cert,
      key: key,
      alpn: [Keyword.get(opts, :alpn, @default_alpn)],
      max_datagram_frame_size:
        Keyword.get(opts, :max_datagram_frame_size, @default_max_datagram_frame_size),
      connection_handler: connection_handler(conn_sup, impl_module)
    }

    :quic.server_spec(name, port, quic_opts)
  end

  @spec connection_handler(Supervisor.supervisor(), module()) :: (pid() ->
                                                                    {:ok, pid()}
                                                                    | {:error, term()})
  defp connection_handler(conn_sup, impl_module) do
    fn conn ->
      case DynamicSupervisor.start_child(
             conn_sup,
             {QuicConnection, conn: conn, impl_module: impl_module}
           ) do
        {:ok, pid} -> {:ok, pid}
        {:ok, pid, _info} -> {:ok, pid}
        {:error, _} = error -> error
      end
    end
  end

  @spec load_credentials(keyword()) :: {binary(), :public_key.private_key()}
  defp load_credentials(opts) do
    cert_dir = Keyword.get(opts, :cert_dir, default_cert_dir())
    cert = File.read!(Path.join(cert_dir, "cert.der"))
    key = :public_key.der_decode(:ECPrivateKey, File.read!(Path.join(cert_dir, "key.der")))
    {cert, key}
  end

  @spec default_cert_dir() :: String.t()
  defp default_cert_dir, do: Path.join(:code.priv_dir(:commons), "quic_cert")
end
