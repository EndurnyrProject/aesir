defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.CookedFoodsTest do
  use ExUnit.Case, async: true

  import Mimic

  alias Aesir.ZoneServer.Mmo.Efst
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects
  alias Aesir.ZoneServer.Mmo.StatusEffect.Helpers
  alias Aesir.ZoneServer.Mmo.StatusEntry

  setup :verify_on_exit!

  # {module, status id, modifier key, icon} — val1-driven single-key foods.
  @single_v1 [
    {Effects.SavageSteak, :sc_savage_steak, :str, :savage_steak},
    {Effects.MinorBbq, :sc_minor_bbq, :vit, :minor_bbq},
    {Effects.SiromaIceTea, :sc_siroma_ice_tea, :dex, :siroma_ice_tea},
    {Effects.DroceraHerbSteamed, :sc_drocera_herb_steamed, :agi, :drocera_herb_steamed},
    {Effects.PuttiTailsNoodles, :sc_putti_tails_noodles, :luk, :putti_tails_noodles},
    {Effects.CocktailWargBlood, :sc_cocktail_warg_blood, :int, :cocktail_warg_blood},
    {Effects.ExtractWhitePotionZ, :sc_extract_white_potion_z, :hp_regen, :extract_white_potion_z}
  ]

  # {module, status id, fixed map, icon} — magnitude hardcoded, val1 ignored.
  @fixed [
    {Effects.CupOfBoza, :sc_cup_of_boza, %{vit: 10}, :cup_of_boza},
    {Effects.PorkRibStew, :sc_pork_rib_stew, %{aspd_rate: 5, sp_cost_rate: -2}, :pork_rib_stew},
    {Effects.Mysticpowder, :sc_mysticpowder, %{flee: 20, luk: 10}, :mysticpowder},
    {Effects.SparkCandy, :sc_sparkcandy, %{atk: 20, aspd_rate: 25}, :steampack},
    {Effects.MagicCandy, :sc_magiccandy, %{matk: 30}, :magic_candy},
    {Effects.Rwc2011Scroll, :sc_2011rwc_scroll,
     %{
       atk: 30,
       matk: 30,
       aspd_rate: 5,
       max_hp_rate: -10,
       max_sp_rate: -10,
       varcast_rate: -5
     }, :"2011rwc_scroll"}
  ]

  # {module, status id, maluses, icon} — mixed val1 rate + fixed maluses.
  @combat_pills [
    {Effects.CombatPill, :sc_combat_pill, %{max_hp_rate: -3, max_sp_rate: -3}, :gm_battle},
    {Effects.CombatPill2, :sc_combat_pill2, %{max_hp_rate: -5, max_sp_rate: -5}, :gm_battle2}
  ]

  defp entry(type, val1), do: %StatusEntry{type: type, state: %{}, val1: val1}

  describe "val1-driven single-key foods" do
    for {module, type, key, _icon} <- @single_v1 do
      test "#{inspect(module)} grants +val1 to #{key}" do
        assert %{unquote(key) => 10} ==
                 unquote(module).modifiers(entry(unquote(type), 10), %{})

        assert %{unquote(key) => 3} ==
                 unquote(module).modifiers(entry(unquote(type), 3), %{})
      end
    end
  end

  describe "fixed-magnitude modules" do
    for {module, type, map, _icon} <- @fixed do
      test "#{inspect(module)} emits its literal map regardless of val1" do
        assert unquote(Macro.escape(map)) ==
                 unquote(module).modifiers(entry(unquote(type), 0), %{})

        assert unquote(Macro.escape(map)) ==
                 unquote(module).modifiers(entry(unquote(type), 99), %{})
      end
    end
  end

  describe "Vitalize Potion (val1-driven rates)" do
    test "adds val1 to both atk_rate and matk_rate" do
      assert %{atk_rate: 15, matk_rate: 15} ==
               Effects.VitalizePotion.modifiers(entry(:sc_vitalize_potion, 15), %{})
    end
  end

  describe "Combat Pill (mixed val1 rate + fixed malus)" do
    for {module, type, maluses, _icon} <- @combat_pills do
      test "#{inspect(module)} combines the val1 rate with the fixed maluses" do
        expected = Map.merge(%{atk_rate: 10, matk_rate: 10}, unquote(Macro.escape(maluses)))
        assert expected == unquote(module).modifiers(entry(unquote(type), 10), %{})
      end

      test "#{inspect(module)} keeps the fixed maluses at val1: 0" do
        expected = Map.merge(%{atk_rate: 0, matk_rate: 0}, unquote(Macro.escape(maluses)))
        assert expected == unquote(module).modifiers(entry(unquote(type), 0), %{})
      end
    end
  end

  describe "candy HP/SP drains (on_tick)" do
    test "SparkCandy drains 100 HP per tick" do
      target = {:player, 1000}
      expect(Helpers, :deal_damage, fn ^target, 100 -> :ok end)

      instance = entry(:sc_sparkcandy, 0)
      assert {:ok, ^instance} = Effects.SparkCandy.on_tick(target, instance, %{})
    end

    test "MagicCandy drains 90 SP per tick" do
      target = {:player, 1000}
      expect(Helpers, :consume_sp, fn ^target, 90 -> :ok end)

      instance = entry(:sc_magiccandy, 0)
      assert {:ok, ^instance} = Effects.MagicCandy.on_tick(target, instance, %{})
    end
  end

  describe "metadata and icons" do
    for {module, type, _detail, icon} <- @single_v1 ++ @fixed ++ @combat_pills do
      test "#{inspect(module)} is a buff with a resolvable icon" do
        meta = unquote(module).metadata()
        assert meta.id == unquote(type)
        assert :buff in meta.properties
        assert is_integer(Efst.id(unquote(icon)))
      end
    end

    test "VitalizePotion metadata and icon" do
      meta = Effects.VitalizePotion.metadata()
      assert meta.id == :sc_vitalize_potion
      assert :buff in meta.properties
      assert is_integer(Efst.id(:vitalize_potion))
    end

    test "candies tick every 10 seconds" do
      assert Effects.SparkCandy.metadata().tick_interval == 10_000
      assert Effects.MagicCandy.metadata().tick_interval == 10_000
    end
  end

  test "all cooked-food modules are registered" do
    registered = Effects.all()
    modules = for {module, _t, _d, _i} <- @single_v1 ++ @fixed ++ @combat_pills, do: module

    for module <- [Effects.VitalizePotion | modules] do
      assert module in registered
    end
  end
end
