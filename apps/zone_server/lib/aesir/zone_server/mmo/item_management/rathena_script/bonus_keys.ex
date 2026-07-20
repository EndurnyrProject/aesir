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

  A key may appear in more than one table: `bVariableCastrate` is a global
  cast-rate delta as `bonus` and a per-skill one as `bonus2`. The tables are
  never consulted together — `EquipCodegen` picks one by the command's arity —
  so the two spellings resolve independently.

  Parameterized `bonus2` keys live in `@param_keys`, mapping each key to a
  `t:param_schema/0` (`family` + `param` kind + `unit`); `param_schema/1`,
  `families/0`, and `param_domain/1` expose them to the codegen and to
  `EquipScript.parse!/1` destination validation.

  A third table, `@value_keys`, covers single-argument `bonus` keys whose
  argument is a **constant** rather than an amount (`bonus bAtkEle,Ele_Fire;`).
  These compile to an `EquipScript` `:set` instruction — last writer wins —
  instead of a summed `:bonus`.

  A fourth table, `@pair_keys`, covers `bonus2` keys whose two arguments are
  both **amounts** rather than a param plus an amount (`bonus2 bHPDrainRate,rate,per`).
  Each argument owns its own summing destination, so the codegen emits two
  ordinary `:bonus` instructions and no new IR shape is needed.

  Two per-destination rules also live here rather than in the evaluator, so the
  data table stays the single extension point:

  - `@max_destinations` — destinations that do NOT stack. Both fold points
    (`EquipScript.eval/2` within one item, `Stats` across items) keep the
    largest contribution instead of summing.
  - `@destination_scales` — destinations whose consumer works in finer units
    than the script argument (`bFlee2` is written in percent but rolled against
    a per-mille random). The codegen scales the emitted **expression**, so a
    refine-dependent amount is scaled too.
  """

  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Resolver

  @type destination :: atom()
  @type param :: :race | :element | :size | :class | :skill | :status | :item | :race2
  @type param_schema :: %{family: atom(), param: param(), unit: :percent | :ms | :sp | :per10k}
  @type value_schema :: %{dest: destination(), param: param()}
  @type pair_schema :: %{first: destination(), second: destination()}
  @type flag_schema :: %{family: atom(), param: param(), amount: integer()}

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
    "bmaxhp" => :max_hp,
    "bmaxsp" => :max_sp,
    "bmaxhprate" => :max_hp_rate,
    "bmaxsprate" => :max_sp_rate,
    "baspd" => :aspd,
    "baspdrate" => :aspd_rate,
    "ballstats" => :all_stats,
    "batkrate" => :atk_rate,
    "bmatkrate" => :matk_rate,
    "bvariablecastrate" => :varcast_rate,
    "bdelayrate" => :delay_rate,
    "blongatkrate" => :long_atk_rate,
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
    "bunbreakableshoes" => :unbreakable_shoes,
    "bhprecovrate" => :hp_regen,
    "bsprecovrate" => :sp_regen,
    "busesprate" => :sp_cost_rate,
    "bflee2" => :perfect_dodge,
    "bspeedrate" => :movement_speed,
    "bfixedcast" => :fixed_cast,
    "bhealpower" => :heal_power,
    "bcritatkrate" => :crit_atk_rate,
    "bshortatkrate" => :short_atk_rate,
    "bperfecthitaddrate" => :perfect_hit,
    "bsplashrange" => :splash_range,
    "blongatkdef" => :long_atk_def,
    "bhpgainvalue" => :hp_gain_value,
    "bshortweapondamagereturn" => :short_weapon_damage_return,
    "bfixedcastrate" => :fixcast_rate,
    "badditemhealrate" => :item_heal_rate,
    "bnoknockback" => :no_knockback,
    "bnocastcancel" => :no_cast_cancel
  }

  @max_destinations MapSet.new([:movement_speed, :splash_range])

  @destination_scales %{perfect_dodge: 10}

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
    "bexpaddrace" => %{family: :exp_add_race, param: :race, unit: :percent},
    "bignoredefracerate" => %{family: :ignore_def_race, param: :race, unit: :percent},
    "bignoremdefracerate" => %{family: :ignore_mdef_race, param: :race, unit: :percent},
    "bskillcooldown" => %{family: :skill_cooldown, param: :skill, unit: :ms},
    "bskillusesp" => %{family: :skill_use_sp, param: :skill, unit: :sp},
    "bvariablecastrate" => %{family: :skill_varcast_rate, param: :skill, unit: :percent},
    "bskillusesprate" => %{family: :skill_use_sp_rate, param: :skill, unit: :percent},
    "baddeff" => %{family: :add_eff, param: :status, unit: :per10k},
    "baddeff2" => %{family: :add_eff2, param: :status, unit: :per10k},
    "baddeffwhenhit" => %{family: :add_eff_when_hit, param: :status, unit: :per10k},
    "breseff" => %{family: :res_eff, param: :status, unit: :per10k},
    "bmagicaddclass" => %{family: :magic_addclass, param: :class, unit: :percent},
    "bdropaddrace" => %{family: :drop_add_race, param: :race, unit: :percent},
    "bfixedcastrate" => %{family: :skill_fixcast_rate, param: :skill, unit: :percent},
    "badditemhealrate" => %{family: :add_item_heal, param: :item, unit: :percent},
    "baddrace2" => %{family: :addrace2, param: :race2, unit: :percent}
  }

  @value_keys %{
    "batkele" => %{dest: :atk_ele, param: :element},
    "bdefele" => %{dest: :def_ele, param: :element}
  }

  @pair_keys %{
    "bhpdrainrate" => %{first: :hp_drain_rate, second: :hp_drain_percent},
    "bspdrainrate" => %{first: :sp_drain_rate, second: :sp_drain_percent}
  }

  # Single-argument `bonus` keys whose lone argument is a param constant
  # (`bonus bIgnoreDefRace,RC_Brute;`) rather than an amount. rAthena treats
  # these as full (100%) effects for the named param, so they compile to a
  # `{:bonus, {family, param}, amount}` with the amount baked in — the same
  # `{family, param}` destinations their `*Rate` `bonus2` siblings sum into.
  @flag_param_keys %{
    "bignoredefrace" => %{family: :ignore_def_race, param: :race, amount: 100},
    "bignoremdefrace" => %{family: :ignore_mdef_race, param: :race, amount: 100},
    "bignoredefclass" => %{family: :ignore_def_class, param: :class, amount: 100}
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
    :player_doram,
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
  The deduplicated set of destination atoms every recognized flat-amount key
  maps to, including both halves of each `@pair_keys` entry — they are ordinary
  summing destinations and must validate on the way back in.
  """
  @spec destinations() :: [destination()]
  def destinations do
    (Map.values(@keys) ++ Enum.flat_map(Map.values(@pair_keys), &[&1.first, &1.second]))
    |> Enum.uniq()
  end

  @doc """
  Whether a destination is non-stackable: the strongest single contribution
  applies instead of the sum. Both equip-bonus fold points consult this — the
  per-item `EquipScript.eval/2` and the across-items merge in the player stats
  recompute.
  """
  @spec max_destination?(destination() | {atom(), atom() | pos_integer()}) :: boolean()
  def max_destination?(dest), do: MapSet.member?(@max_destinations, dest)

  @doc """
  The multiplier the codegen applies to a key's amount expression, for
  destinations whose consumer reads finer units than the script writes. Returns
  `1` for the destinations that need no conversion.
  """
  @spec destination_scale(destination()) :: pos_integer()
  def destination_scale(dest) when is_atom(dest), do: Map.get(@destination_scales, dest, 1)

  @doc """
  Resolves a rAthena `bonus2` parameterized key (any case) to its param schema:
  the `modifiers.equipment` family it stores into, the domain its param comes
  from, and its unit. Returns `:error` for out-of-vocabulary keys.
  """
  @spec param_schema(String.t()) :: {:ok, param_schema()} | :error
  def param_schema(name) when is_binary(name), do: Map.fetch(@param_keys, String.downcase(name))

  @doc """
  Resolves a rAthena `bonus2` key whose two arguments are both amounts (any
  case) to the pair of destinations they sum into: `first` for the leading
  argument, `second` for the trailing one. Returns `:error` for out-of-vocabulary
  keys — including the parameterized `bonus2` keys, which `param_schema/1` owns.
  """
  @spec pair_schema(String.t()) :: {:ok, pair_schema()} | :error
  def pair_schema(name) when is_binary(name), do: Map.fetch(@pair_keys, String.downcase(name))

  @doc """
  Resolves a single-argument `bonus` key whose lone argument is a param constant
  (`bonus bIgnoreDefRace,RC_Brute;`) to its `t:flag_schema/0`: the family it
  stores into, the param kind that argument comes from, and the fixed amount.
  Returns `:error` for keys outside that vocabulary.
  """
  @spec flag_param_schema(String.t()) :: {:ok, flag_schema()} | :error
  def flag_param_schema(name) when is_binary(name),
    do: Map.fetch(@flag_param_keys, String.downcase(name))

  @doc """
  The deduplicated set of family atoms every recognized `bonus2` and
  flag-param key maps to.
  """
  @spec families() :: [atom()]
  def families do
    (Map.values(@param_keys) ++ Map.values(@flag_param_keys))
    |> Enum.map(& &1.family)
    |> Enum.uniq()
  end

  @doc """
  The valid atom values for a `bonus2` param domain, used to validate `bonus2`
  arguments at `EquipScript.parse!` time. The `:status` domain is derived from
  `Resolver.effs/0` rather than hardcoded, so it can never drift out of lockstep
  with the resolvable `Eff_*` vocabulary.
  """
  @spec param_domain(:race | :element | :size | :class | :status | :race2) :: [atom()]
  def param_domain(:race), do: @race_domain
  def param_domain(:element), do: @element_domain
  def param_domain(:size), do: @size_domain
  def param_domain(:class), do: @class_domain
  def param_domain(:status), do: Resolver.effs() |> Map.values() |> Enum.uniq()
  def param_domain(:race2), do: Resolver.race2s() |> Map.values() |> Enum.uniq()

  @doc """
  Resolves a single-argument `bonus` key whose argument is a **constant** rather
  than an amount (`bonus bAtkEle,Ele_Fire;`) to its `value_schema/0`. Returns
  `:error` for keys outside that vocabulary — including the ordinary numeric
  keys, which `destination/1` owns.
  """
  @spec value_schema(String.t()) :: {:ok, value_schema()} | :error
  def value_schema(name) when is_binary(name), do: Map.fetch(@value_keys, String.downcase(name))

  @doc """
  The deduplicated set of destination atoms every recognized value key maps to.
  """
  @spec value_destinations() :: [destination()]
  def value_destinations, do: @value_keys |> Map.values() |> Enum.map(& &1.dest) |> Enum.uniq()

  @doc """
  Resolves a value-key destination atom back to its param kind, derived from the
  same `@value_keys` table backing `value_schema/1`. Used by `EquipScript.parse!`
  to validate `:set` instruction values. Returns `:error` outside the vocabulary.
  """
  @spec value_param(destination()) :: {:ok, param()} | :error
  def value_param(dest) when is_atom(dest) do
    @value_keys
    |> Map.values()
    |> Enum.find(&(&1.dest == dest))
    |> case do
      %{param: param} -> {:ok, param}
      nil -> :error
    end
  end

  @doc """
  Resolves a `bonus2` family atom back to its param kind, derived from the
  same `@param_keys` schema table backing `param_schema/1` so the mapping can
  never drift out of sync with it. Used by `EquipScript.parse!` to validate
  tuple bonus destinations. Returns `:error` for a family outside the
  vocabulary.
  """
  @spec family_param(atom()) :: {:ok, param()} | :error
  def family_param(family) when is_atom(family) do
    (Map.values(@param_keys) ++ Map.values(@flag_param_keys))
    |> Enum.find(&(&1.family == family))
    |> case do
      %{param: param} -> {:ok, param}
      nil -> :error
    end
  end
end
