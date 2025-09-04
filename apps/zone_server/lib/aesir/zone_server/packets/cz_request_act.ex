defmodule Aesir.ZoneServer.Packets.CzRequestAct do
  @moduledoc """
  CZ_REQUEST_ACT (0x0437) - Player action request packet.

  This packet is sent when a player performs an action like attacking,
  sitting, standing, or using an item. The action type determines
  what the player is trying to do.

  Structure:
  - packet_type: 2 bytes (0x0437)
  - target_id: 4 bytes (GID of target entity)
  - action: 1 byte (action type)

  Action types:
  - 0: Attack (single attack)
  - 7: Continuous attack (keep attacking until stopped)
  - 2: Sit down
  - 3: Stand up

  Total size: 7 bytes
  """
  use Aesir.Commons.Network.Packet

  @packet_id 0x0437
  @packet_size 7

  defstruct [:target_id, :action]

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def parse(<<@packet_id::16-little, target_id::32-little, action::8>>) do
    {:ok,
     %__MODULE__{
       target_id: target_id,
       action: action
     }}
  end

  def parse(_), do: {:error, :invalid_packet}
end
