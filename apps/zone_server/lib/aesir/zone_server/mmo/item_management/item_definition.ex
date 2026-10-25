defmodule Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition do
  @moduledoc """
  Static item definition (the `item_db` record).

  Loaded as data from `priv/db/re/items/*.yml` into `:persistent_term`; never a
  per-record module. Carries the loot/equip essentials only. The `NoTrade`,
  `NoCart`, `NoStorage` and `NoGuildStorage` restrictions are modelled
  (`no_trade`, `no_cart`, `no_storage`, `no_guild_storage`) along with the
  trade restriction's group-level override (`trade_override`), the `NoConsume`
  usable flag as `no_consume` (the item is never removed, and its item skill can
  still cast), and the `Stack` block as `stack_limit`, the per-container stack
  cap. The other nested Trade/NoUse/Delay restrictions remain intentionally
  unmodelled.
  """

  alias Aesir.ZoneServer.Mmo.ItemManagement.EquipScript
  alias Aesir.ZoneServer.Mmo.JobManagement.ItemEligibility

  @renewal_classes [:baby, :fourth, :normal, :third, :third_baby, :third_upper, :upper]
  @pre_renewal_classes [:baby, :normal, :upper]

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

  @typedoc "An item container a stack limit can apply to."
  @type container :: :inventory | :cart | :storage | :guild_storage

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
            jobs: :all,
            classes: @renewal_classes,
            gender: :both,
            locations: [],
            weapon_level: nil,
            armor_level: nil,
            equip_level_min: 0,
            equip_level_max: 0,
            refineable: false,
            bind_on_equip: false,
            no_consume: false,
            no_trade: false,
            trade_override: 100,
            no_cart: false,
            no_storage: false,
            no_guild_storage: false,
            stack_limit: %{},
            on_use: nil,
            on_equip: nil,
            on_unequip: nil,
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
          jobs: :all | [ItemEligibility.family()],
          classes: [ItemEligibility.category()],
          gender: :both | :male | :female,
          locations: [atom()],
          weapon_level: integer(),
          armor_level: integer(),
          equip_level_min: integer(),
          equip_level_max: integer(),
          refineable: boolean(),
          bind_on_equip: boolean(),
          no_consume: boolean(),
          no_trade: boolean(),
          trade_override: non_neg_integer(),
          no_cart: boolean(),
          no_storage: boolean(),
          no_guild_storage: boolean(),
          stack_limit: %{optional(container()) => non_neg_integer()},
          on_use: String.t() | nil,
          on_equip: EquipScript.program() | nil,
          on_unequip: EquipScript.program() | nil,
          attack_element: atom()
        }

  @doc "Returns the unrestricted item class categories for a game mode."
  @spec default_classes(ItemEligibility.mode()) :: [ItemEligibility.category()]
  def default_classes(:renewal), do: @renewal_classes
  def default_classes(:pre_renewal), do: @pre_renewal_classes

  @doc "Applies item-specific effective-gender restrictions."
  @spec normalize_gender(t()) :: t()
  def normalize_gender(%__MODULE__{id: 2634} = definition), do: %{definition | gender: :male}
  def normalize_gender(%__MODULE__{id: 2635} = definition), do: %{definition | gender: :female}

  def normalize_gender(%__MODULE__{subtype: :musical} = definition),
    do: %{definition | gender: :male}

  def normalize_gender(%__MODULE__{subtype: :whip} = definition),
    do: %{definition | gender: :female}

  def normalize_gender(%__MODULE__{} = definition), do: definition

  @doc """
  Whether a newly obtained copy of this item starts identified.

  Weapons, armour, pet armour and shadow gear arrive unidentified; every other
  type is identified. Accepts a definition or any map carrying its `:type`, so
  catalog preview shapes read the same rule.
  """
  @spec identified_on_obtain?(t() | %{required(:type) => item_type()}) :: boolean()
  def identified_on_obtain?(%{type: type}),
    do: type not in [:weapon, :armor, :pet_armor, :shadow_gear]

  @doc """
  Whether copies of this item share one slot.

  Weapons, armour, pet eggs, pet armour and shadow gear take one slot per
  copy; every other type, ammunition included, stacks. Accepts a definition or
  any map carrying its `:type`.
  """
  @spec stackable?(t() | %{required(:type) => item_type()}) :: boolean()
  def stackable?(%{type: type}),
    do: type not in [:weapon, :armor, :pet_egg, :pet_armor, :shadow_gear]

  @doc """
  The most copies one stack of this item may hold in `container`, or `nil`
  when only the shared 30,000 cap applies.
  """
  @spec stack_limit(t(), container()) :: non_neg_integer() | nil
  def stack_limit(%__MODULE__{stack_limit: limits}, container), do: Map.get(limits, container)

  @doc """
  The item's sell price, applying the rAthena default: when `sell` is unset
  (`0`), it falls back to half the buy price (`Buy / 2`).
  """
  @spec sell_price(t()) :: non_neg_integer()
  def sell_price(%__MODULE__{sell: sell}) when sell > 0, do: sell
  def sell_price(%__MODULE__{buy: buy}), do: div(buy, 2)
end
