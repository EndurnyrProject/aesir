defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.CombatBuffsTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Efst
  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Resolver
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects
  alias Aesir.ZoneServer.Mmo.StatusEntry

  # {module, rAthena symbol, status id, icon atom (nil = none), calc_flags}
  @modules [
    {Effects.AtkPotion, "SC_ATKPOTION", :sc_atkpotion, :plusattackpower, [:atk]},
    {Effects.MatkPotion, "SC_MATKPOTION", :sc_matkpotion, :plusmagicpower, [:matk]},
    {Effects.IncCri, "SC_INCCRI", :sc_inccri, :criticalpercent, [:critical]},
    {Effects.IncFlee2, "SC_INCFLEE2", :sc_incflee2, :plusavoidvalue, [:perfect_dodge]},
    {Effects.IncAtkRate, "SC_INCATKRATE", :sc_incatkrate, nil, [:atk_rate]},
    {Effects.IncMatkRate, "SC_INCMATKRATE", :sc_incmatkrate, nil, [:matk_rate]},
    {Effects.AddAtkDamage, "SC_ADD_ATK_DAMAGE", :sc_add_atk_damage, :add_atk_damage, [:atk_rate]},
    {Effects.AddMatkDamage, "SC_ADD_MATK_DAMAGE", :sc_add_matk_damage, :add_matk_damage,
     [:matk_rate]},
    {Effects.DefRate, "SC_DEF_RATE", :sc_def_rate, :protect_def, [:phys_damage_reduction]},
    {Effects.MdefRate, "SC_MDEF_RATE", :sc_mdef_rate, :protect_mdef, [:magic_damage_reduction]},
    {Effects.ManaPlus, "SC_MANA_PLUS", :sc_mana_plus, :mana_plus, [:matk]},
    {Effects.IncreaseMaxSp, "SC_INCREASE_MAXSP", :sc_increase_maxsp, :atker_movespeed,
     [:max_sp_rate]},
    {Effects.MustleM, "SC_MUSTLE_M", :sc_mustle_m, :mustle_m, [:max_hp_rate]},
    {Effects.LifeForceF, "SC_LIFE_FORCE_F", :sc_life_force_f, :life_force_f, [:max_sp_rate]},
    {Effects.FullSwingK, "SC_FULL_SWING_K", :sc_full_swing_k, :full_swing_k, [:atk]}
  ]

  defp entry(type, val1), do: %StatusEntry{type: type, state: %{}, val1: val1}

  describe "modifiers/2" do
    test "flat atk / matk potions emit their key from val1" do
      assert %{atk: 20} == Effects.AtkPotion.modifiers(entry(:sc_atkpotion, 20), %{})
      assert %{matk: 15} == Effects.MatkPotion.modifiers(entry(:sc_matkpotion, 15), %{})
      assert %{matk: 8} == Effects.ManaPlus.modifiers(entry(:sc_mana_plus, 8), %{})
      assert %{atk: 30} == Effects.FullSwingK.modifiers(entry(:sc_full_swing_k, 30), %{})
    end

    test "SC_INCCRI maps val1 raw into Aesir's whole-percent critical stat" do
      assert %{critical: 7} == Effects.IncCri.modifiers(entry(:sc_inccri, 7), %{})
    end

    test "SC_INCFLEE2 scales val1 by 10 into Aesir's tenths-unit perfect_dodge stat" do
      assert %{perfect_dodge: 40} == Effects.IncFlee2.modifiers(entry(:sc_incflee2, 4), %{})
    end

    test "percent atk/matk rate buffs emit rate-delta keys" do
      assert %{atk_rate: 10} == Effects.IncAtkRate.modifiers(entry(:sc_incatkrate, 10), %{})
      assert %{matk_rate: 10} == Effects.IncMatkRate.modifiers(entry(:sc_incmatkrate, 10), %{})
      assert %{atk_rate: 5} == Effects.AddAtkDamage.modifiers(entry(:sc_add_atk_damage, 5), %{})

      assert %{matk_rate: 5} ==
               Effects.AddMatkDamage.modifiers(entry(:sc_add_matk_damage, 5), %{})
    end

    test "SC_DEF_RATE / SC_MDEF_RATE emit damage-reduction keys, not DEF/MDEF buffs" do
      phys = Effects.DefRate.modifiers(entry(:sc_def_rate, 30), %{})
      assert phys == %{phys_damage_reduction: 30}
      refute Map.has_key?(phys, :def)
      refute Map.has_key?(phys, :def_rate)

      magic = Effects.MdefRate.modifiers(entry(:sc_mdef_rate, 25), %{})
      assert magic == %{magic_damage_reduction: 25}
      refute Map.has_key?(magic, :mdef)
      refute Map.has_key?(magic, :mdef_rate)
    end

    test "max hp/sp rate buffs emit rate-delta keys from val1" do
      assert %{max_sp_rate: 5} ==
               Effects.IncreaseMaxSp.modifiers(entry(:sc_increase_maxsp, 5), %{})

      assert %{max_hp_rate: 10} == Effects.MustleM.modifiers(entry(:sc_mustle_m, 10), %{})
      assert %{max_sp_rate: 10} == Effects.LifeForceF.modifiers(entry(:sc_life_force_f, 10), %{})
    end
  end

  describe "metadata" do
    for {module, _symbol, type, _icon, calc_flags} <- @modules do
      test "#{inspect(module)} id / properties / calc_flags" do
        meta = unquote(module).metadata()
        assert meta.id == unquote(type)
        assert :buff in meta.properties

        for flag <- unquote(calc_flags) do
          assert flag in meta.calc_flags
        end
      end
    end

    for {module, _symbol, _type, icon, _calc_flags} <- @modules do
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

  describe "resolver + registration" do
    for {module, symbol, type, _icon, _calc_flags} <- @modules do
      test "#{symbol} resolves to #{type} and #{inspect(module)} is registered" do
        assert Resolver.resolve_status(unquote(symbol)) == {:ok, unquote(type)}
        assert unquote(module) in Effects.all()
      end
    end
  end
end
