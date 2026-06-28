defmodule Aesir.ZoneServer.Unit.Player.Appearance do
  @moduledoc """
  Pure look layer for player equipment.

  Derives the equipment-driven look values from a `Stats.Equipment` struct, diffs
  two equipment states into `SpriteChange` packets, and builds the appearance
  fields for a `UnitSpawn`. No DB, no sockets — view ids come from the `Stats`
  view extractors and client look-type ids from `LookType`.

  Weapon and shield collapse into the single `weapon` look slot (`val` carries the
  weapon view, `val2` the shield view), matching the client convention.
  """

  alias Aesir.Net.SpriteChange
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
      weapon: {Stats.weapon_view(equipment), Stats.shield_view(equipment)},
      head_bottom: {Stats.head_bottom_view(equipment), 0},
      head_mid: {Stats.head_mid_view(equipment), 0},
      head_top: {Stats.head_top_view(equipment), 0},
      robe: {Stats.robe_view(equipment), 0}
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
      weapon: Stats.weapon_view(equipment),
      shield: Stats.shield_view(equipment),
      accessory: Stats.head_bottom_view(equipment),
      accessory2: Stats.head_mid_view(equipment),
      accessory3: Stats.head_top_view(equipment),
      robe: Stats.robe_view(equipment)
    }
  end
end
