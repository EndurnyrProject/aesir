defmodule Aesir.ZoneServer.Packets.ZcAckWearEquip do
  @moduledoc """
  ZC_ACK_WEAR_EQUIP packet (0x0999, `ZC_REQ_WEAR_EQUIP_ACK` V5)

  Notifies the owning client of the result of a `CZ_REQ_WEAR_EQUIP` request.

  Latest layout (`PACKET_ZC_REQ_WEAR_EQUIP_ACK`,
  PACKETVER_MAIN >= 20121205 / PACKETVER_RE >= 20121107 / PACKETVER_ZERO):
  - packet_id: 0x0999 (2 bytes, little-endian)
  - index: client inventory index, server index + 2 (2 bytes)
  - wear_location: worn equip-position bitmask (4 bytes)
  - view_id: equip sprite number, 0 unless visibly equipped (2 bytes)
  - result: equip result code (1 byte)

  Result codes (rAthena `clif_equipitemack_flag`, modern packetver):
  - 0 = OK, 1 = fail (level requirement), 2 = fail (generic).
  """

  use Aesir.Commons.Network.Packet

  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @packet_id 0x0999
  @packet_size 11

  @result_ok 0
  @result_fail_level 1
  @result_fail 2

  @type failure_reason :: :level | :fail

  @type t :: %__MODULE__{
          index: non_neg_integer(),
          wear_location: integer(),
          view_id: integer(),
          result: non_neg_integer()
        }

  defstruct index: 0, wear_location: 0, view_id: 0, result: @result_ok

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def build(%__MODULE__{} = packet) do
    data = <<
      packet.index::16-little,
      packet.wear_location::32-little,
      packet.view_id::16-little,
      packet.result::8
    >>

    build_packet(@packet_id, data)
  end

  @doc """
  Builds a successful equip ack from the server index, worn location bitmask and
  the item's view sprite. The +2 client index offset is applied.
  """
  @spec success(non_neg_integer(), integer(), integer()) :: t()
  def success(server_index, wear_location, view_id) do
    %__MODULE__{
      index: PlayerState.client_index(server_index),
      wear_location: wear_location,
      view_id: view_id,
      result: @result_ok
    }
  end

  @doc """
  Builds a failed equip ack for the given server index. `:level` reports a level
  requirement failure; `:fail` reports a generic failure.
  """
  @spec failure(non_neg_integer(), failure_reason()) :: t()
  def failure(server_index, reason \\ :fail) do
    %__MODULE__{
      index: PlayerState.client_index(server_index),
      result: result_for(reason)
    }
  end

  @doc "Result code: equip succeeded."
  @spec result_ok() :: non_neg_integer()
  def result_ok, do: @result_ok

  @doc "Result code: equip failed because the level requirement is unmet."
  @spec result_fail_level() :: non_neg_integer()
  def result_fail_level, do: @result_fail_level

  @doc "Result code: generic equip failure."
  @spec result_fail() :: non_neg_integer()
  def result_fail, do: @result_fail

  @spec result_for(failure_reason()) :: non_neg_integer()
  defp result_for(:level), do: @result_fail_level
  defp result_for(:fail), do: @result_fail
end
