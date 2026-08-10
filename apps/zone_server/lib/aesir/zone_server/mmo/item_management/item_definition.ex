defmodule Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition do
  @moduledoc """
  Static item definition (the `item_db` record).

  Loaded as data from `priv/db/items/*.yml` into `:persistent_term`; never a
  per-record module. Carries the loot/equip essentials only - scripts and the
  nested Trade/NoUse/Delay/Stack restrictions are intentionally not modelled yet.
  """

  alias Aesir.ZoneServer.Mmo.ItemManagement.EquipScript

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

  @enforce_keys [:id, :aegis_name, :name]
  defstruct id: nil,
            aegis_name: nil,
            name: nil,
            type: :etc,
            subtype: nil,
            weight: 0,
            buy: 0,
            sell: 0,
            attack: 0,
            magic_attack: 0,
            defense: 0,
            range: 0,
            slots: 0,
            view: 0,
            jobs: [],
            locations: [],
            weapon_level: nil,
            armor_level: nil,
            equip_level_min: 0,
            equip_level_max: 0,
            refineable: false,
            bind_on_equip: false,
            on_use: nil,
            on_equip: nil,
            attack_element: nil

  @type t() :: %__MODULE__{
          id: integer(),
          aegis_name: String.t(),
          name: String.t(),
          type: item_type(),
          subtype: atom(),
          weight: integer(),
          buy: integer(),
          sell: integer(),
          attack: integer(),
          magic_attack: integer(),
          defense: integer(),
          range: integer(),
          slots: integer(),
          view: integer(),
          jobs: [atom()],
          locations: [atom()],
          weapon_level: integer(),
          armor_level: integer(),
          equip_level_min: integer(),
          equip_level_max: integer(),
          refineable: boolean(),
          bind_on_equip: boolean(),
          on_use: String.t() | nil,
          on_equip: EquipScript.program() | nil,
          attack_element: atom()
        }

  @doc """
  The item's sell price, applying the rAthena default: when `sell` is unset
  (`0`), it falls back to half the buy price (`Buy / 2`).
  """
  @spec sell_price(t()) :: non_neg_integer()
  def sell_price(%__MODULE__{sell: sell}) when sell > 0, do: sell
  def sell_price(%__MODULE__{buy: buy}), do: div(buy, 2)
end
