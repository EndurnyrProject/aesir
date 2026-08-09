defmodule Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Resolver do
  @moduledoc """
  Maps rAthena script symbols to Aesir runtime values for the item-script
  transpiler.

  Statuses, elements, classes, races, sizes, mob classes and on-hit effects are
  resolved through hand-curated maps (the rAthena constant names do not line up
  with Aesir's internal atoms); skills and items delegate to the live
  `Skill.Catalog` / `ItemManagement.Items` registries.

  Every resolver returns `{:ok, value}` or `{:error, {:unknown_symbol, symbol}}`;
  the error feeds the transpiler's all-or-nothing rule (an item with any
  unresolvable symbol emits no `on_use`).
  """

  alias Aesir.ZoneServer.Mmo.EffectId
  alias Aesir.ZoneServer.Mmo.ItemManagement.Items
  alias Aesir.ZoneServer.Mmo.Skill.Catalog

  @typedoc "An unresolvable rAthena symbol, carried verbatim for the coverage report."
  @type error :: {:error, {:unknown_symbol, String.t()}}

  @statuses %{
    "SC_BLESSING" => :sc_blessing,
    "SC_INCAGI" => :sc_increaseagi,
    "SC_INCREASEAGI" => :sc_increaseagi,
    "SC_DECAGI" => :sc_decreaseagi,
    "SC_DECREASEAGI" => :sc_decreaseagi,
    "SC_ANGELUS" => :sc_angelus,
    "SC_CONCENTRATE" => :sc_concentrate,
    "SC_GLORIA" => :sc_gloria,
    "SC_KYRIE" => :sc_kyrie,
    "SC_MAGNIFICAT" => :sc_magnificat,
    "SC_IMPOSITIO" => :sc_impositio,
    "SC_SUFFRAGIUM" => :sc_suffragium,
    "SC_ASPERSIO" => :sc_aspersio,
    "SC_BENEDICTIO" => :sc_benedictio,
    "SC_AETERNA" => :sc_aeterna,
    "SC_SIGNUMCRUCIS" => :sc_signumcrucis,
    "SC_PNEUMA" => :sc_pneuma,
    "SC_RUWACH" => :sc_ruwach,
    "SC_SAFETYWALL" => :sc_safetywall,
    "SC_ENDURE" => :sc_endure,
    "SC_AUTOBERSERK" => :sc_autoberserk,
    "SC_ENERGYCOAT" => :sc_energycoat,
    "SC_TWOHANDQUICKEN" => :sc_twohandquicken,
    "SC_HIDING" => :sc_hiding,
    "SC_CLOAKING" => :sc_cloaking,
    "SC_QUAGMIRE" => :sc_quagmire,
    "SC_SIGHT" => :sc_sight,
    "SC_TRICKDEAD" => :sc_trickdead,
    "SC_POEMBRAGI" => :sc_poembragi,
    "SC_POISON" => :sc_poison,
    "SC_DPOISON" => :sc_dpoison,
    "SC_SLOWPOISON" => :sc_slowpoison,
    "SC_ENCPOISON" => :sc_encpoison,
    "SC_POISONREACT" => :sc_poisonreact,
    "SC_BLIND" => :sc_blind,
    "SC_CURSE" => :sc_curse,
    "SC_SILENCE" => :sc_silence,
    "SC_STUN" => :sc_stun,
    "SC_SLEEP" => :sc_sleep,
    "SC_FREEZE" => :sc_freeze,
    "SC_STONE" => :sc_stone,
    "SC_CONFUSION" => :sc_confusion,
    "SC_BLEEDING" => :sc_bleeding,
    "SC_STRFOOD" => :sc_strfood,
    "SC_AGIFOOD" => :sc_agifood,
    "SC_VITFOOD" => :sc_vitfood,
    "SC_INTFOOD" => :sc_intfood,
    "SC_DEXFOOD" => :sc_dexfood,
    "SC_LUKFOOD" => :sc_lukfood,
    "SC_HITFOOD" => :sc_hitfood,
    "SC_FLEEFOOD" => :sc_fleefood,
    "SC_CRIFOOD" => :sc_crifood,
    "SC_BATKFOOD" => :sc_batkfood,
    "SC_MATKFOOD" => :sc_matkfood,
    "SC_WATKFOOD" => :sc_watkfood,
    "SC_INCSTR" => :sc_incstr,
    "SC_INCINT" => :sc_incint,
    "SC_INCDEX" => :sc_incdex,
    "SC_INCLUK" => :sc_incluk,
    "SC_STR_SCROLL" => :sc_str_scroll,
    "SC_INT_SCROLL" => :sc_int_scroll,
    "SC_FOOD_STR_CASH" => :sc_food_str_cash,
    "SC_FOOD_AGI_CASH" => :sc_food_agi_cash,
    "SC_FOOD_VIT_CASH" => :sc_food_vit_cash,
    "SC_FOOD_INT_CASH" => :sc_food_int_cash,
    "SC_FOOD_DEX_CASH" => :sc_food_dex_cash,
    "SC_FOOD_LUK_CASH" => :sc_food_luk_cash,
    "SC_INCALLSTATUS" => :sc_incallstatus,
    "SC_ALMIGHTY" => :sc_almighty,
    "SC_ULTIMATECOOK" => :sc_ultimatecook,
    "SC_INFINITY_DRINK" => :sc_infinity_drink,
    "SC_ATKPOTION" => :sc_atkpotion,
    "SC_MATKPOTION" => :sc_matkpotion,
    "SC_INCCRI" => :sc_inccri,
    "SC_INCFLEE2" => :sc_incflee2,
    "SC_INCATKRATE" => :sc_incatkrate,
    "SC_INCMATKRATE" => :sc_incmatkrate,
    "SC_ADD_ATK_DAMAGE" => :sc_add_atk_damage,
    "SC_ADD_MATK_DAMAGE" => :sc_add_matk_damage,
    "SC_DEF_RATE" => :sc_def_rate,
    "SC_MDEF_RATE" => :sc_mdef_rate,
    "SC_MANA_PLUS" => :sc_mana_plus,
    "SC_INCREASE_MAXSP" => :sc_increase_maxsp,
    "SC_MUSTLE_M" => :sc_mustle_m,
    "SC_LIFE_FORCE_F" => :sc_life_force_f,
    "SC_FULL_SWING_K" => :sc_full_swing_k,
    "SC_ASPDPOTION0" => :sc_aspdpotion0,
    "SC_ASPDPOTION1" => :sc_aspdpotion1,
    "SC_ASPDPOTION2" => :sc_aspdpotion2,
    "SC_ASPDPOTION3" => :sc_aspdpotion3,
    "SC_ATTHASTE_CASH" => :sc_atthaste_cash,
    "SC_BOOST500" => :sc_boost500,
    "SC_EXTRACT_SALAMINE_JUICE" => :sc_extract_salamine_juice,
    "SC_SKF_ASPD" => :sc_skf_aspd,
    "SC_SPEEDUP0" => :sc_speedup0,
    "SC_SPEEDUP1" => :sc_speedup1,
    "SC_SLOWDOWN" => :sc_slowdown,
    "SC_SAVAGE_STEAK" => :sc_savage_steak,
    "SC_MINOR_BBQ" => :sc_minor_bbq,
    "SC_SIROMA_ICE_TEA" => :sc_siroma_ice_tea,
    "SC_DROCERA_HERB_STEAMED" => :sc_drocera_herb_steamed,
    "SC_PUTTI_TAILS_NOODLES" => :sc_putti_tails_noodles,
    "SC_COCKTAIL_WARG_BLOOD" => :sc_cocktail_warg_blood,
    "SC_CUP_OF_BOZA" => :sc_cup_of_boza,
    "SC_PORK_RIB_STEW" => :sc_pork_rib_stew,
    "SC_MYSTICPOWDER" => :sc_mysticpowder,
    "SC_SPARKCANDY" => :sc_sparkcandy,
    "SC_MAGICCANDY" => :sc_magiccandy,
    "SC_COMBAT_PILL" => :sc_combat_pill,
    "SC_COMBAT_PILL2" => :sc_combat_pill2,
    "SC_VITALIZE_POTION" => :sc_vitalize_potion,
    "SC_EXTRACT_WHITE_POTION_Z" => :sc_extract_white_potion_z,
    "SC_2011RWC_SCROLL" => :sc_2011rwc_scroll,
    "SC_EXPBOOST" => :sc_expboost,
    "SC_JEXPBOOST" => :sc_jexpboost,
    "SC_ITEMBOOST" => :sc_itemboost,
    "SC_LIFEINSURANCE" => :sc_lifeinsurance,
    "SC_INCHEALRATE" => :sc_inchealrate,
    "SC_SKF_CAST" => :sc_skf_cast,
    "SC_SPCOST_RATE" => :sc_spcost_rate,
    "SC_MENTAL_POTION" => :sc_mental_potion,
    "SC_BEEF_RIB_STEW" => :sc_beef_rib_stew
  }

  @elements %{
    "Ele_Fire" => :fire,
    "Ele_Water" => :water,
    "Ele_Wind" => :wind,
    "Ele_Earth" => :earth,
    "Ele_Holy" => :holy,
    "Ele_Dark" => :shadow,
    "Ele_Ghost" => :ghost,
    "Ele_Poison" => :poison,
    "Ele_Undead" => :undead,
    "Ele_Neutral" => :neutral,
    "Ele_All" => :all
  }

  @classes %{
    "Job_Novice" => :novice,
    "Job_Swordman" => :swordman,
    "Job_Mage" => :mage,
    "Job_Archer" => :archer,
    "Job_Acolyte" => :acolyte,
    "Job_Merchant" => :merchant,
    "Job_Thief" => :thief,
    "Job_Knight" => :knight,
    "Job_Priest" => :priest,
    "Job_Wizard" => :wizard,
    "Job_Blacksmith" => :blacksmith,
    "Job_Hunter" => :hunter,
    "Job_Assassin" => :assassin,
    "Job_Crusader" => :crusader,
    "Job_Monk" => :monk,
    "Job_Sage" => :sage,
    "Job_Rogue" => :rogue,
    "Job_Alchemist" => :alchemist,
    "Job_Bard" => :bard,
    "Job_Dancer" => :dancer,
    "Job_SuperNovice" => :super_novice,
    "Job_Super_Novice" => :super_novice,
    "Job_Gunslinger" => :gunslinger,
    "Job_Ninja" => :ninja,
    "Job_Taekwon" => :taekwon,
    "Job_Star_Gladiator" => :star_gladiator,
    "Job_Soul_Linker" => :soul_linker
  }

  @races %{
    "RC_Formless" => :formless,
    "RC_Undead" => :undead,
    "RC_Brute" => :brute,
    "RC_Plant" => :plant,
    "RC_Insect" => :insect,
    "RC_Fish" => :fish,
    "RC_Demon" => :demon,
    "RC_DemiHuman" => :demi_human,
    "RC_Angel" => :angel,
    "RC_Dragon" => :dragon,
    "RC_Player_Human" => :player_human,
    "RC_Player_Doram" => :player_doram,
    "RC_All" => :all,
    "RC_Boss" => {:class, :boss}
  }

  @sizes %{
    "Size_Small" => :small,
    "Size_Medium" => :medium,
    "Size_Large" => :large,
    "Size_All" => :all
  }

  @mob_classes %{
    "Class_Normal" => :normal,
    "Class_Boss" => :boss,
    "Class_All" => :all
  }

  # rAthena's `e_race2` monster-group enum (`bAddRace2`'s param). Keyed on the
  # downcased constant name because the corpus spells the same group both ways
  # (`RC2_BioLab` and `RC2_BIOLAB`, `RC2_Illusion_Vampire` and
  # `RC2_ILLUSION_VAMPIRE`); `resolve_race2/1` downcases before lookup. Groups
  # are opaque param atoms (no combatant carries a race2 yet), so the atom is
  # just the name minus its `rc2_` prefix.
  @race2 %{
    "rc2_goblin" => :goblin,
    "rc2_kobold" => :kobold,
    "rc2_orc" => :orc,
    "rc2_golem" => :golem,
    "rc2_guardian" => :guardian,
    "rc2_ninja" => :ninja,
    "rc2_gvg" => :gvg,
    "rc2_battlefield" => :battlefield,
    "rc2_treasure" => :treasure,
    "rc2_biolab" => :biolab,
    "rc2_manuk" => :manuk,
    "rc2_splendide" => :splendide,
    "rc2_scaraba" => :scaraba,
    "rc2_ogh_atk_def" => :ogh_atk_def,
    "rc2_ogh_hidden" => :ogh_hidden,
    "rc2_bio5_swordman_thief" => :bio5_swordman_thief,
    "rc2_bio5_acolyte_merchant" => :bio5_acolyte_merchant,
    "rc2_bio5_mage_archer" => :bio5_mage_archer,
    "rc2_bio5_mvp" => :bio5_mvp,
    "rc2_clocktower" => :clocktower,
    "rc2_thanatos" => :thanatos,
    "rc2_faceworm" => :faceworm,
    "rc2_hearthunter" => :hearthunter,
    "rc2_rockridge" => :rockridge,
    "rc2_werner_lab" => :werner_lab,
    "rc2_temple_demon" => :temple_demon,
    "rc2_illusion_vampire" => :illusion_vampire,
    "rc2_malangdo" => :malangdo,
    "rc2_ep172alpha" => :ep172alpha,
    "rc2_ep172beta" => :ep172beta,
    "rc2_ep172bath" => :ep172bath,
    "rc2_illusion_turtle" => :illusion_turtle,
    "rc2_rachel_sanctuary" => :rachel_sanctuary,
    "rc2_illusion_luanda" => :illusion_luanda,
    "rc2_illusion_frozen" => :illusion_frozen,
    "rc2_illusion_moonlight" => :illusion_moonlight,
    "rc2_ep16_def" => :ep16_def,
    "rc2_edda_arunafeltz" => :edda_arunafeltz,
    "rc2_lasagna" => :lasagna,
    "rc2_glast_heim_abyss" => :glast_heim_abyss,
    "rc2_destroyed_valkyrie_realm" => :destroyed_valkyrie_realm,
    "rc2_encroached_gephenia" => :encroached_gephenia
  }

  # rAthena's `readparam` character-parameter constants that the equip corpus
  # reads (`readparam(bStr)`), mapped to the stat atoms `EquipScript` feeds from
  # its `:stats` input. Only the six base stats and the six trait stats appear;
  # they downcase to the same atoms `BonusKeys` uses for the matching `bonus`
  # destinations. Keyed downcased because the corpus is consistent but a
  # case-insensitive lookup costs nothing.
  @stat_params %{
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
    "bcrt" => :crt
  }

  @effs %{
    "Eff_Stun" => :sc_stun,
    "Eff_Poison" => :sc_poison,
    "Eff_Freeze" => :sc_freeze,
    "Eff_Curse" => :sc_curse,
    "Eff_Silence" => :sc_silence,
    "Eff_Blind" => :sc_blind,
    "Eff_Sleep" => :sc_sleep,
    "Eff_Bleeding" => :sc_bleeding,
    "Eff_Confusion" => :sc_confusion,
    "Eff_Stone" => :sc_stone
  }

  @spec resolve_status(String.t()) :: {:ok, atom()} | error()
  def resolve_status(symbol) when is_binary(symbol), do: lookup(@statuses, symbol)

  @doc """
  Returns the full rAthena-symbol-to-status-atom map. Used by the
  resolver-completeness test to assert every resolved status has a registered
  `StatusEffect.Registry` definition (the same-commit rule guard).
  """
  @spec statuses() :: %{String.t() => atom()}
  def statuses, do: @statuses

  @spec resolve_element(String.t()) :: {:ok, atom()} | error()
  def resolve_element(symbol) when is_binary(symbol), do: lookup(@elements, symbol)

  @spec resolve_class(String.t()) :: {:ok, atom()} | error()
  def resolve_class(symbol) when is_binary(symbol), do: lookup(@classes, symbol)

  @doc """
  Resolves an rAthena `RC_*` race constant to its combat race atom
  (`Combat.RaceModifiers`'s type). `RC_Boss` is a sentinel: it does not name a
  race, it redirects race-family bonuses (`bAddRace`/`bSubRace`) to the class
  family, so it resolves to `{:class, :boss}` rather than a race atom.
  `RC_Player_Doram` resolves to `:player_doram` even though no Aesir unit
  carries that race yet: the bonus is inert at runtime (no combatant ever
  matches it) but the rest of the item's script still transpiles.
  """
  @spec resolve_race(String.t()) :: {:ok, atom() | {:class, :boss}} | error()
  def resolve_race(symbol) when is_binary(symbol), do: lookup(@races, symbol)

  @doc """
  Resolves an rAthena `Size_*` constant to its combat size atom
  (`Combat.SizeModifiers`'s type).
  """
  @spec resolve_size(String.t()) :: {:ok, atom()} | error()
  def resolve_size(symbol) when is_binary(symbol), do: lookup(@sizes, symbol)

  @doc """
  Resolves an rAthena mob-class `Class_*` constant (`bAddClass`/`bSubClass`'s
  param) to `:normal | :boss | :all`. `Class_Guardian` is deliberately absent
  - Aesir has no guardian mob class - so it resolves `:error`.
  """
  @spec resolve_mob_class(String.t()) :: {:ok, atom()} | error()
  def resolve_mob_class(symbol) when is_binary(symbol), do: lookup(@mob_classes, symbol)

  @doc """
  Resolves an rAthena `RC2_*` monster-group constant (`bAddRace2`'s param) to
  its group atom. Lookup is case-insensitive: the corpus spells the same group
  in several casings, so the symbol is downcased before lookup.
  """
  @spec resolve_race2(String.t()) :: {:ok, atom()} | error()
  def resolve_race2(symbol) when is_binary(symbol) do
    case Map.fetch(@race2, String.downcase(symbol)) do
      {:ok, value} -> {:ok, value}
      :error -> unknown(symbol)
    end
  end

  @doc """
  Returns the full rAthena-symbol-to-group-atom map for `RC2_*` constants,
  backing `BonusKeys.param_domain(:race2)`.
  """
  @spec race2s() :: %{String.t() => atom()}
  def race2s, do: @race2

  @doc """
  Resolves an rAthena `Eff_*` status-infliction constant (`bAddEff` /
  `bAddEffWhenHit` / `bResEff`'s param) to the `:sc_*` atom of an
  implemented, registered status. `Eff_*` names with no registered status
  effect module are deliberately absent and resolve `:error`.
  """
  @spec resolve_eff(String.t()) :: {:ok, atom()} | error()
  def resolve_eff(symbol) when is_binary(symbol), do: lookup(@effs, symbol)

  @doc """
  Resolves an rAthena `readparam` character-parameter constant (`bStr`, `bInt`,
  `bPow`, ...) to the stat atom `EquipScript` reads from its `:stats` input.
  Only the six base stats and six trait stats are supported; any other
  parameter (HP, weight, ...) resolves `:error`. Lookup is case-insensitive.
  """
  @spec resolve_stat_param(String.t()) :: {:ok, atom()} | error()
  def resolve_stat_param(symbol) when is_binary(symbol) do
    case Map.fetch(@stat_params, String.downcase(symbol)) do
      {:ok, value} -> {:ok, value}
      :error -> unknown(symbol)
    end
  end

  @doc """
  Returns the full `readparam`-constant-to-stat-atom map, backing the
  `EquipScript` validation vocabulary and the codegen tests.
  """
  @spec stat_params() :: %{String.t() => atom()}
  def stat_params, do: @stat_params

  @doc """
  Returns the full rAthena-symbol-to-status-atom map for `Eff_*` constants.
  Used by the resolver-completeness test to assert every resolved `Eff_*`
  entry has a registered `StatusEffect.Registry` definition (the same-commit
  rule guard).
  """
  @spec effs() :: %{String.t() => atom()}
  def effs, do: @effs

  @doc """
  Resolves an rAthena `EF_*` special-effect constant to its readable `:ef_*`
  atom (e.g. `"EF_HEAL2"` -> `:heal2`), the form the `specialeffect2` DSL op
  expects. Delegates the atom -> id validity check to the generated `EffectId`
  map so only effects the client actually knows resolve.
  """
  @spec resolve_effect(String.t()) :: {:ok, atom()} | error()
  def resolve_effect("EF_" <> _ = symbol) do
    Code.ensure_loaded(EffectId)

    with {:ok, atom} <- existing_atom(String.trim_leading(symbol, "EF_")),
         id when is_integer(id) <- EffectId.id(atom) do
      {:ok, atom}
    else
      _ -> unknown(symbol)
    end
  end

  def resolve_effect(symbol) when is_binary(symbol), do: unknown(symbol)

  @spec resolve_skill(String.t() | integer()) :: {:ok, integer()} | error()
  def resolve_skill(id) when is_integer(id) do
    case Catalog.by_id(id) do
      {:ok, %{id: skill_id}} -> {:ok, skill_id}
      :error -> unknown(Integer.to_string(id))
    end
  end

  def resolve_skill(symbol) when is_binary(symbol) do
    case Integer.parse(symbol) do
      {id, ""} -> resolve_skill(id)
      _ -> resolve_skill_name(symbol)
    end
  end

  @spec resolve_item(String.t() | integer()) :: {:ok, integer()} | error()
  def resolve_item(id) when is_integer(id) do
    case Items.by_id(id) do
      {:ok, %{id: item_id}} -> {:ok, item_id}
      :error -> unknown(Integer.to_string(id))
    end
  end

  def resolve_item(symbol) when is_binary(symbol) do
    case Integer.parse(symbol) do
      {id, ""} -> resolve_item(id)
      _ -> resolve_item_aegis(symbol)
    end
  end

  @spec resolve_skill_name(String.t()) :: {:ok, integer()} | error()
  defp resolve_skill_name(symbol) do
    # Building the catalog creates the skill-name atoms; without it
    # `existing_atom` fails for any skill no loaded module happens to
    # mention (mix-task context, where modules load lazily).
    _ = Catalog.all()

    with {:ok, name} <- existing_atom(symbol),
         {:ok, %{id: id}} <- Catalog.by_name(name) do
      {:ok, id}
    else
      _ -> unknown(symbol)
    end
  end

  @spec resolve_item_aegis(String.t()) :: {:ok, integer()} | error()
  defp resolve_item_aegis(symbol) do
    case Items.by_aegis(symbol) do
      {:ok, %{id: id}} -> {:ok, id}
      :error -> unknown(symbol)
    end
  end

  @spec existing_atom(String.t()) :: {:ok, atom()} | :error
  defp existing_atom(symbol) do
    {:ok, String.to_existing_atom(String.downcase(symbol))}
  rescue
    ArgumentError -> :error
  end

  @spec lookup(map(), String.t()) :: {:ok, term()} | error()
  defp lookup(table, symbol) do
    case Map.fetch(table, symbol) do
      {:ok, value} -> {:ok, value}
      :error -> unknown(symbol)
    end
  end

  @spec unknown(String.t()) :: error()
  defp unknown(symbol), do: {:error, {:unknown_symbol, symbol}}
end
