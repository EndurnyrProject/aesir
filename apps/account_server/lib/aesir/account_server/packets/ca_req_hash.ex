defmodule Aesir.AccountServer.Packets.CaReqHash do
  @moduledoc """
  CA_REQ_HASH packet (0x01DB) - Hash request from client as part of authentication.

  Fixed-size packet structure:
  - packet_type: 2 bytes (0x01DB)

  Total size: 2 bytes
  """
  use Aesir.Commons.Network.Packet

  @packet_id 0x01DB
  @packet_size 2

  defstruct []

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def build(%__MODULE__{}) do
    <<@packet_id::16-little>>
  end
end
