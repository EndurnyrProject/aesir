defmodule Aesir.AccountServer.Packets.CaLogin do
  @moduledoc """
  CA_LOGIN packet (0x0064) - Basic login request from client to account server.

  Structure:
  - packet_type: 2 bytes (0x0064)
  - version: 4 bytes
  - username: 24 bytes (null-terminated string)
  - password: 24 bytes (null-terminated string)
  - client_type: 1 byte

  Total size: 55 bytes
  """
  use Aesir.Network.Packet

  @packet_id 0x0064
  @packet_size 55

  defstruct [:version, :username, :password, :client_type]

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def parse(<<@packet_id::16-little, data::binary>>) do
    parse(data)
  end

  def parse(
        <<version::32-little, username::binary-size(24), password::binary-size(24),
          client_type::8>>
      ) do
    {:ok,
     %__MODULE__{
       version: version,
       username: extract_string(username),
       password: extract_string(password),
       client_type: client_type
     }}
  end

  def parse(_), do: {:error, :invalid_packet}
end
