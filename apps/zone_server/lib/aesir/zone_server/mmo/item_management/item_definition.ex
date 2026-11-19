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
  cap. `no_use_sitting` and `use_override` model the seated-use restriction
  and its group-level bypass. Other nested Trade/NoUse/Delay restrictions
  remain unmodelled.
  """

  use TypedStruct

  alias Aesir.ZoneServer.Mmo.ItemManagement.EquipScript
  alias Aesir.ZoneServer.Mmo.JobManagement.ItemEligibility
  alias Aesir.ZoneServer.Mmo.WeaponTypes

  @renewal_classes [:baby, :fourth, :normal, :third, :third_baby, :third_upper, :upper]
  @pre_renewal_classes [:baby, :normal, :upper]

  @ammo_subtypes %{
    arrow: 1,
    dagger: 2,
    bullet: 3,
    shell: 4,
    grenade: 5,
    shuriken: 6,
    kunai: 7,
    cannonball: 8,
    throw_weapon: 9
  }

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

  @typedoc "A static item definition."
  typedstruct enforce: true do
    field :id, integer()
    field :aegis_name, String.t()
    field :name, String.t()
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
    field :jobs, :all | [ItemEligibility.family()], default: :all
    field :classes, [ItemEligibility.category()], default: @renewal_classes
    field :gender, :both | :male | :female, default: :both
    field :locations, [atom()], default: []
    field :weapon_level, integer() | nil, default: nil
    field :armor_level, integer() | nil, default: nil
    field :equip_level_min, integer(), default: 0
    field :equip_level_max, integer(), default: 0
    field :refineable, boolean(), default: false
    field :bind_on_equip, boolean(), default: false
    field :no_consume, boolean(), default: false
    field :no_use_sitting, boolean(), default: false
    field :use_override, non_neg_integer(), default: 100
    field :no_trade, boolean(), default: false
    field :trade_override, non_neg_integer(), default: 100
    field :no_cart, boolean(), default: false
    field :no_storage, boolean(), default: false
    field :no_guild_storage, boolean(), default: false
    field :stack_limit, %{optional(container()) => non_neg_integer()}, default: %{}
    field :on_use, String.t() | nil, default: nil
    field :on_equip, EquipScript.compiled() | nil, default: nil
    field :on_unequip, EquipScript.compiled() | nil, default: nil
    field :attack_element, atom(), default: nil
  end

  @doc """
  Returns the script-visible view of an item.

  Weapons and ammunition return their subtype ordinal, defaulting to `0` when
  unset or unknown. Other item types return their stored appearance view.
  """
  @spec script_view(t()) :: integer()
  def script_view(%__MODULE__{type: :weapon, subtype: subtype}),
    do: WeaponTypes.get_weapon_id(subtype)

  def script_view(%__MODULE__{type: :ammo, subtype: subtype}),
    do: Map.get(@ammo_subtypes, subtype, 0)

  def script_view(%__MODULE__{view: view}), do: view

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
