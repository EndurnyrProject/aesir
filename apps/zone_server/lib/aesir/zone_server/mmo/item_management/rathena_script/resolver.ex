defmodule Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.CatalogNotLoadedError do
  @moduledoc "Raised when item or item-group resolution requires a cold runtime catalog."

  defexception [:message]
end

defmodule Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Resolver do
  @moduledoc """
  Maps rAthena script symbols to Aesir runtime values for the item-script
  transpiler.

  Statuses, elements, classes, races, sizes, mob classes and on-hit effects use
  curated maps. Skills use `Skill.Catalog`. Items and item groups use the
  process-local source catalogs installed by `with_source_catalogs/2`, or their
  loaded runtime catalogs outside that context. A cold runtime catalog raises
  `CatalogNotLoadedError`.

  Unknown symbols return `{:error, {:unknown_symbol, symbol}}`; the error feeds
  the transpiler's all-or-nothing rule.
  """

  alias Aesir.ZoneServer.Mmo.AutoTriggerFlag
  alias Aesir.ZoneServer.Mmo.BattleFlag
  alias Aesir.ZoneServer.Mmo.EffectId
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups
  alias Aesir.ZoneServer.Mmo.ItemManagement.Items
  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.CatalogNotLoadedError
  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Script.Rathena

  @typedoc "An unresolvable rAthena symbol, carried verbatim for the coverage report."
  @type error :: {:error, {:unknown_symbol, String.t()}}

  @typedoc "Process-local item and item-group indexes built from selected source rows."
  @type source_catalogs :: %{
          required(:items_by_id) => %{integer() => integer()},
          required(:items_by_aegis) => %{String.t() => integer()},
          required(:item_groups) => MapSet.t(String.t()),
          optional(:self_cast_skills) => MapSet.t(integer())
        }

  @source_catalogs_key {__MODULE__, :source_catalogs}

  @doc """
  Builds source indexes from selected item, item-group and, optionally, skill
  database rows. Skill rows index which skills an implicit autocast casts on
  its own wearer (see `self_cast_skill?/1`).
  """
  @spec source_catalogs([map()], [map()], [map()]) :: source_catalogs()
  def source_catalogs(item_rows, item_group_rows, skill_rows \\ []) do
    catalogs = %{
      items_by_id:
        Map.new(item_rows, fn row -> {Map.fetch!(row, "Id"), Map.fetch!(row, "Id")} end),
      items_by_aegis:
        Map.new(item_rows, fn row -> {Map.fetch!(row, "AegisName"), Map.fetch!(row, "Id")} end),
      item_groups: MapSet.new(item_group_rows, &source_group_key/1)
    }

    case skill_rows do
      [] -> catalogs
      rows -> Map.put(catalogs, :self_cast_skills, self_cast_skill_ids(rows))
    end
  end

  defp self_cast_skill_ids(rows) do
    for row <- rows, self_cast_row?(row), into: MapSet.new(), do: Map.fetch!(row, "Id")
  end

  defp self_cast_row?(%{"TargetType" => "Support"}), do: true

  defp self_cast_row?(%{"TargetType" => "Self"} = row),
    do: get_in(row, ["Flags", "NoTargetSelf"]) != true

  defp self_cast_row?(_row), do: false

  @self_cast_target_types [:self, :target_ally, :target_any, :target_resurrection]

  @doc """
  Whether an autocast whose script names no target casts `skill_id` on its own
  wearer: support skills, and self skills that may target their caster. Any
  other skill casts at the other party.

  Reads the source skill database when a source context carries skill rows,
  otherwise the runtime catalog's target type.
  """
  @spec self_cast_skill?(integer()) :: boolean()
  def self_cast_skill?(skill_id) when is_integer(skill_id) do
    case Process.get(@source_catalogs_key) do
      %{self_cast_skills: skills} ->
        MapSet.member?(skills, skill_id)

      _no_skill_rows ->
        match?(
          {:ok, %{target_type: type}} when type in @self_cast_target_types,
          Catalog.by_id(skill_id)
        )
    end
  end

  @doc """
  Runs `fun` with authoritative process-local source indexes.

  Calls are safely nested and the previous context is restored even when `fun`
  raises. Runtime catalogs are not consulted while a source context exists.
  """
  @spec with_source_catalogs(source_catalogs(), (-> result)) :: result when result: term()
  def with_source_catalogs(source_catalogs, fun)
      when is_map(source_catalogs) and is_function(fun, 0) do
    missing = make_ref()
    previous = Process.get(@source_catalogs_key, missing)
    Process.put(@source_catalogs_key, source_catalogs)

    try do
      fun.()
    after
      if previous == missing do
        Process.delete(@source_catalogs_key)
      else
        Process.put(@source_catalogs_key, previous)
      end
    end
  end

  @statuses %{
    "SC_PARTYFLEE" => :sc_partyflee,
    "SC_BLESSING" => :sc_blessing,
    "SC_CARTBOOST" => :sc_cartboost,
    "SC_MAXOVERTHRUST" => :sc_maxoverthrust,
    "SC_MELTDOWN" => :sc_meltdown,
    "SC_INCAGI" => :sc_incagi,
    "SC_INCVIT" => :sc_incvit,
    "SC_INCREASEAGI" => :sc_increaseagi,
    "SC_DECAGI" => :sc_decreaseagi,
    "SC_DECREASEAGI" => :sc_decreaseagi,
    "SC_ANGELUS" => :sc_angelus,
    "SC_ADRENALINE" => :sc_adrenaline,
    "SC_INTRAVISION" => :sc_intravision,
    "SC_CONCENTRATE" => :sc_concentrate,
    "SC_GLORIA" => :sc_gloria,
    "SC_KYRIE" => :sc_kyrie,
    "SC_ASSUMPTIO" => :sc_assumptio,
    "SC_MAGNIFICAT" => :sc_magnificat,
    "SC_IMPOSITIO" => :sc_impositio,
    "SC_SUFFRAGIUM" => :sc_suffragium,
    "SC_ASPERSIO" => :sc_aspersio,
    "SC_FIREWEAPON" => :sc_fireweapon,
    "SC_WATERWEAPON" => :sc_waterweapon,
    "SC_WINDWEAPON" => :sc_windweapon,
    "SC_EARTHWEAPON" => :sc_earthweapon,
    "SC_WINDWALK" => :sc_windwalk,
    "SC_ARMOR_ELEMENT_WATER" => :sc_armor_element_water,
    "SC_ARMOR_ELEMENT_EARTH" => :sc_armor_element_earth,
    "SC_ARMOR_ELEMENT_FIRE" => :sc_armor_element_fire,
    "SC_ARMOR_ELEMENT_WIND" => :sc_armor_element_wind,
    "SC_ARMOR_RESIST" => :sc_armor_resist,
    "SC_COMMONSC_RESIST" => :sc_commonsc_resist,
    "SC_MANU_ATK" => :sc_manu_atk,
    "SC_MANU_DEF" => :sc_manu_def,
    "SC_MANU_MATK" => :sc_manu_matk,
    "SC_SPL_ATK" => :sc_spl_atk,
    "SC_SPL_DEF" => :sc_spl_def,
    "SC_SPL_MATK" => :sc_spl_matk,
    "SC_VITATA_500" => :sc_vitata_500,
    "SC_S_LIFEPOTION" => :sc_s_lifepotion,
    "SC_L_LIFEPOTION" => :sc_l_lifepotion,
    "SC_ELEMENTALCHANGE" => :sc_elementalchange,
    "SC_ACARAJE" => :sc_acaraje,
    "SC_INCREASE_MAXHP" => :sc_increase_maxhp,
    "SC_PROMOTE_HEALTH_RESERCH" => :sc_promote_health_reserch,
    "SC_ENERGY_DRINK_RESERCH" => :sc_energy_drink_reserch,
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
    "SC_EDP" => :sc_edp,
    "SC_POISONREACT" => :sc_poisonreact,
    "SC_BLIND" => :sc_blind,
    "SC_CURSE" => :sc_curse,
    "SC_SILENCE" => :sc_silence,
    "SC_STUN" => :sc_stun,
    "SC_SLEEP" => :sc_sleep,
    "SC_FREEZE" => :sc_freeze,
    "SC_STONE" => :sc_stone,
    "SC_STONEWAIT" => :sc_stonewait,
    "SC_CONFUSION" => :sc_confusion,
    "SC_HALLUCINATION" => :sc_hallucination,
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
    "SC_WATK_ELEMENT" => :sc_watk_element,
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
    "SC_INCDEFRATE" => :sc_incdefrate,
    "SC_INCMHPRATE" => :sc_incmhprate,
    "SC_INCMSPRATE" => :sc_incmsprate,
    "SC_INCHIT" => :sc_inchit,
    "SC_INCHITRATE" => :sc_inchitrate,
    "SC_INCFLEE" => :sc_incflee,
    "SC_INCFLEERATE" => :sc_incfleerate,
    "SC_SCRESIST" => :sc_scresist,
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
    "SC_BEEF_RIB_STEW" => :sc_beef_rib_stew,
    "SC_SUMMER" => :sc_summer,
    "SC_STRANGELIGHTS" => :sc_strangelights,
    "SC_MOONSTAR" => :sc_moonstar,
    "SC_SUPER_STAR" => :sc_super_star,
    "SC_FSTONE" => :sc_fstone,
    "SC_DECORATION_OF_MUSIC" => :sc_decoration_of_music,
    "SC_HAT_EFFECT" => :sc_hat_effect,
    "SC_LJOSALFAR" => :sc_ljosalfar,
    "SC_MAPLE_FALLS" => :sc_maple_falls,
    "SC_MERMAID_LONGING" => :sc_mermaid_longing,
    "SC_TIME_ACCESSORY" => :sc_time_accessory
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

  @race_ids %{
    0 => :formless,
    1 => :undead,
    2 => :brute,
    3 => :plant,
    4 => :insect,
    5 => :fish,
    6 => :demon,
    7 => :demi_human,
    8 => :angel,
    9 => :dragon,
    10 => :player_human,
    11 => :player_doram,
    12 => :all
  }

  @sizes %{
    "Size_Small" => :small,
    "Size_Medium" => :medium,
    "Size_Large" => :large,
    "Size_All" => :all
  }

  @bounds %{
    "Bound_Account" => 1,
    "Bound_Char" => 4
  }

  @mob_classes %{
    "Class_Normal" => :normal,
    "Class_Boss" => :boss,
    "Class_Guardian" => :guardian,
    "Class_Battlefield" => :battlefield,
    "Class_All" => :all
  }

  # Battle-flag constants qualifying a bonus with the kind of attack that fires
  # it (`bonus3 bSubEle,Ele_Fire,3,BF_MAGIC`), and the on-hit status families'
  # trigger-flag variant (`bonus3 bAddEff,Eff_Stun,500,ATF_MAGIC`). Both tables
  # are keyed on the downcased script spelling of their constant module's
  # entries, so the numeric bits live in one place only. Scripts OR them
  # together; `EquipCodegen` folds the expression.
  @battle_flags Map.new(BattleFlag.ids(), fn {name, value} -> {"bf_#{name}", value} end)
  @trigger_flags Map.new(AutoTriggerFlag.ids(), fn {name, value} -> {"atf_#{name}", value} end)

  @race2_ids %{
    1 => :goblin,
    2 => :kobold,
    3 => :orc,
    4 => :golem,
    5 => :guardian,
    6 => :ninja,
    7 => :gvg,
    8 => :battlefield,
    9 => :treasure,
    10 => :biolab,
    11 => :manuk,
    12 => :splendide,
    13 => :scaraba,
    14 => :ogh_atk_def,
    15 => :ogh_hidden,
    16 => :bio5_swordman_thief,
    17 => :bio5_acolyte_merchant,
    18 => :bio5_mage_archer,
    19 => :bio5_mvp,
    20 => :clocktower,
    21 => :thanatos,
    22 => :faceworm,
    23 => :hearthunter,
    24 => :rockridge,
    25 => :werner_lab,
    26 => :temple_demon,
    27 => :illusion_vampire,
    28 => :malangdo,
    29 => :ep172alpha,
    30 => :ep172beta,
    31 => :ep172bath,
    32 => :illusion_turtle,
    33 => :rachel_sanctuary,
    34 => :illusion_luanda,
    35 => :illusion_frozen,
    36 => :illusion_moonlight,
    37 => :ep16_def,
    38 => :edda_arunafeltz,
    39 => :lasagna,
    40 => :glast_heim_abyss,
    41 => :destroyed_valkyrie_realm,
    42 => :encroached_gephenia
  }
  @race2 Map.new(@race2_ids, fn {_id, group} -> {"rc2_#{group}", group} end)

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
    "Eff_Stone" => :sc_stonewait
  }

  # Constants are case-insensitive; fold the indexes once while preserving
  # each unknown symbol's original spelling in errors.
  @elements_folded Map.new(@elements, fn {symbol, atom} -> {String.downcase(symbol), atom} end)
  @races_folded Map.new(@races, fn {symbol, atom} -> {String.downcase(symbol), atom} end)
  @statuses_folded Map.new(@statuses, fn {symbol, atom} -> {String.downcase(symbol), atom} end)

  @doc "Resolves a date selector, month, or weekday constant."
  @spec resolve_date_constant(String.t()) :: {:ok, integer()} | error()
  def resolve_date_constant(symbol) do
    case Rathena.date_constant(symbol) do
      {:ok, value} -> {:ok, value}
      :error -> unknown(symbol)
    end
  end

  @spec resolve_status(String.t()) :: {:ok, atom()} | error()
  def resolve_status(symbol) when is_binary(symbol) do
    case lookup(@statuses, symbol) do
      {:ok, _} = ok -> ok
      {:error, _} -> lookup_folded(@statuses_folded, symbol)
    end
  end

  @spec lookup_folded(map(), String.t()) :: {:ok, term()} | error()
  defp lookup_folded(table, symbol) do
    case Map.fetch(table, String.downcase(symbol)) do
      {:ok, atom} -> {:ok, atom}
      :error -> unknown(symbol)
    end
  end

  @doc """
  Returns the full rAthena-symbol-to-status-atom map. Used by the
  resolver-completeness test to assert every resolved status has a registered
  `StatusEffect.Registry` definition (the same-commit rule guard).
  """
  @spec statuses() :: %{String.t() => atom()}
  def statuses, do: @statuses

  @doc "Resolves an element constant case-insensitively."
  @spec resolve_element(String.t()) :: {:ok, atom()} | error()
  def resolve_element(symbol) when is_binary(symbol), do: lookup_folded(@elements_folded, symbol)

  @doc """
  Resolves an rAthena `Job_*` class constant to its job atom. The curated
  `@classes` map carries the legacy CamelCase aliases (`Job_SuperNovice`); any
  other `Job_*` name falls back to stripping the prefix, downcasing, and
  validating the result against the live job table (`Job_Lord_Knight` ->
  `:lord_knight`), so advanced/trans/expanded classes resolve without a
  hand-maintained entry each. Lookup is case-insensitive on the fallback path.
  """
  @spec resolve_class(String.t()) :: {:ok, atom()} | error()
  def resolve_class(symbol) when is_binary(symbol) do
    case lookup(@classes, symbol) do
      {:ok, _} = ok -> ok
      {:error, _} -> derive_class(symbol)
    end
  end

  @spec derive_class(String.t()) :: {:ok, atom()} | error()
  defp derive_class(symbol) do
    with %{"name" => name} <- Regex.named_captures(~r/^job_(?<name>.+)$/i, symbol),
         {:ok, atom} <- existing_atom(name),
         {:ok, _id} <- AvailableJobs.job_name_to_id(atom) do
      {:ok, atom}
    else
      _ -> unknown(symbol)
    end
  end

  @doc """
  Resolves a numeric race ID or an `RC_*` constant (case-insensitively) to its combat race atom
  (`Combat.RaceModifiers`'s type). `RC_Boss` is a sentinel: it does not name a
  race, it redirects race-family bonuses (`bAddRace`/`bSubRace`) to the class
  family, so it resolves to `{:class, :boss}` rather than a race atom.
  `RC_Player_Doram` resolves to `:player_doram` even though no Aesir unit
  carries that race yet: the bonus is inert at runtime (no combatant ever
  matches it) but the rest of the item's script still transpiles.
  """
  @spec resolve_race(String.t() | integer()) :: {:ok, atom() | {:class, :boss}} | error()
  def resolve_race(id) when is_integer(id) do
    case Map.fetch(@race_ids, id) do
      {:ok, race} -> {:ok, race}
      :error -> unknown(Integer.to_string(id))
    end
  end

  def resolve_race(symbol) when is_binary(symbol), do: lookup_folded(@races_folded, symbol)

  @doc """
  Resolves an rAthena `Size_*` constant to its combat size atom
  (`Combat.SizeModifiers`'s type).
  """
  @spec resolve_size(String.t()) :: {:ok, atom()} | error()
  def resolve_size(symbol) when is_binary(symbol), do: lookup(@sizes, symbol)

  @doc """
  Resolves an rAthena mob-class `Class_*` constant (`bAddClass`/`bSubClass`'s
  param) to `:normal | :boss | :guardian | :battlefield | :all`.
  """
  @spec resolve_mob_class(String.t()) :: {:ok, atom()} | error()
  def resolve_mob_class(symbol) when is_binary(symbol), do: lookup(@mob_classes, symbol)

  @doc """
  Resolves a numeric secondary-race ID or a case-insensitive `RC2_*` constant
  to the monster-group atom carried by combatants. `NONE` and `MAX` are not
  monster groups and do not resolve.
  """
  @spec resolve_race2(String.t() | integer()) :: {:ok, atom()} | error()
  def resolve_race2(id) when is_integer(id) do
    case Map.fetch(@race2_ids, id) do
      {:ok, group} -> {:ok, group}
      :error -> unknown(Integer.to_string(id))
    end
  end

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
  Resolves an rAthena `BF_*` battle-flag constant to its axis bit.

  These qualify a bonus with the kind of attack that triggers it; a script ORs
  several together and the codegen folds the expression into one mask.
  """
  @spec resolve_battle_flag(String.t()) :: {:ok, non_neg_integer()} | error()
  def resolve_battle_flag(symbol) when is_binary(symbol) do
    case Map.fetch(@battle_flags, String.downcase(symbol)) do
      {:ok, value} -> {:ok, value}
      :error -> unknown(symbol)
    end
  end

  @doc """
  Resolves an rAthena `ATF_*` trigger-flag constant, the on-hit status
  families' variant, to its axis bit.
  """
  @spec resolve_trigger_flag(String.t()) :: {:ok, non_neg_integer()} | error()
  def resolve_trigger_flag(symbol) when is_binary(symbol) do
    case Map.fetch(@trigger_flags, String.downcase(symbol)) do
      {:ok, value} -> {:ok, value}
      :error -> unknown(symbol)
    end
  end

  @doc """
  Resolves a bound type constant to its numeric value.
  """
  @spec resolve_bound(String.t()) :: {:ok, 1 | 4} | error()
  def resolve_bound(symbol) when is_binary(symbol), do: lookup(@bounds, symbol)

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

  @doc "Resolves an `IG_*` constant to a known item-group key."
  @spec resolve_item_group(String.t()) :: {:ok, atom()} | error()
  def resolve_item_group("IG_" <> group = symbol) when group != "" do
    group_key = String.downcase(group)

    case Process.get(@source_catalogs_key) do
      %{item_groups: groups} ->
        if MapSet.member?(groups, group_key),
          do: {:ok, String.to_atom(group_key)},
          else: unknown(symbol)

      nil ->
        ensure_catalog_loaded!(ItemGroups, "item-group", "IG_*")
        key = String.to_atom(group_key)

        case ItemGroups.fetch(key) do
          {:ok, _group} -> {:ok, key}
          :error -> unknown(symbol)
        end
    end
  end

  def resolve_item_group(symbol) when is_binary(symbol), do: unknown(symbol)

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
    case Process.get(@source_catalogs_key) do
      %{items_by_id: items} ->
        case Map.fetch(items, id) do
          {:ok, item_id} -> {:ok, item_id}
          :error -> unknown(Integer.to_string(id))
        end

      nil ->
        ensure_catalog_loaded!(Items, "item", "items")

        case Items.by_id(id) do
          {:ok, %{id: item_id}} -> {:ok, item_id}
          :error -> unknown(Integer.to_string(id))
        end
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
    case Process.get(@source_catalogs_key) do
      %{items_by_aegis: items} ->
        case Map.fetch(items, symbol) do
          {:ok, id} -> {:ok, id}
          :error -> unknown(symbol)
        end

      nil ->
        ensure_catalog_loaded!(Items, "item", "items")

        case Items.by_aegis(symbol) do
          {:ok, %{id: id}} -> {:ok, id}
          :error -> unknown(symbol)
        end
    end
  end

  defp source_group_key(row), do: row |> Map.fetch!("Group") |> String.downcase()

  defp ensure_catalog_loaded!(catalog, label, references) do
    unless catalog.loaded?() do
      raise CatalogNotLoadedError,
            "#{label} catalog is not loaded; call #{inspect(catalog)}.reload/0 before importing scripts that reference #{references}"
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
