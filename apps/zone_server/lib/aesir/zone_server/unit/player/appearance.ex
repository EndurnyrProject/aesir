defmodule Aesir.ZoneServer.Unit.Player.Appearance do
  @moduledoc """
  Pure look layer for player equipment.

  Derives the equipment-driven look values from a `Stats.Equipment` struct, diffs
  two equipment states into `SpriteChange` packets, and builds the appearance
  fields for a `UnitSpawn`. No DB, no sockets; view ids are read from the item
  catalog and client look-type ids from `LookType`.

  Weapon and shield collapse into the single `weapon` look slot (`val` carries the
  weapon view, `val2` the shield view), matching the client convention.
  """

  alias Aesir.Net.SpriteChange
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.WeaponTypes
  alias Aesir.ZoneServer.Unit.LookType
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment

  @typedoc "Equipment-driven look values keyed by look slot, each `{val, val2}`."
  @type look_views :: %{atom() => {non_neg_integer(), non_neg_integer()}}

  # Fixed slot -> look-type order so `diff/3` output is deterministic.
  @slot_look_types [
    weapon: LookType.weapon(),
    head_bottom: LookType.head_bottom(),
    head_mid: LookType.head_mid(),
    head_top: LookType.head_top(),
    robe: LookType.robe()
  ]

  @doc """
  Returns the equipment-driven look values keyed by look slot.

  The `weapon` slot carries `{weapon_view, shield_view}`; every head and robe slot
  carries `{view, 0}`.
  """
  @spec look_views(Equipment.t()) :: look_views()
  def look_views(%Equipment{} = equipment) do
    %{
      weapon: {weapon_view(equipment), shield_view(equipment)},
      head_bottom: {head_bottom_view(equipment), 0},
      head_mid: {head_mid_view(equipment), 0},
      head_top: {head_top_view(equipment), 0},
      robe: {robe_view(equipment), 0}
    }
  end

  @doc """
  Diffs two equipment states into one `SpriteChange` per look slot whose
  `{val, val2}` changed, each tagged with `gid`. Returns `[]` when nothing changed.
  """
  @spec diff(non_neg_integer(), Equipment.t(), Equipment.t()) :: [SpriteChange.t()]
  def diff(gid, %Equipment{} = old_equipment, %Equipment{} = new_equipment) do
    old_views = look_views(old_equipment)
    new_views = look_views(new_equipment)

    for {slot, type} <- @slot_look_types, old_views[slot] != new_views[slot] do
      {val, val2} = new_views[slot]
      %SpriteChange{gid: gid, type: type, val: val, val2: val2}
    end
  end

  @doc """
  Builds the `UnitSpawn` appearance fields from the same view extractors.
  """
  @spec spawn_fields(Equipment.t()) :: %{
          weapon: non_neg_integer(),
          shield: non_neg_integer(),
          accessory: non_neg_integer(),
          accessory2: non_neg_integer(),
          accessory3: non_neg_integer(),
          robe: non_neg_integer()
        }
  def spawn_fields(%Equipment{} = equipment) do
    %{
      weapon: weapon_view(equipment),
      shield: shield_view(equipment),
      accessory: head_bottom_view(equipment),
      accessory2: head_mid_view(equipment),
      accessory3: head_top_view(equipment),
      robe: robe_view(equipment)
    }
  end

  @doc """
  Returns the client view (sprite) id of the equipped weapon, or `0` when bare-handed.
  """
  @spec weapon_view(Equipment.t()) :: non_neg_integer()
  def weapon_view(%Equipment{right_hand: nil}), do: 0

  def weapon_view(%Equipment{right_hand: nameid} = equipment) do
    # A weapon's sprite is its weapon-class view (dagger, one-handed sword, ...),
    # derived from the item subtype. Item DBs only set an explicit `view` for
    # weapons with a unique sprite (e.g. collection weapons); prefer that when
    # present, otherwise fall back to the class so ordinary weapons still render.
    case view_of(nameid) do
      0 -> WeaponTypes.get_weapon_id(Stats.weapon_type(equipment))
      view -> view
    end
  end

  @doc """
  Returns the client view (sprite) id of the equipped shield, or `0` when none
  or when the left-hand item is itself a weapon (two-hander occupying both hands).
  """
  @spec shield_view(Equipment.t()) :: non_neg_integer()
  def shield_view(%Equipment{left_hand: left_hand} = equipment) do
    if Stats.shield?(equipment), do: view_of(left_hand), else: 0
  end

  @doc """
  Returns the client view (sprite) id of the equipped head-top item, or `0` when none.
  """
  @spec head_top_view(Equipment.t()) :: non_neg_integer()
  def head_top_view(%Equipment{head_top: nil}), do: 0
  def head_top_view(%Equipment{head_top: nameid}), do: view_of(nameid)

  @doc """
  Returns the client view (sprite) id of the equipped head-mid item, or `0` when none.
  """
  @spec head_mid_view(Equipment.t()) :: non_neg_integer()
  def head_mid_view(%Equipment{head_mid: nil}), do: 0
  def head_mid_view(%Equipment{head_mid: nameid}), do: view_of(nameid)

  @doc """
  Returns the client view (sprite) id of the equipped head-low (head-bottom) item, or `0` when none.
  """
  @spec head_bottom_view(Equipment.t()) :: non_neg_integer()
  def head_bottom_view(%Equipment{head_low: nil}), do: 0
  def head_bottom_view(%Equipment{head_low: nameid}), do: view_of(nameid)

  @doc """
  Returns the client view (sprite) id of the equipped garment (robe), or `0` when none.
  """
  @spec robe_view(Equipment.t()) :: non_neg_integer()
  def robe_view(%Equipment{garment: nil}), do: 0
  def robe_view(%Equipment{garment: nameid}), do: view_of(nameid)

  defp view_of(nil), do: 0

  defp view_of(nameid) do
    case ItemManagement.get_item_by_id(nameid) do
      {:ok, %ItemDefinition{view: view}} -> view
      _ -> 0
    end
  end
end
