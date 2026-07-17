defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.DiscoveryTestStub do
  @moduledoc """
  A status effect stub that deliberately sits inside the `Effects` namespace.

  It exists so `EffectsDiscoveryTest` can prove that discovery excludes modules
  compiled from test files, which is what keeps stub ids from colliding with
  real ones.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_test_discovery_stub,
    no_dispel: false,
    properties: [:buff]
end

defmodule Aesir.ZoneServer.Mmo.StatusEffect.EffectsDiscoveryTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.DiscoveryTestStub

  @effects_dir Path.join(
                 __DIR__,
                 "../../../../../lib/aesir/zone_server/mmo/status_effect/effects"
               )

  @frozen_ids [
    :sc_2011rwc_scroll,
    :sc_add_atk_damage,
    :sc_add_matk_damage,
    :sc_aeterna,
    :sc_agifood,
    :sc_almighty,
    :sc_angelus,
    :sc_arcane_charge,
    :sc_aspdpotion0,
    :sc_aspdpotion1,
    :sc_aspdpotion2,
    :sc_aspdpotion3,
    :sc_aspersio,
    :sc_atkpotion,
    :sc_atthaste_cash,
    :sc_autoberserk,
    :sc_batkfood,
    :sc_beef_rib_stew,
    :sc_benedictio,
    :sc_bleeding,
    :sc_blessing,
    :sc_blind,
    :sc_boost500,
    :sc_cloaking,
    :sc_cocktail_warg_blood,
    :sc_combat_pill,
    :sc_combat_pill2,
    :sc_concentrate,
    :sc_confusion,
    :sc_crifood,
    :sc_cup_of_boza,
    :sc_curse,
    :sc_decreaseagi,
    :sc_def_rate,
    :sc_dexfood,
    :sc_dpoison,
    :sc_drocera_herb_steamed,
    :sc_encpoison,
    :sc_endure,
    :sc_energycoat,
    :sc_expboost,
    :sc_extract_salamine_juice,
    :sc_extract_white_potion_z,
    :sc_fleefood,
    :sc_food_agi_cash,
    :sc_food_dex_cash,
    :sc_food_int_cash,
    :sc_food_luk_cash,
    :sc_food_str_cash,
    :sc_food_vit_cash,
    :sc_freeze,
    :sc_full_swing_k,
    :sc_gloria,
    :sc_hiding,
    :sc_hitfood,
    :sc_impositio,
    :sc_incallstatus,
    :sc_incatkrate,
    :sc_inccri,
    :sc_incdex,
    :sc_incflee2,
    :sc_inchealrate,
    :sc_incint,
    :sc_incluk,
    :sc_incmatkrate,
    :sc_increase_maxsp,
    :sc_increaseagi,
    :sc_incstr,
    :sc_infinity_drink,
    :sc_int_scroll,
    :sc_intfood,
    :sc_itemboost,
    :sc_jexpboost,
    :sc_kyrie,
    :sc_life_force_f,
    :sc_lifeinsurance,
    :sc_loud,
    :sc_lukfood,
    :sc_magiccandy,
    :sc_magnificat,
    :sc_mana_plus,
    :sc_matkfood,
    :sc_matkpotion,
    :sc_mdef_rate,
    :sc_mental_potion,
    :sc_minor_bbq,
    :sc_mustle_m,
    :sc_mysticpowder,
    :sc_pneuma,
    :sc_poembragi,
    :sc_poison,
    :sc_poisonreact,
    :sc_pork_rib_stew,
    :sc_provoke,
    :sc_push_cart,
    :sc_putti_tails_noodles,
    :sc_quagmire,
    :sc_ruwach,
    :sc_safetywall,
    :sc_savage_steak,
    :sc_sight,
    :sc_sightblaster,
    :sc_signumcrucis,
    :sc_silence,
    :sc_siroma_ice_tea,
    :sc_skf_aspd,
    :sc_skf_cast,
    :sc_sleep,
    :sc_slowdown,
    :sc_slowpoison,
    :sc_sparkcandy,
    :sc_spcost_rate,
    :sc_speedup0,
    :sc_speedup1,
    :sc_stone,
    :sc_str_scroll,
    :sc_strfood,
    :sc_stun,
    :sc_suffragium,
    :sc_trickdead,
    :sc_twohandquicken,
    :sc_ultimatecook,
    :sc_vitalize_potion,
    :sc_vitfood,
    :sc_watk_element,
    :sc_watkfood
  ]

  defp effect_modules_from_disk do
    @effects_dir
    |> Path.join("*.ex")
    |> Path.wildcard()
    |> Enum.map(fn path ->
      Module.concat(Effects, path |> Path.basename(".ex") |> Macro.camelize())
    end)
  end

  describe "all/0" do
    test "discovers exactly the modules backed by a file under effects/" do
      assert Enum.sort(Effects.all()) == Enum.sort(effect_modules_from_disk())
    end

    test "still discovers every status that existed before discovery replaced the list" do
      discovered = MapSet.new(Effects.all(), & &1.id())

      assert MapSet.subset?(MapSet.new(@frozen_ids), discovered),
             """
             Statuses present before the switch to runtime discovery have gone missing:
             #{inspect(MapSet.to_list(MapSet.difference(MapSet.new(@frozen_ids), discovered)))}

             Removing a status is a deliberate act — drop its id from @frozen_ids in the
             same change. Adding statuses never requires touching this list.
             """
    end

    test "every discovered module implements the Definition behaviour" do
      for module <- Effects.all() do
        assert function_exported?(module, :id, 0)
        assert function_exported?(module, :metadata, 0)
      end
    end

    test "status ids are unique" do
      ids = Enum.map(Effects.all(), & &1.id())

      assert Enum.uniq(ids) == ids
    end
  end

  describe "test stub exclusion" do
    test "a stub defined in a test file does not register, even inside the Effects namespace" do
      Code.ensure_loaded!(DiscoveryTestStub)

      refute DiscoveryTestStub in Effects.all()
      refute :sc_test_discovery_stub in Enum.map(Effects.all(), & &1.id())
    end

    test "stub ids defined by other test files do not register" do
      ids = Enum.map(Effects.all(), & &1.id())

      for stub_id <- [:sc_test_tick_expiring, :sc_test_permanent, :sc_registry_test, :sc_bad] do
        refute stub_id in ids
      end
    end
  end
end
