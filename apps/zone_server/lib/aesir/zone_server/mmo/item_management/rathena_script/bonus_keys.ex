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

  import Bitwise

  alias Aesir.ZoneServer.Mmo.BattleFlag
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
          | :item_group
          | :race2
          | :interval
          | :monster
          | :battle
  @type param_schema :: %{
          family: atom(),
          param: param(),
          unit: :percent | :ms | :sp | :per10k | :cells
        }
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
    "bdefrate" => :def_rate,
    "bdef2rate" => :def2_rate,
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
    "bcastrate" => :varcast_rate,
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
    "bhitrate" => :hit_rate,
    "bspeedrate" => :movement_speed,
    "bspeedaddrate" => :movement_speed_add,
    "bcriticallong" => :critical_long,
    "bnoregen" => :no_regen,
    "bfixedcast" => :fixed_cast,
    "bhealpower" => :heal_power,
    "bhealpower2" => :heal_power2,
    "bcritatkrate" => :crit_atk_rate,
    "bshortatkrate" => :short_atk_rate,
    "bperfecthitrate" => :perfect_hit_rate,
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

  @max_destinations MapSet.new([:movement_speed, :perfect_hit_rate, :splash_range])

  @destination_scales %{perfect_dodge: 10}

  @param_keys %{
    "baddrace" => %{family: :addrace, param: :race, unit: :percent},
    "bcomarace" => %{family: :coma_race, param: :race, unit: :per10k},
    "bcomaclass" => %{family: :coma_class, param: :class, unit: :per10k},
    "bcriticaladdrace" => %{family: :critical_add_race, param: :race, unit: :percent},
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
    "bskillheal" => %{family: :skill_heal, param: :skill, unit: :percent},
    "baddskillblow" => %{family: :add_skill_blow, param: :skill, unit: :cells},
    "bexpaddrace" => %{family: :exp_add_race, param: :race, unit: :percent},
    "bignoredefracerate" => %{family: :ignore_def_race, param: :race, unit: :percent},
    "bignoremdefracerate" => %{family: :ignore_mdef_race, param: :race, unit: :percent},
    "bskillcooldown" => %{family: :skill_cooldown, param: :skill, unit: :ms},
    "bskillusesp" => %{family: :skill_use_sp, param: :skill, unit: :sp},
    "bvariablecastrate" => %{family: :skill_varcast_rate, param: :skill, unit: :percent},
    "bcastrate" => %{family: :skill_varcast_rate, param: :skill, unit: :percent},
    "bskillusesprate" => %{family: :skill_use_sp_rate, param: :skill, unit: :percent},
    "baddeff" => %{family: :add_eff, param: :status, unit: :per10k},
    "baddeff2" => %{family: :add_eff2, param: :status, unit: :per10k},
    "baddeffwhenhit" => %{family: :add_eff_when_hit, param: :status, unit: :per10k},
    "breseff" => %{family: :res_eff, param: :status, unit: :per10k},
    "bmagicaddclass" => %{family: :magic_addclass, param: :class, unit: :percent},
    "bdropaddrace" => %{family: :drop_add_race, param: :race, unit: :percent},
    "bfixedcastrate" => %{family: :skill_fixcast_rate, param: :skill, unit: :percent},
    "badditemhealrate" => %{family: :add_item_heal, param: :item, unit: :percent},
    "badditemgrouphealrate" => %{
      family: :add_item_group_heal,
      param: :item_group,
      unit: :percent
    },
    "baddrace2" => %{family: :addrace2, param: :race2, unit: :percent},
    "bmagicaddrace2" => %{family: :magic_addrace2, param: :race2, unit: :percent},
    "bignoredefclassrate" => %{family: :ignore_def_class, param: :class, unit: :percent},
    "bignoremdefclassrate" => %{family: :ignore_mdef_class, param: :class, unit: :percent},
    "bsubrace2" => %{family: :subrace2, param: :race2, unit: :percent},
    "baddmonsterdropitem" => %{family: :add_monster_drop, param: :item, unit: :per10k},
    "baddmonsterdropitemgroup" => %{
      family: :add_monster_drop_group,
      param: :item_group,
      unit: :per10k
    },
    "badddamageclass" => %{family: :add_damage_class, param: :monster, unit: :percent},
    "badddefmonster" => %{family: :add_def_monster, param: :monster, unit: :percent},
    "bspgainrace" => %{family: :sp_gain_race, param: :race, unit: :sp},
    "bspdrainvaluerace" => %{family: :sp_drain_race, param: :race, unit: :sp},
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

  @paired_choice_keys %{"bgetzenynum" => :get_zeny}
  @bitwise_destinations MapSet.new([:no_regen])

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

  # `bonus3` keys whose third argument is a trigger-condition flag rather than a
  # value. Their leading `param, amount` pair is identical to the same key's
  # `bonus2` form, so the transpiler reuses that key's `@param_keys` schema and
  # keeps the flag as part of the destination: the bonus then applies only to
  # attacks of the flagged kind, while the unflagged `bonus2` form keeps
  # applying to every attack.
  #
  # The value names which flag vocabulary the key's argument is written in - the
  # sub-resist family classifies the incoming attack (`:battle`), the on-hit
  # status families additionally choose their victim (`:trigger`).
  # `bonus3 bAddEffOnSkill,sk,eff,n` inflicts a status when one named skill
  # lands, rather than on ordinary hits. Its destination carries both the skill
  # that triggers it and the status it inflicts.
  @on_skill_status_keys %{"baddeffonskill" => :add_eff_on_skill}

  @flag_keys %{
    "baddeff" => :trigger,
    "baddeffwhenhit" => :trigger,
    "bsubele" => :battle,
    "bsubrace" => :battle,
    "bsubsize" => :battle,
    "bsubclass" => :battle
  }

  # The extra argument on bonus4 bAddEff/bAddEffWhenHit is a duration override
  # in milliseconds. It rides in a sibling family with the same status/flag param
  # as the chance entry, keeping every equipment modifier value numeric.
  @status_duration_families %{
    "baddeff" => :add_eff_duration,
    "baddeffwhenhit" => :add_eff_when_hit_duration
  }

  # Category-gated vanish entries share a normalized battle flag; chance and
  # percent are sibling numeric families so equal flags sum independently.
  @vanish_schemas %{
    "bhpvanishrate" => %{rate: :hp_vanish_rate, percent: :hp_vanish_percent},
    "bspvanishrate" => %{rate: :sp_vanish_rate, percent: :sp_vanish_percent}
  }

  # Race-gated Vellum entries use the target race instead of a battle flag.
  @race_vanish_schemas %{
    "bhpvanishracerate" => %{rate: :hp_vanish_race_rate, percent: :hp_vanish_race_percent},
    "bspvanishracerate" => %{rate: :sp_vanish_race_rate, percent: :sp_vanish_race_percent}
  }

  # Normal-weapon-hit procs keyed by target race. Registration is last-writer
  # rather than additive, so all sibling fields use overwrite merge semantics.
  @defender_proc_schemas %{
    "bsetdefrace" => %{
      rate: :def_set_race_rate,
      duration: :def_set_race_duration,
      value: :def_set_race_value
    },
    "bsetmdefrace" => %{
      rate: :mdef_set_race_rate,
      duration: :mdef_set_race_duration,
      value: :mdef_set_race_value
    },
    "bstatenorecoverrace" => %{
      rate: :no_recover_race_rate,
      duration: :no_recover_race_duration
    }
  }
  @defender_proc_families Enum.flat_map(Map.values(@defender_proc_schemas), &Map.values/1)

  # Equip autocast keys: a chance for a worn item to cast a skill by itself.
  # The value is the trigger point - `:attack` fires on the wearer's own landed
  # hits, `:when_hit` on hits taken, and `:on_skill` on the wearer casting one
  # named skill.
  @auto_cast_keys %{
    "bautospell" => :attack,
    "bautospellwhenhit" => :when_hit,
    "bautospellonskill" => :on_skill
  }

  # A when-hit proc is armed for both normal attacks and skills, unlike the
  # attack-side default of normal swings only. The remaining axes fill from the
  # script's own flag argument.
  @when_hit_preset_flag BattleFlag.id(:normal) ||| BattleFlag.id(:skill)

  # `bonus3` keys whose third argument is a genuine second param, not a droppable
  # flag: a bonus item drop gated on the mob that died. The gate is either the
  # mob's race (`bonus3 bAddMonsterDropItem,iid,r,n`) or one specific monster
  # (`bonus3 bAddMonsterIdDropItem,iid,mid,n`). Both emit a three-element
  # `{family, item_id, gate}` destination - a race atom or a monster id -
  # distinct from the two-argument `bonus2` form's `{family, item_id}`.
  @bonus3_drop_keys %{
    "baddmonsterdropitem" => {:add_monster_drop, :race},
    "baddmonsteriddropitem" => {:add_monster_drop, :monster}
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
    (Map.values(@keys) ++
       Map.values(@paired_choice_keys) ++
       Enum.flat_map(Map.values(@pair_keys), &[&1.first, &1.second]))
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

  @doc "Whether a numeric destination combines contributions as a bit mask."
  @spec bitwise_destination?(destination()) :: boolean()
  def bitwise_destination?(dest), do: MapSet.member?(@bitwise_destinations, dest)

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

  @doc "Resolves a `bonus2` key whose amount stays paired with its strongest rate."
  @spec paired_choice_destination(String.t()) :: {:ok, destination()} | :error
  def paired_choice_destination(name) when is_binary(name),
    do: Map.fetch(@paired_choice_keys, String.downcase(name))

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
  Resolves a key whose `bonus3` form takes a trigger-condition flag as its
  third argument to the flag vocabulary that argument is written in:
  `:battle` for the sub-resist family, `:trigger` for the on-hit status
  families.

  The leading `param, amount` pair is identical to the key's `bonus2` form, so
  the transpiler resolves it through `param_schema/1` and folds the flag into
  the destination. Returns `:error` for every other key (any case).
  """
  @spec flag_kind(String.t()) :: {:ok, :battle | :trigger} | :error
  def flag_kind(name) when is_binary(name), do: Map.fetch(@flag_keys, String.downcase(name))

  @doc "Returns the sibling duration family for bonus4 status-infliction keys."
  @spec status_duration_family(String.t()) :: {:ok, atom()} | :error
  def status_duration_family(name) when is_binary(name),
    do: Map.fetch(@status_duration_families, String.downcase(name))

  @doc "Returns the category-gated HP/SP vanish sibling families for a key."
  @spec vanish_schema(String.t()) :: {:ok, %{rate: atom(), percent: atom()}} | :error
  def vanish_schema(name) when is_binary(name),
    do: Map.fetch(@vanish_schemas, String.downcase(name))

  @doc "Returns the race-gated HP/SP vanish sibling families for a key."
  @spec race_vanish_schema(String.t()) :: {:ok, %{rate: atom(), percent: atom()}} | :error
  def race_vanish_schema(name) when is_binary(name),
    do: Map.fetch(@race_vanish_schemas, String.downcase(name))

  @doc "Returns the race-gated defender-status sibling families for a key."
  @spec defender_proc_schema(String.t()) ::
          {:ok,
           %{required(:rate) => atom(), required(:duration) => atom(), optional(:value) => atom()}}
          | :error
  def defender_proc_schema(name) when is_binary(name),
    do: Map.fetch(@defender_proc_schemas, String.downcase(name))

  @doc "Returns the number of numeric fields carried by a defender proc key."
  @spec defender_proc_arity(String.t()) :: {:ok, 2 | 3} | :error
  def defender_proc_arity(name) when is_binary(name) do
    case defender_proc_schema(name) do
      {:ok, schema} -> {:ok, map_size(schema)}
      :error -> :error
    end
  end

  @doc "Whether a numeric equipment destination uses last-writer merge semantics."
  @spec overwrite_destination?(term()) :: boolean()
  def overwrite_destination?({family, _param}), do: family in @defender_proc_families
  def overwrite_destination?(_destination), do: false

  @doc """
  Resolves a key whose `bonus3` form inflicts a status when one named skill
  lands (`bonus3 bAddEffOnSkill,sk,eff,n`) to the family it stores into.
  Returns `:error` for every other key (any case).
  """
  @spec on_skill_status_family(String.t()) :: {:ok, atom()} | :error
  def on_skill_status_family(name) when is_binary(name),
    do: Map.fetch(@on_skill_status_keys, String.downcase(name))

  @doc """
  Resolves an equip autocast key to the trigger point it arms: `:attack` for a
  proc on the wearer's own landed hits, `:when_hit` for one on hits taken,
  `:on_skill` for one on casting a named skill. Returns `:error` for every other
  key (any case).
  """
  @spec auto_cast_trigger(String.t()) :: {:ok, :attack | :when_hit | :on_skill} | :error
  def auto_cast_trigger(name) when is_binary(name),
    do: Map.fetch(@auto_cast_keys, String.downcase(name))

  @doc """
  The battle-flag bits an autocast trigger arms before the script's own flag
  argument is folded in. A when-hit proc covers normal attacks and skills
  alike; an attack-side proc adds nothing of its own.
  """
  @spec auto_cast_preset_flag(:attack | :when_hit | :on_skill) :: non_neg_integer()
  def auto_cast_preset_flag(:when_hit), do: @when_hit_preset_flag
  def auto_cast_preset_flag(:attack), do: 0
  def auto_cast_preset_flag(:on_skill), do: 0

  @doc """
  Whether a `bonus3` key's third argument gates a bonus item drop rather than
  being a droppable flag. The transpiler resolves such keys to a
  `{family, item_id, gate}` destination. Returns `false` for every other key
  (any case).
  """
  @spec bonus3_drop_key?(String.t()) :: boolean()
  def bonus3_drop_key?(name) when is_binary(name),
    do: Map.has_key?(@bonus3_drop_keys, String.downcase(name))

  @doc """
  Resolves a bonus-drop key to the family it stores into and the kind of gate
  its third argument names: `:race` for the slain mob's race, `:monster` for one
  specific monster id. Returns `:error` for every other key (any case).
  """
  @spec bonus3_drop_schema(String.t()) :: {:ok, {atom(), :race | :monster}} | :error
  def bonus3_drop_schema(name) when is_binary(name),
    do: Map.fetch(@bonus3_drop_keys, String.downcase(name))

  @doc """
  The deduplicated set of family atoms every recognized `bonus2` and
  flag-param key maps to.
  """
  @spec families() :: [atom()]
  def families do
    vanish_families = Enum.flat_map([@vanish_schemas, @race_vanish_schemas], &schema_families/1)

    (Map.values(@param_keys) ++ Map.values(@flag_param_keys))
    |> Enum.map(& &1.family)
    |> Kernel.++(Map.values(@interval_keys))
    |> Kernel.++(Map.values(@status_duration_families))
    |> Kernel.++(vanish_families)
    |> Kernel.++(@defender_proc_families)
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
    cond do
      family in Map.values(@interval_keys) ->
        {:ok, :interval}

      family in Map.values(@status_duration_families) ->
        {:ok, :status}

      family in schema_families(@vanish_schemas) ->
        {:ok, :battle}

      family in schema_families(@race_vanish_schemas) ->
        {:ok, :race}

      family in @defender_proc_families ->
        {:ok, :race}

      true ->
        (Map.values(@param_keys) ++ Map.values(@flag_param_keys))
        |> Enum.find(&(&1.family == family))
        |> case do
          %{param: param} -> {:ok, param}
          nil -> :error
        end
    end
  end

  defp schema_families(schemas),
    do: schemas |> Map.values() |> Enum.flat_map(&Map.values/1)
end
