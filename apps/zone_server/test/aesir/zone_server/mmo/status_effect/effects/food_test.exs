defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.FoodTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects
  alias Aesir.ZoneServer.Mmo.StatusEntry

  # {module, status id, modifier key} — each food grants a flat val1 bonus to one key.
  @foods [
    {Effects.StrFood, :sc_strfood, :str},
    {Effects.AgiFood, :sc_agifood, :agi},
    {Effects.VitFood, :sc_vitfood, :vit},
    {Effects.IntFood, :sc_intfood, :int},
    {Effects.DexFood, :sc_dexfood, :dex},
    {Effects.LukFood, :sc_lukfood, :luk},
    {Effects.HitFood, :sc_hitfood, :hit},
    {Effects.FleeFood, :sc_fleefood, :flee},
    {Effects.CriFood, :sc_crifood, :critical},
    {Effects.BatkFood, :sc_batkfood, :atk},
    {Effects.MatkFood, :sc_matkfood, :matk},
    {Effects.WatkFood, :sc_watkfood, :watk}
  ]

  defp entry(type, val1), do: %StatusEntry{type: type, state: %{}, val1: val1}

  describe "modifiers/2" do
    for {module, type, key} <- @foods do
      test "#{inspect(module)} grants +val1 to #{key}" do
        assert %{unquote(key) => 10} ==
                 unquote(module).modifiers(entry(unquote(type), 10), %{})

        assert %{unquote(key) => 3} ==
                 unquote(module).modifiers(entry(unquote(type), 3), %{})
      end
    end
  end

  describe "metadata" do
    for {module, type, key} <- @foods do
      test "#{inspect(module)} is a buff with the right id and calc flag" do
        meta = unquote(module).metadata()
        assert meta.id == unquote(type)
        assert :buff in meta.properties
        assert unquote(key) in meta.calc_flags
      end
    end
  end

  test "all food effects are registered" do
    registered = Effects.all()

    for {module, _type, _key} <- @foods do
      assert module in registered
    end
  end
end
