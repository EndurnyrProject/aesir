defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.MegaBuffsTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Efst
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects
  alias Aesir.ZoneServer.Mmo.StatusEntry

  @all_stats [:str, :agi, :vit, :int, :dex, :luk]

  # {module, status id, icon atom (nil = none), calc_flags, end_on_start}
  @modules [
    {Effects.IncAllStatus, :sc_incallstatus, nil, @all_stats, []},
    {Effects.Almighty, :sc_almighty, :almighty, [:atk, :matk], [:sc_ultimatecook]},
    {Effects.UltimateCook, :sc_ultimatecook, :ultimatecook, @all_stats ++ [:atk, :matk],
     [
       :sc_food_str_cash,
       :sc_food_agi_cash,
       :sc_food_vit_cash,
       :sc_food_int_cash,
       :sc_food_dex_cash,
       :sc_food_luk_cash,
       :sc_almighty
     ]},
    {Effects.InfinityDrink, :sc_infinity_drink, :infinity_drink, [:max_hp_rate, :max_sp_rate], []}
  ]

  defp entry(type, val1), do: %StatusEntry{type: type, state: %{}, val1: val1}

  describe "modifiers/2" do
    test "IncAllStatus grants +val1 to every base stat" do
      assert %{str: 5, agi: 5, vit: 5, int: 5, dex: 5, luk: 5} ==
               Effects.IncAllStatus.modifiers(entry(:sc_incallstatus, 5), %{})

      assert %{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1} ==
               Effects.IncAllStatus.modifiers(entry(:sc_incallstatus, 1), %{})
    end

    test "Almighty grants only atk/matk from val1 (not all-stats)" do
      assert %{atk: 12, matk: 12} == Effects.Almighty.modifiers(entry(:sc_almighty, 12), %{})
    end

    test "UltimateCook grants +val1 to every stat plus fixed +30 atk/matk" do
      assert %{str: 7, agi: 7, vit: 7, int: 7, dex: 7, luk: 7, atk: 30, matk: 30} ==
               Effects.UltimateCook.modifiers(entry(:sc_ultimatecook, 7), %{})
    end

    test "InfinityDrink emits the fixed max hp/sp rate regardless of val1" do
      assert %{max_hp_rate: 5, max_sp_rate: 5} ==
               Effects.InfinityDrink.modifiers(entry(:sc_infinity_drink, 0), %{})

      assert %{max_hp_rate: 5, max_sp_rate: 5} ==
               Effects.InfinityDrink.modifiers(entry(:sc_infinity_drink, 99), %{})
    end
  end

  describe "metadata" do
    for {module, type, _icon, calc_flags, eos} <- @modules do
      test "#{inspect(module)} id/properties/calc_flags/end_on_start" do
        meta = unquote(module).metadata()
        assert meta.id == unquote(type)
        assert :buff in meta.properties

        for flag <- unquote(calc_flags) do
          assert flag in meta.calc_flags
        end

        assert meta.end_on_start == unquote(eos)
      end
    end

    for {module, _type, icon, _calc_flags, _eos} <- @modules do
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

  test "all mega-buff effects are registered" do
    registered = Effects.all()

    for {module, _type, _icon, _calc_flags, _eos} <- @modules do
      assert module in registered
    end
  end
end
