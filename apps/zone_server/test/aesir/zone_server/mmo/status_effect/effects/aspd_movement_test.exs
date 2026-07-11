defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.AspdMovementTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Efst
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects
  alias Aesir.ZoneServer.Mmo.StatusEntry

  # {module, status id, expected modifier map for val1: 10, icon atom | nil}
  @aspd [
    {Effects.AspdPotion0, :sc_aspdpotion0, %{aspd: 10}, :atthaste_potion1},
    {Effects.AspdPotion1, :sc_aspdpotion1, %{aspd: 10}, :atthaste_potion2},
    {Effects.AspdPotion2, :sc_aspdpotion2, %{aspd: 10}, :atthaste_potion3},
    {Effects.AspdPotion3, :sc_aspdpotion3, %{aspd: 10}, :atthaste_infinity},
    {Effects.AtthasteCash, :sc_atthaste_cash, %{aspd_rate: 10}, :atthaste_cash},
    {Effects.Boost500, :sc_boost500, %{aspd_rate: 10}, :boost500},
    {Effects.ExtractSalamineJuice, :sc_extract_salamine_juice, %{aspd_rate: 10},
     :extract_salamine_juice},
    {Effects.SkfAspd, :sc_skf_aspd, %{aspd_rate: 10}, :skf_aspd}
  ]

  # Movement: positive movement_speed = slower (status_manager.ex). SPEEDUP is
  # faster => negates val1; SLOWDOWN is slower => keeps val1 positive.
  @movement [
    {Effects.Speedup0, :sc_speedup0, %{movement_speed: -10}, :movhaste_horse},
    {Effects.Speedup1, :sc_speedup1, %{movement_speed: -10}, :movhaste_potion},
    {Effects.Slowdown, :sc_slowdown, %{movement_speed: 10}, nil}
  ]

  @all @aspd ++ @movement

  @aspd_potion_ids [:sc_aspdpotion0, :sc_aspdpotion1, :sc_aspdpotion2, :sc_aspdpotion3]

  defp entry(type, val1), do: %StatusEntry{type: type, state: %{}, val1: val1}

  describe "modifiers/2" do
    for {module, type, map, _icon} <- @all do
      test "#{inspect(module)} emits #{inspect(map)} for val1: 10" do
        assert unquote(Macro.escape(map)) ==
                 unquote(module).modifiers(entry(unquote(type), 10), %{})
      end
    end

    test "Slowdown emits positive movement_speed, Speedup negative" do
      assert %{movement_speed: 100} == Effects.Slowdown.modifiers(entry(:sc_slowdown, 100), %{})
      assert %{movement_speed: -25} == Effects.Speedup0.modifiers(entry(:sc_speedup0, 25), %{})
      assert %{movement_speed: -50} == Effects.Speedup1.modifiers(entry(:sc_speedup1, 50), %{})
    end
  end

  describe "metadata" do
    for {module, type, _map, icon} <- @all do
      test "#{inspect(module)} has id #{type} and icon resolves via Efst" do
        meta = unquote(module).metadata()
        assert meta.id == unquote(type)
        assert meta.icon == unquote(icon)

        if unquote(icon), do: assert(is_integer(Efst.id(unquote(icon))))
      end
    end

    test "Slowdown is a debuff, all others buffs" do
      assert :debuff in Effects.Slowdown.metadata().properties

      for {module, _type, _map, _icon} <- @all -- [List.last(@movement)] do
        assert :buff in module.metadata().properties
      end
    end
  end

  describe "aspd potion mutual end_on_start" do
    for {module, type, _map, _icon} <- @aspd, type in @aspd_potion_ids do
      test "#{inspect(module)} ends the other three aspd potions" do
        ends = unquote(module).metadata().end_on_start
        assert Enum.sort(ends) == Enum.sort(@aspd_potion_ids -- [unquote(type)])
      end
    end
  end

  test "all modules are registered" do
    registered = Effects.all()

    for {module, _type, _map, _icon} <- @all do
      assert module in registered
    end
  end
end
