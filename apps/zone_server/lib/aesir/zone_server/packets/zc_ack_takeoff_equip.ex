defmodule Aesir.ZoneServer.Packets.ZcAckTakeoffEquip do
  @moduledoc """
  ZC_ACK_TAKEOFF_EQUIP packet (0x099A, `ZC_REQ_TAKEOFF_EQUIP_ACK` V5)

  Notifies the owning client of the result of a `CZ_REQ_TAKEOFF_EQUIP` request.

  Latest layout (`PACKET_ZC_REQ_TAKEOFF_EQUIP_ACK`, PACKETVER >= 20130000):
  - packet_id: 0x099A (2 bytes, little-endian)
  - index: client inventory index, server index + 2 (2 bytes)
  - wear_location: previously-worn equip-position bitmask (4 bytes)
  - result: unequip result code (1 byte)

  rAthena inverts the success flag for this variant (`success = !success`), so
  the on-wire result is 0 = success, 1 = failure.
  """

  use Aesir.Commons.Network.Packet

  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @packet_id 0x099A
  @packet_size 9

  @result_success 0
  @result_failure 1

  @type t :: %__MODULE__{
          index: non_neg_integer(),
          wear_location: integer(),
          result: non_neg_integer()
        }

  defstruct index: 0, wear_location: 0, result: @result_success

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def build(%__MODULE__{} = packet) do
    data = <<
      packet.index::16-little,
      packet.wear_location::32-little,
      packet.result::8
    >>

    build_packet(@packet_id, data)
  end

  @doc """
  Builds a successful unequip ack from the server index and the formerly-worn
  location bitmask. The +2 client index offset is applied.
  """
  @spec success(non_neg_integer(), integer()) :: t()
  def success(server_index, wear_location) do
    %__MODULE__{
      index: PlayerState.client_index(server_index),
      wear_location: wear_location,
      result: @result_success
    }
  end

  @doc """
  Builds a failed unequip ack for the given server index.
  """
  @spec failure(non_neg_integer()) :: t()
  def failure(server_index) do
    %__MODULE__{
      index: PlayerState.client_index(server_index),
      result: @result_failure
    }
  end

  @doc "Result code: unequip succeeded (inverted on the wire)."
  @spec result_success() :: non_neg_integer()
  def result_success, do: @result_success

  @doc "Result code: unequip failed (inverted on the wire)."
  @spec result_failure() :: non_neg_integer()
  def result_failure, do: @result_failure
end
