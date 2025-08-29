defmodule Aesir.CharServer.Config.Network do
  @spec bind_ip() :: :inet.ip4_address() | :inet.ip6_address()
  def bind_ip() do
    ip_charlist =
      application_env()
      |> Keyword.fetch!(:bind_ip)
      |> String.to_charlist()

    case :inet.parse_strict_address(ip_charlist) do
      {:ok, ip} -> ip
      {:error, _} -> raise "Invalid IP address format: #{ip_charlist}"
    end
  end

  @spec port() :: pos_integer()
  def port(), do: Keyword.fetch!(application_env(), :port)

  defp application_env() do
    Application.fetch_env!(:char_server, :network)
  end
end
