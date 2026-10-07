defmodule Aesir.ZoneServer.Mmo.ItemManagement.EquipLocation do
  @moduledoc """
  Canonical mapping between equip-location atoms and the rAthena `EQP_*`
  bitmask stored on item rows and sent in inventory/equip packets.

  Bit values are taken verbatim from rAthena's `enum equip_pos` (src/common/mmo.hpp).
  The atoms match what the item loader produces from `priv/db/re/items/equip.yml`
  (rAthena `item_db` Location flag names), including the composite aggregates
  `:both_hand` (`EQP_ARMS`) and `:both_accessory` (`EQP_ACC_RL`).
  """

  import Bitwise

  @single %{
    head_low: 0x000001,
    right_hand: 0x000002,
    garment: 0x000004,
    right_accessory: 0x000008,
    armor: 0x000010,
    left_hand: 0x000020,
    shoes: 0x000040,
    left_accessory: 0x000080,
    head_top: 0x000100,
    head_mid: 0x000200,
    costume_head_top: 0x000400,
    costume_head_mid: 0x000800,
    costume_head_low: 0x001000,
    costume_garment: 0x002000,
    ammo: 0x008000,
    shadow_armor: 0x010000,
    shadow_weapon: 0x020000,
    shadow_shield: 0x040000,
    shadow_shoes: 0x080000,
    shadow_right_accessory: 0x100000,
    shadow_left_accessory: 0x200000
  }

  @composite %{
    both_hand: @single.right_hand ||| @single.left_hand,
    both_accessory: @single.right_accessory ||| @single.left_accessory
  }

  @atom_to_bitmask Map.merge(@single, @composite)

  @equip_index_order [
    :left_accessory,
    :right_accessory,
    :shoes,
    :garment,
    :head_low,
    :head_mid,
    :head_top,
    :armor,
    :left_hand,
    :right_hand,
    :costume_head_top,
    :costume_head_mid,
    :costume_head_low,
    :costume_garment,
    :ammo,
    :shadow_armor,
    :shadow_weapon,
    :shadow_shield,
    :shadow_shoes,
    :shadow_right_accessory,
    :shadow_left_accessory
  ]

  @shared_slots %{
    right_hand: [:left_hand],
    head_mid: [:head_low],
    head_top: [:head_mid, :head_low],
    costume_head_mid: [:costume_head_low],
    costume_head_top: [:costume_head_mid, :costume_head_low]
  }

  @decode_order @single
                |> Enum.sort_by(fn {_atom, bit} -> bit end)
                |> Enum.map(fn {atom, bit} -> {bit, atom} end)

  @doc """
  ORs the EQP bits for a list of location atoms into a single bitmask.

  Composite atoms expand to their combined bits. An empty list yields `0`.
  """
  @spec location_atoms_to_bitmask([atom()]) :: non_neg_integer()
  def location_atoms_to_bitmask(atoms) when is_list(atoms) do
    Enum.reduce(atoms, 0, fn atom, acc -> acc ||| location_bit(atom) end)
  end

  @doc """
  Decodes a bitmask into the single-location atoms whose bit is set, ordered by
  ascending bit value. Composite atoms are never emitted.
  """
  @spec bitmask_to_location_atoms(non_neg_integer()) :: [atom()]
  def bitmask_to_location_atoms(bitmask) when is_integer(bitmask) and bitmask >= 0 do
    for {bit, atom} <- @decode_order, (bitmask &&& bit) != 0, do: atom
  end

  @doc """
  Returns the EQP bit for a single location atom, or `0` if unknown.
  """
  @spec location_bit(atom()) :: non_neg_integer()
  def location_bit(atom) when is_atom(atom), do: Map.get(@atom_to_bitmask, atom, 0)

  @doc """
  The equipment slots in the order a character's worn items run their scripts,
  which is also the slot numbering item scripts use to name a slot.
  """
  @spec equip_index_order() :: [atom()]
  def equip_index_order, do: @equip_index_order

  @doc """
  The position in `equip_index_order/0` at which an item worn at `bitmask` runs
  its scripts, `nil` when it occupies none of those slots.

  An item spanning several slots runs once: a two-handed weapon at the left
  hand, a multi-slot headgear (costume or not) at its lowest head slot.
  """
  @spec equip_index(non_neg_integer()) :: non_neg_integer() | nil
  def equip_index(bitmask) when is_integer(bitmask) and bitmask >= 0 do
    locations = bitmask_to_location_atoms(bitmask)

    Enum.find_index(@equip_index_order, fn slot ->
      slot in locations and not Enum.any?(Map.get(@shared_slots, slot, []), &(&1 in locations))
    end)
  end
end
