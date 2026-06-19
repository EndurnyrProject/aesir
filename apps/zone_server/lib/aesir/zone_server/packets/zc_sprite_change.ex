defmodule Aesir.ZoneServer.Packets.ZcSpriteChange do
  @moduledoc """
  ZC_SPRITE_CHANGE packet (0x01D7, `ZC_SPRITE_CHANGE2`)

  Broadcast to nearby players when a unit's appearance changes (weapon, shield,
  headgear, etc.), so others see equip/unequip results.

  Latest layout (`PACKET_ZC_SPRITE_CHANGE`,
  PACKETVER_MAIN >= 20181121 / PACKETVER_RE >= 20180704 / PACKETVER_ZERO):
  - packet_id: 0x01D7 (2 bytes, little-endian)
  - gid: account/object id (4 bytes)
  - type: `LOOK_*` selector (1 byte)
  - val: primary look value (4 bytes)
  - val2: secondary look value (4 bytes)

  rAthena collapses weapon/shield changes into a single `LOOK_WEAPON` packet
  carrying the weapon view in `val` and the shield view in `val2`
  (see `clif_changelook`). Other looks send only `val`, with `val2` zeroed.

  `LOOK_*` constants follow rAthena's `enum _look` ordinal values.
  """

  use Aesir.Commons.Network.Packet

  @packet_id 0x01D7
  @packet_size 15

  @look_base 0
  @look_hair 1
  @look_weapon 2
  @look_head_bottom 3
  @look_head_top 4
  @look_head_mid 5
  @look_hair_color 6
  @look_clothes_color 7
  @look_shield 8
  @look_shoes 9
  @look_robe 12

  @type t :: %__MODULE__{
          gid: non_neg_integer(),
          type: non_neg_integer(),
          val: integer(),
          val2: integer()
        }

  defstruct gid: 0, type: @look_base, val: 0, val2: 0

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @impl true
  def build(%__MODULE__{gid: gid, type: type, val: val, val2: val2}) do
    build_packet(@packet_id, <<gid::32-little, type::8, val::32-little, val2::32-little>>)
  end

  @doc """
  Builds a single-value look change (e.g. headgear). `val2` is zeroed.
  """
  @spec new(non_neg_integer(), non_neg_integer(), integer()) :: t()
  def new(gid, type, val) do
    %__MODULE__{gid: gid, type: type, val: val, val2: 0}
  end

  @doc """
  Builds a weapon/shield look change. rAthena sends both under `LOOK_WEAPON`
  with the weapon view in `val` and the shield view in `val2`.
  """
  @spec weapon(non_neg_integer(), integer(), integer()) :: t()
  def weapon(gid, weapon_view, shield_view) do
    %__MODULE__{gid: gid, type: @look_weapon, val: weapon_view, val2: shield_view}
  end

  @doc """
  Builds a shield look change. Identical wire form to `weapon/3`: sent under
  `LOOK_WEAPON` with the weapon view in `val` and the shield view in `val2`.
  """
  @spec shield(non_neg_integer(), integer(), integer()) :: t()
  def shield(gid, weapon_view, shield_view) do
    weapon(gid, weapon_view, shield_view)
  end

  @doc "LOOK_BASE selector."
  @spec look_base() :: non_neg_integer()
  def look_base, do: @look_base

  @doc "LOOK_HAIR selector."
  @spec look_hair() :: non_neg_integer()
  def look_hair, do: @look_hair

  @doc "LOOK_WEAPON selector."
  @spec look_weapon() :: non_neg_integer()
  def look_weapon, do: @look_weapon

  @doc "LOOK_HEAD_BOTTOM selector."
  @spec look_head_bottom() :: non_neg_integer()
  def look_head_bottom, do: @look_head_bottom

  @doc "LOOK_HEAD_TOP selector."
  @spec look_head_top() :: non_neg_integer()
  def look_head_top, do: @look_head_top

  @doc "LOOK_HEAD_MID selector."
  @spec look_head_mid() :: non_neg_integer()
  def look_head_mid, do: @look_head_mid

  @doc "LOOK_HAIR_COLOR selector."
  @spec look_hair_color() :: non_neg_integer()
  def look_hair_color, do: @look_hair_color

  @doc "LOOK_CLOTHES_COLOR selector."
  @spec look_clothes_color() :: non_neg_integer()
  def look_clothes_color, do: @look_clothes_color

  @doc "LOOK_SHIELD selector."
  @spec look_shield() :: non_neg_integer()
  def look_shield, do: @look_shield

  @doc "LOOK_SHOES selector."
  @spec look_shoes() :: non_neg_integer()
  def look_shoes, do: @look_shoes

  @doc "LOOK_ROBE selector."
  @spec look_robe() :: non_neg_integer()
  def look_robe, do: @look_robe
end
