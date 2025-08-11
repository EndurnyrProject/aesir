defmodule Aesir.CharServer.Packets.HcCharacterList do
  @moduledoc """
  HC_CHARACTER_LIST packet (0x082d) - Character slot configuration.

  Structure (29 bytes):
  - packet_id: 2 bytes (0x082d)
  - packet_length: 2 bytes (always 29)
  - normal_slots: 1 byte (MIN_CHARS, typically 9)
  - premium_slots: 1 byte (VIP slots)
  - billing_slots: 1 byte (billing slots)
  - producible_slots: 1 byte (total slots the player can use)
  - valid_slots: 1 byte (MAX_CHARS, typically 15)
  - unused: 20 bytes (reserved/padding)
  """
  use Aesir.Commons.Network.Packet

  @packet_id 0x082D
  @packet_size 29

  defstruct [
    :normal_slots,
    :premium_slots,
    :billing_slots,
    :producible_slots,
    :valid_slots
  ]

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def parse(<<@packet_id::16-little, 29::16-little, rest::binary>>) do
    <<normal::8, premium::8, billing::8, producible::8, valid::8, _unused::binary-size(20)>> =
      rest

    {:ok,
     %__MODULE__{
       normal_slots: normal,
       premium_slots: premium,
       billing_slots: billing,
       producible_slots: producible,
       valid_slots: valid
     }}
  end

  def parse(_), do: {:error, :invalid_packet}

  @impl true
  def build(%__MODULE__{} = packet) do
    normal = packet.normal_slots || 9
    premium = packet.premium_slots || 0
    billing = packet.billing_slots || 0
    producible = packet.producible_slots || 9
    valid = packet.valid_slots || 15

    <<
      @packet_id::16-little,
      29::16-little,
      normal::8,
      premium::8,
      billing::8,
      producible::8,
      valid::8,
      # 20 bytes of padding
      0::size(20 * 8)
    >>
  end
end
