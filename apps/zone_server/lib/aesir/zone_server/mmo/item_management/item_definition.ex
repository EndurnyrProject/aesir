defmodule Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition do
  @moduledoc """
  Static item definition (the `item_db` record).

  Loaded as data from `priv/db/items/*.yml` into `:persistent_term`; never a
  per-record module. Carries the loot/equip essentials only - scripts and the
  nested Trade/NoUse/Delay/Stack restrictions are intentionally not modelled yet.
  """
  use TypedStruct

  @typedoc "Broad item category (rAthena `Type`)."
  @type item_type ::
          :healing
          | :usable
          | :etc
          | :armor
          | :weapon
          | :card
          | :pet_egg
          | :pet_armor
          | :ammo
          | :delay_consume
          | :shadow_gear
          | :cash

  typedstruct do
    field :id, integer(), enforce: true
    field :aegis_name, String.t(), enforce: true
    field :name, String.t(), enforce: true
    field :type, item_type(), default: :etc
    field :subtype, atom(), default: nil
    field :weight, integer(), default: 0
    field :buy, integer(), default: 0
    field :sell, integer(), default: 0
    field :attack, integer(), default: 0
    field :magic_attack, integer(), default: 0
    field :defense, integer(), default: 0
    field :range, integer(), default: 0
    field :slots, integer(), default: 0
    field :view, integer(), default: 0
    field :jobs, [atom()], default: []
    field :locations, [atom()], default: []
    field :weapon_level, integer(), default: nil
    field :armor_level, integer(), default: nil
    field :equip_level_min, integer(), default: 0
    field :equip_level_max, integer(), default: 0
    field :refineable, boolean(), default: false
  end
end
