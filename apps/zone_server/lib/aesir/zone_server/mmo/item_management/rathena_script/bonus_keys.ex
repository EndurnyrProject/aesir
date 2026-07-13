defmodule Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.BonusKeys do
  @moduledoc """
  Data-driven table of the rAthena `bonus` keys the equip-script transpiler
  supports, mapping each key to its `modifiers.equipment` destination atom.

  rAthena resolves script constants case-insensitively (corpus scripts spell
  `bPAtk`/`bSMatk`/`bMRes`, while the exported constants are
  `bPatk`/`bSmatk`/`bMres`), so `@keys` is keyed on the **downcased** name and
  lookups downcase their input. This is the equip-side sibling of `CommandSet`
  and the single extension point for the vocabulary: adding a supported key is
  a data edit here, not a change to `EquipCodegen`.
  """

  @type destination :: atom()

  @keys %{
    "bstr" => :str,
    "bagi" => :agi,
    "bvit" => :vit,
    "bint" => :int,
    "bdex" => :dex,
    "bluk" => :luk,
    "bpow" => :pow,
    "bsta" => :sta,
    "bwis" => :wis,
    "bspl" => :spl,
    "bcon" => :con,
    "bcrt" => :crt,
    "bbaseatk" => :atk,
    "batk" => :atk,
    "bmatk" => :matk,
    "bdef" => :def,
    "bmdef" => :mdef,
    "bhit" => :hit,
    "bflee" => :flee,
    "bcritical" => :critical,
    "bpatk" => :patk,
    "bsmatk" => :smatk,
    "bres" => :res,
    "bmres" => :mres,
    "bbreakweaponrate" => :break_weapon_rate,
    "bbreakarmorrate" => :break_armor_rate,
    "bunbreakable" => :unbreakable,
    "bunbreakableweapon" => :unbreakable_weapon,
    "bunbreakablearmor" => :unbreakable_armor,
    "bunbreakablehelm" => :unbreakable_helm,
    "bunbreakableshield" => :unbreakable_shield,
    "bunbreakablegarment" => :unbreakable_garment,
    "bunbreakableshoes" => :unbreakable_shoes
  }

  @doc """
  Resolves a rAthena `bonus` key (any case) to its `modifiers.equipment`
  destination atom. Returns `:error` for out-of-vocabulary keys.
  """
  @spec destination(String.t()) :: {:ok, destination()} | :error
  def destination(name) when is_binary(name), do: Map.fetch(@keys, String.downcase(name))

  @doc """
  The deduplicated set of destination atoms every recognized key maps to.
  """
  @spec destinations() :: [destination()]
  def destinations, do: @keys |> Map.values() |> Enum.uniq()
end
