defmodule Aesir.ZoneServer.Packets.ZcDeleteItemFromBody do
  @moduledoc """
  ZC_DELETE_ITEM_FROM_BODY packet (0x07FA)

  Sent to the owning client to remove (or reduce) an inventory item, naming the
  reason so the client can render the correct notification.

  Layout (`PACKET_ZC_DELETE_ITEM_FROM_BODY`, PACKETVER >= 20091117):
  - packet_id: 0x07FA (2 bytes, little-endian)
  - reason: delete-type code (2 bytes)
  - index: client inventory index, server index + 2 (2 bytes)
  - amount: number of items removed (2 bytes)

  Reason codes (rAthena `clif_delitem`):
  - 0 normal, 1 used for a skill, 2 refine failed, 3 material changed,
    4 moved to storage, 5 moved to cart, 6 sold, 7 consumed by analysis.
  """

  use Aesir.Commons.Network.Packet

  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @packet_id 0x07FA
  @packet_size 8

  @reason_normal 0
  @reason_skill 1
  @reason_refine_failed 2
  @reason_material_changed 3
  @reason_moved_to_storage 4
  @reason_moved_to_cart 5
  @reason_sold 6
  @reason_analysis 7

  @type t :: %__MODULE__{
          index: non_neg_integer(),
          amount: integer(),
          reason: non_neg_integer()
        }

  defstruct index: 0, amount: 0, reason: @reason_normal

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def build(%__MODULE__{index: index, amount: amount, reason: reason}) do
    build_packet(@packet_id, <<reason::16-little, index::16-little, amount::16-little>>)
  end

  @doc """
  Builds a delete-item packet from a server index, amount and reason code,
  applying the +2 client index offset.
  """
  @spec new(non_neg_integer(), integer(), non_neg_integer()) :: t()
  def new(server_index, amount, reason \\ @reason_normal) do
    %__MODULE__{
      index: PlayerState.client_index(server_index),
      amount: amount,
      reason: reason
    }
  end

  @doc "Reason: normal removal."
  @spec reason_normal() :: non_neg_integer()
  def reason_normal, do: @reason_normal

  @doc "Reason: item used for a skill."
  @spec reason_skill() :: non_neg_integer()
  def reason_skill, do: @reason_skill

  @doc "Reason: refine failed."
  @spec reason_refine_failed() :: non_neg_integer()
  def reason_refine_failed, do: @reason_refine_failed

  @doc "Reason: material changed."
  @spec reason_material_changed() :: non_neg_integer()
  def reason_material_changed, do: @reason_material_changed

  @doc "Reason: moved to storage."
  @spec reason_moved_to_storage() :: non_neg_integer()
  def reason_moved_to_storage, do: @reason_moved_to_storage

  @doc "Reason: moved to cart."
  @spec reason_moved_to_cart() :: non_neg_integer()
  def reason_moved_to_cart, do: @reason_moved_to_cart

  @doc "Reason: item sold."
  @spec reason_sold() :: non_neg_integer()
  def reason_sold, do: @reason_sold

  @doc "Reason: consumed by Four Spirit Analysis."
  @spec reason_analysis() :: non_neg_integer()
  def reason_analysis, do: @reason_analysis
end
