defmodule Aesir.ZoneServer.Packets.ZcNotifyVanish do
  @moduledoc """
  ZC_NOTIFY_VANISH (0x0080) - Makes a unit disappear to one client.

  This packet tells the client that a unit has disappeared/vanished.

  Structure:
  - packet_type: 2 bytes (0x0080)
  - gid: 4 bytes (unit ID)
  - type: 1 byte (vanish type)

  Vanish types:
  - 0: Out of sight
  - 1: Died
  - 2: Logged out
  - 3: Teleport
  - 4: Trickdead

  Total size: 7 bytes
  """
  use Aesir.Commons.Network.Packet

  @packet_id 0x0080
  @packet_size 7

  # Vanish type constants
  @out_of_sight 0
  @died 1
  @logged_out 2
  @teleport 3
  @trickdead 4

  defstruct [:gid, :type]

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def build(%__MODULE__{} = packet) do
    <<
      @packet_id::16-little,
      packet.gid::32-little,
      packet.type::8
    >>
  end

  @doc "Returns the vanish type for out of sight"
  def out_of_sight, do: @out_of_sight

  @doc "Returns the vanish type for died"
  def died, do: @died

  @doc "Returns the vanish type for logged out"
  def logged_out, do: @logged_out

  @doc "Returns the vanish type for teleport"
  def teleport, do: @teleport

  @doc "Returns the vanish type for trickdead"
  def trickdead, do: @trickdead
end
