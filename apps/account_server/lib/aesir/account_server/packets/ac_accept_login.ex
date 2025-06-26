defmodule Aesir.AccountServer.Packets.AcAcceptLogin do
  @moduledoc """
  AC_ACCEPT_LOGIN packet (0x0ac4) - Login success response with server list.

  Variable-length packet structure:
  - packet_type: 2 bytes (0x0ac4)
  - packet_length: 2 bytes
  - login_id1: 4 bytes
  - AID: 4 bytes (account ID)
  - login_id2: 4 bytes
  - last_ip: 4 bytes
  - last_login: 26 bytes (string)
  - sex: 1 byte (0: female, 1: male, 2: server)
  - token: WEB_AUTH_TOKEN_LENGTH bytes
  - char_servers: array of server info structures

  Server entry structure:
  - ip: 4 bytes
  - port: 2 bytes
  - name: 20 bytes
  - users: 2 bytes
  - type: 2 bytes
  - new_: 2 bytes
  - unknown: 128 bytes
  """
  use Aesir.Network.Packet

  @packet_id 0x0AC4

  defmodule ServerInfo do
    defstruct [:ip, :port, :name, :users, :type, :new?, :unknown]
  end

  defstruct [
    :login_id1,
    :aid,
    :login_id2,
    :last_ip,
    :last_login,
    :sex,
    :token,
    :char_servers
  ]

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: :variable

  @impl true
  def build(%__MODULE__{} = packet) do
    char_servers_data =
      Enum.map(packet.char_servers, &serialize_server/1) |> IO.iodata_to_binary()

    token_data = packet.token <> <<0>>

    data = <<
      packet.login_id1::32-little,
      packet.aid::32-little,
      packet.login_id2::32-little,
      0::32-little,
      <<0::size(26 * 8)>>,
      serialize_sex(packet.sex)::8,
      token_data::binary,
      char_servers_data::binary
    >>

    build_variable_packet(@packet_id, data)
  end

  defp serialize_server(%ServerInfo{} = server) do
    name = pack_string(server.name, 20)
    new_flag = if server.new?, do: 1, else: 0
    unknown = :binary.copy(<<0>>, 128)

    <<port::16-little>> = <<server.port::16-big>>

    <<serialize_ip(server.ip)::32-little, port::16-little, name::binary-size(20),
      server.users::16-little, server.type::16-little, new_flag::16-little,
      unknown::binary>>
  end

  defp serialize_ip({ip1, ip2, ip3, ip4}) do
    <<ip_int::32-little>> = <<ip1::8, ip2::8, ip3::8, ip4::8>>
    ip_int
  end

  defp serialize_ip(_), do: 0

  defp serialize_sex(:female), do: 0
  defp serialize_sex(:male), do: 1
  defp serialize_sex(:server), do: 2
  defp serialize_sex(_), do: 2
end
