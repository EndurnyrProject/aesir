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

  A fifth table, `@interval_keys`, covers the periodic HP/SP regen/loss `bonus2`
  keys whose arguments are an **amount and an interval** in milliseconds
  (`bonus2 bHPRegenRate,n,t`, `bonus2 bSPLossRate,n,t`). The interval becomes the
  destination param, so equal-interval contributions across items sum into one
  `{family, interval}` entry — mirroring how the periodic-regen tick accumulates
  and fires per interval. `interval_family/1` exposes the family to the codegen.

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
  @type param ::
          :race
          | :element
          | :size
          | :class
          | :skill
          | :status
          | :item
          | :race2
          | :interval
          | :monster
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
    "bcrate" => :crit_rate,
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
    "bhealpower2" => :heal_power2,
    "bcritatkrate" => :crit_atk_rate,
    "bshortatkrate" => :short_atk_rate,
    "bperfecthitaddrate" => :perfect_hit,
    "bsplashrange" => :splash_range,
    "blongatkdef" => :long_atk_def,
    "bhpgainvalue" => :hp_gain_value,
    "bspgainvalue" => :sp_gain_value,
    "bmagichpgainvalue" => :magic_hp_gain_value,
    "bmagicspgainvalue" => :magic_sp_gain_value,
    "blongspgainvalue" => :long_sp_gain_value,
    "bspdrainvalue" => :sp_drain_value,
    "bnosizefix" => :no_size_fix,
    "bintravision" => :intravision,
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
    "baddrace2" => %{family: :addrace2, param: :race2, unit: :percent},
    "bmagicaddrace2" => %{family: :magic_addrace2, param: :race2, unit: :percent},
    "bignoredefclassrate" => %{family: :ignore_def_class, param: :class, unit: :percent},
    "bignoremdefclassrate" => %{family: :ignore_mdef_class, param: :class, unit: :percent},
    "bsubrace2" => %{family: :subrace2, param: :race2, unit: :percent},
    "baddmonsterdropitem" => %{family: :add_monster_drop, param: :item, unit: :per10k},
    "badddamageclass" => %{family: :add_damage_class, param: :monster, unit: :percent},
    "bspgainrace" => %{family: :sp_gain_race, param: :race, unit: :sp},
    "bexpaddclass" => %{family: :exp_add_class, param: :class, unit: :percent},
    "bsubskill" => %{family: :sub_skill, param: :skill, unit: :percent},
    "bsubdefele" => %{family: :sub_def_ele, param: :element, unit: :percent}
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
    "bignoredefclass" => %{family: :ignore_def_class, param: :class, amount: 100},
    "bdefratioatkclass" => %{family: :def_ratio_atk_class, param: :class, amount: 1}
  }

  # Periodic `bonus2` keys (`bHPRegenRate`/`bHPLossRate`/`bSPRegenRate`/
  # `bSPLossRate`) whose arguments are an amount and an interval in milliseconds.
  # The interval becomes the destination param, so equal-interval contributions
  # sum into one `{family, interval}` entry the regen tick reads and fires per
  # interval.
  @interval_keys %{
    "bhpregenrate" => :hp_regen_bonus,
    "bhplossrate" => :hp_loss_bonus,
    "bspregenrate" => :sp_regen_bonus,
    "bsplossrate" => :sp_loss_bonus
  }

  # `bonus3` keys whose third argument is a trigger-condition flag
  # (short/long/weapon/magic/self/target) rather than a value. Their leading
  # `param, amount` pair is identical to the same key's `bonus2` form, so the
  # transpiler reuses that key's `@param_keys` schema and drops the flag. Only
  # keys whose `{family, param}` destination already has a runtime consumer are
  # listed: the sub-resist family (read on the damage-taken side) and the
  # on-hit status-infliction family. The dropped flag makes the effect apply to
  # every attack instead of only the flagged category — the same breadth the
  # `bonus2` form of these keys already has.
  @bonus3_flag_keys MapSet.new([
                      "baddeff",
                      "baddeffwhenhit",
                      "bsubele",
                      "bsubrace",
                      "bsubsize",
                      "bsubclass"
                    ])

  # `bonus3` keys whose third argument is a genuine second param, not a droppable
  # flag: `bonus3 bAddMonsterDropItem,iid,r,n` gates the drop on the slain mob's
  # race. The transpiler emits a three-element `{family, item_id, race}`
  # destination for these, distinct from the two-argument `bonus2` form's
  # `{family, item_id}`.
  @bonus3_drop_keys MapSet.new(["baddmonsterdropitem"])

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
  Resolves a periodic HP/SP regen/loss `bonus2` key (`bonus2 bHPRegenRate,n,t`)
  to the `modifiers.equipment` family its per-interval entries store into. The
  amount is the leading argument and the interval (the second argument, in
  milliseconds) becomes the destination param. Returns `:error` for keys outside
  that vocabulary.
  """
  @spec interval_family(String.t()) :: {:ok, atom()} | :error
  def interval_family(name) when is_binary(name),
    do: Map.fetch(@interval_keys, String.downcase(name))

  @doc """
  Whether a `bonus3` key's third argument is a droppable trigger-condition flag,
  making its leading `param, amount` pair identical to the key's `bonus2` form.
  The transpiler resolves such keys through `param_schema/1` and discards the
  flag. Returns `false` for every other key (any case).
  """
  @spec bonus3_flag_key?(String.t()) :: boolean()
  def bonus3_flag_key?(name) when is_binary(name),
    do: MapSet.member?(@bonus3_flag_keys, String.downcase(name))

  @doc """
  Whether a `bonus3` key's third argument is a race param gating a monster-drop
  bonus (`bonus3 bAddMonsterDropItem,iid,r,n`) rather than a droppable flag. The
  transpiler resolves such keys to a `{family, item_id, race}` destination.
  Returns `false` for every other key (any case).
  """
  @spec bonus3_drop_key?(String.t()) :: boolean()
  def bonus3_drop_key?(name) when is_binary(name),
    do: MapSet.member?(@bonus3_drop_keys, String.downcase(name))

  @doc """
  The deduplicated set of family atoms every recognized `bonus2` and
  flag-param key maps to.
  """
  @spec families() :: [atom()]
  def families do
    (Map.values(@param_keys) ++ Map.values(@flag_param_keys))
    |> Enum.map(& &1.family)
    |> Kernel.++(Map.values(@interval_keys))
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
    if family in Map.values(@interval_keys) do
      {:ok, :interval}
    else
      (Map.values(@param_keys) ++ Map.values(@flag_param_keys))
      |> Enum.find(&(&1.family == family))
      |> case do
        %{param: param} -> {:ok, param}
        nil -> :error
      end
    end
  end
end
