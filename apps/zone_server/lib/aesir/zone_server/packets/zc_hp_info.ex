defmodule Aesir.ZoneServer.Packets.ZcHpInfo do
  @moduledoc """
  ZC_HP_INFO (0x0977) - Monster HP information packet.

  This packet is used to update a monster's HP bar display to nearby players.
  It's sent when a monster takes damage or is healed to update the client-side
  HP bar display.

  Packet structure:
  - id: Monster's GID
  - hp: Current HP value
  - max_hp: Maximum HP value

  Used by the client to display monster HP bars above monsters.
  """

  use Aesir.Commons.Network.Packet

  @packet_id 0x0977

  @type t :: %__MODULE__{
          id: integer(),
          hp: integer(),
          max_hp: integer()
        }

  defstruct [
    :id,
    :hp,
    :max_hp
  ]

  @doc """
  Returns the packet ID for ZC_HP_INFO.
  """
  @impl true
  def packet_id, do: @packet_id

  @doc """
  Returns the packet size (fixed length).
  """
  @impl true
  def packet_size, do: 14

  @doc """
  Builds the binary packet data for ZC_HP_INFO.

  ## Parameters
  - packet: ZcHpInfo struct with id, hp, and max_hp fields

  ## Returns
  Binary packet data ready for transmission
  """
  @impl true
  def build(%__MODULE__{} = packet) do
    data = <<
      # Monster ID (4 bytes)
      packet.id::32-little,
      # Current HP (4 bytes)
      packet.hp::32-little,
      # Maximum HP (4 bytes)
      packet.max_hp::32-little
    >>

    build_packet(@packet_id, data)
  end

  @doc """
  Creates a ZC_HP_INFO packet for a monster.

  ## Parameters
  - monster_id: The monster's GID/instance ID
  - current_hp: Current HP value
  - max_hp: Maximum HP value

  ## Returns
  ZcHpInfo struct ready to be sent to clients

  ## Examples
      iex> packet = ZcHpInfo.new(2001, 500, 1000)
      iex> packet.hp
      500
      iex> packet.max_hp
      1000
  """
  @spec new(integer(), integer(), integer()) :: t()
  def new(monster_id, current_hp, max_hp)
      when is_integer(monster_id) and is_integer(current_hp) and is_integer(max_hp) do
    %__MODULE__{
      id: monster_id,
      hp: max(0, current_hp),
      max_hp: max(1, max_hp)
    }
  end
end
