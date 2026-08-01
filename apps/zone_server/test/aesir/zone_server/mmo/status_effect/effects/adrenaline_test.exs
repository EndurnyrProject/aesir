defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.AdrenalineTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Adrenaline
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Adrenaline2
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @adrenaline2_weapons [
    :fist,
    :dagger,
    :one_handed_sword,
    :two_handed_sword,
    :one_handed_spear,
    :two_handed_spear,
    :one_handed_axe,
    :two_handed_axe,
    :mace,
    :two_handed_mace,
    :staff,
    :knuckle,
    :musical,
    :whip,
    :book,
    :katar
  ]

  setup :set_mimic_from_context
  setup :verify_on_exit!
  setup :setup_ets_tables

  test "Adrenaline Rush grants flat ASPD and level-scaled HIT" do
    for {level, hit} <- Enum.zip(1..5, [8, 11, 14, 17, 20]) do
      assert %{aspd: 7, hit: hit} ==
               Adrenaline.modifiers(%StatusEntry{type: :sc_adrenaline, val1: level}, %{})
    end
  end

  test "Adrenaline Rush II grants flat ASPD" do
    for level <- [1, 5] do
      assert %{aspd: 6} ==
               Adrenaline2.modifiers(%StatusEntry{type: :sc_adrenaline2, val1: level}, %{})
    end
  end

  test "status definitions are discoverable with their calculation flags and weapon requirements" do
    assert %{id: :sc_adrenaline, calc_flags: [:aspd, :hit], icon: :adrenaline} =
             Adrenaline.metadata()

    assert %{require_weapon: [:one_handed_axe, :two_handed_axe, :mace]} =
             Adrenaline.metadata()

    assert %{id: :sc_adrenaline2, calc_flags: [:aspd], icon: :adrenaline2} =
             Adrenaline2.metadata()

    assert %{require_weapon: @adrenaline2_weapons} = Adrenaline2.metadata()

    for {status, id} <- [{Adrenaline, :sc_adrenaline}, {Adrenaline2, :sc_adrenaline2}] do
      assert status in Effects.all()
      :ok = Registry.register_module(status)
      assert %{module: ^status} = Registry.get_definition(id)
    end
  end

  test "Adrenaline statuses end when wielding a disallowed weapon" do
    stub_player()

    for {status, id, disallowed_weapon} <- [
          {Adrenaline, :sc_adrenaline, :dagger},
          {Adrenaline2, :sc_adrenaline2, :bow}
        ] do
      :ok = Registry.register_module(status)
      :ok = Interpreter.apply_status(:player, 1, id)

      Interpreter.enforce_weapon_requirements(:player, 1, disallowed_weapon)

      refute StatusStorage.has_status?(:player, 1, id)
    end
  end

  test "Adrenaline statuses survive a swap to an allowed weapon" do
    stub_player()

    for {status, id, allowed_weapon} <- [
          {Adrenaline, :sc_adrenaline, :mace},
          {Adrenaline2, :sc_adrenaline2, :katar}
        ] do
      :ok = Registry.register_module(status)
      :ok = Interpreter.apply_status(:player, 1, id)

      Interpreter.enforce_weapon_requirements(:player, 1, allowed_weapon)

      assert StatusStorage.has_status?(:player, 1, id)
    end
  end

  defp stub_player do
    stub(UnitRegistry, :get_unit_info, fn :player, 1 ->
      {:ok,
       %{
         unit_id: 1,
         unit_type: :player,
         race: :formless,
         element: :neutral,
         element_level: 1,
         boss_flag: false,
         size: :medium,
         stats: %{max_hp: 100, max_sp: 50, hp: 100, sp: 50, level: 1, base_level: 1}
       }}
    end)
  end
end
