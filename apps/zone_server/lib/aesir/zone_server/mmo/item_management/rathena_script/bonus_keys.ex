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

  Parameterized `bonus2` keys live in `@param_keys`, mapping each key to a
  `t:param_schema/0` (`family` + `param` kind + `unit`); `param_schema/1`,
  `families/0`, and `param_domain/1` expose them to the codegen and to
  `EquipScript.parse!/1` destination validation.
  """

  @type destination :: atom()
  @type param :: :race | :element | :size | :class | :skill
  @type param_schema :: %{family: atom(), param: param(), unit: :percent}

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

  @param_keys %{
    "baddrace" => %{family: :addrace, param: :race, unit: :percent},
    "baddele" => %{family: :addele, param: :element, unit: :percent},
    "baddsize" => %{family: :addsize, param: :size, unit: :percent},
    "baddclass" => %{family: :addclass, param: :class, unit: :percent},
    "bsubrace" => %{family: :subrace, param: :race, unit: :percent},
    "bsubele" => %{family: :subele, param: :element, unit: :percent},
    "bsubsize" => %{family: :subsize, param: :size, unit: :percent},
    "bsubclass" => %{family: :subclass, param: :class, unit: :percent},
    "bmagicaddrace" => %{family: :magic_addrace, param: :race, unit: :percent},
    "bmagicaddele" => %{family: :magic_addele, param: :element, unit: :percent},
    "bmagicaddsize" => %{family: :magic_addsize, param: :size, unit: :percent},
    "bmagicatkele" => %{family: :magic_atk_ele, param: :element, unit: :percent},
    "bskillatk" => %{family: :skill_atk, param: :skill, unit: :percent},
    "bignoredefracerate" => %{family: :ignore_def_race, param: :race, unit: :percent},
    "bignoremdefracerate" => %{family: :ignore_mdef_race, param: :race, unit: :percent}
  }

  @race_domain [
    :formless,
    :undead,
    :brute,
    :plant,
    :insect,
    :fish,
    :demon,
    :demi_human,
    :angel,
    :dragon,
    :player_human,
    :all
  ]
  @element_domain [
    :neutral,
    :water,
    :earth,
    :fire,
    :wind,
    :poison,
    :holy,
    :shadow,
    :ghost,
    :undead,
    :all
  ]
  @size_domain [:small, :medium, :large, :all]
  @class_domain [:normal, :boss, :all]

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

  @doc """
  Resolves a rAthena `bonus2` damage-tier key (any case) to its param schema:
  the `modifiers.equipment` family it stores into, the domain its param comes
  from, and its unit. Returns `:error` for out-of-vocabulary keys.
  """
  @spec param_schema(String.t()) :: {:ok, param_schema()} | :error
  def param_schema(name) when is_binary(name), do: Map.fetch(@param_keys, String.downcase(name))

  @doc """
  The deduplicated set of family atoms every recognized `bonus2` key maps to.
  """
  @spec families() :: [atom()]
  def families, do: @param_keys |> Map.values() |> Enum.map(& &1.family) |> Enum.uniq()

  @doc """
  The valid atom values for a `bonus2` param domain, used to validate `bonus2`
  arguments at `EquipScript.parse!` time.
  """
  @spec param_domain(:race | :element | :size | :class) :: [atom()]
  def param_domain(:race), do: @race_domain
  def param_domain(:element), do: @element_domain
  def param_domain(:size), do: @size_domain
  def param_domain(:class), do: @class_domain

  @doc """
  Resolves a `bonus2` family atom back to its param kind, derived from the
  same `@param_keys` schema table backing `param_schema/1` so the mapping can
  never drift out of sync with it. Used by `EquipScript.parse!` to validate
  tuple bonus destinations. Returns `:error` for a family outside the
  vocabulary.
  """
  @spec family_param(atom()) :: {:ok, param()} | :error
  def family_param(family) when is_atom(family) do
    @param_keys
    |> Map.values()
    |> Enum.find(&(&1.family == family))
    |> case do
      %{param: param} -> {:ok, param}
      nil -> :error
    end
  end
end
