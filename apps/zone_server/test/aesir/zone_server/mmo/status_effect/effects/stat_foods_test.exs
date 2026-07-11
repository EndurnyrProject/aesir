defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.StatFoodsTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Efst
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects
  alias Aesir.ZoneServer.Mmo.StatusEntry

  # {module, status id, modifier key, icon atom (nil = none), end_on_start list}
  @stat_foods [
    {Effects.IncStr, :sc_incstr, :str, nil, []},
    {Effects.IncInt, :sc_incint, :int, nil, []},
    {Effects.IncDex, :sc_incdex, :dex, nil, []},
    {Effects.IncLuk, :sc_incluk, :luk, nil, []},
    {Effects.StrScroll, :sc_str_scroll, :str, :str_scroll, []},
    {Effects.IntScroll, :sc_int_scroll, :int, :int_scroll, []},
    {Effects.FoodStrCash, :sc_food_str_cash, :str, :food_str_cash, [:sc_strfood]},
    {Effects.FoodAgiCash, :sc_food_agi_cash, :agi, :food_agi_cash, [:sc_agifood]},
    {Effects.FoodVitCash, :sc_food_vit_cash, :vit, :food_vit_cash, [:sc_vitfood]},
    {Effects.FoodIntCash, :sc_food_int_cash, :int, :food_int_cash, [:sc_intfood]},
    {Effects.FoodDexCash, :sc_food_dex_cash, :dex, :food_dex_cash, [:sc_dexfood]},
    {Effects.FoodLukCash, :sc_food_luk_cash, :luk, :food_luk_cash, [:sc_lukfood]}
  ]

  # Plain food <-> cash counterpart, symmetric end_on_start.
  @food_pairs [
    {Effects.StrFood, :sc_food_str_cash},
    {Effects.AgiFood, :sc_food_agi_cash},
    {Effects.VitFood, :sc_food_vit_cash},
    {Effects.IntFood, :sc_food_int_cash},
    {Effects.DexFood, :sc_food_dex_cash},
    {Effects.LukFood, :sc_food_luk_cash}
  ]

  defp entry(type, val1), do: %StatusEntry{type: type, state: %{}, val1: val1}

  describe "modifiers/2" do
    for {module, type, key, _icon, _eos} <- @stat_foods do
      test "#{inspect(module)} grants +val1 to #{key}" do
        assert %{unquote(key) => 7} ==
                 unquote(module).modifiers(entry(unquote(type), 7), %{})

        assert %{unquote(key) => 1} ==
                 unquote(module).modifiers(entry(unquote(type), 1), %{})
      end
    end
  end

  describe "metadata" do
    for {module, type, key, icon, eos} <- @stat_foods do
      test "#{inspect(module)} id/properties/calc_flags/end_on_start" do
        meta = unquote(module).metadata()
        assert meta.id == unquote(type)
        assert :buff in meta.properties
        assert unquote(key) in meta.calc_flags
        assert meta.end_on_start == unquote(eos)
      end

      if is_nil(icon) do
        test "#{inspect(module)} has no icon" do
          assert is_nil(unquote(module).metadata().icon)
        end
      else
        test "#{inspect(module)} icon #{icon} resolves via Mmo.Efst" do
          icon = unquote(module).metadata().icon
          assert icon == unquote(icon)
          assert is_integer(Efst.id(icon))
        end
      end
    end
  end

  describe "plain-food symmetry" do
    for {module, cash_id} <- @food_pairs do
      test "#{inspect(module)} lists #{cash_id} in end_on_start" do
        assert unquote(cash_id) in unquote(module).metadata().end_on_start
      end
    end
  end

  test "all stat-food effects are registered" do
    registered = Effects.all()

    for {module, _type, _key, _icon, _eos} <- @stat_foods do
      assert module in registered
    end
  end
end
