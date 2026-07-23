defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.TwoHandQuickenTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.TwoHandQuicken
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_from_context
  setup :verify_on_exit!
  setup :setup_ets_tables

  defp entry(val1, val2), do: %{val1: val1, val2: val2}

  describe "modifiers/2" do
    test "lv1: crit +30, hit +2, aspd flat 7" do
      assert %{aspd: 7, hit: 2, critical: 30} == TwoHandQuicken.modifiers(entry(1, 7), %{})
    end

    test "lv10: crit +120, hit +20, aspd flat 7" do
      assert %{aspd: 7, hit: 20, critical: 120} == TwoHandQuicken.modifiers(entry(10, 7), %{})
    end
  end

  describe "definition" do
    test "carries the two-handed sword weapon requirement" do
      assert %{require_weapon: [:two_handed_sword]} = Registry.get_definition(:sc_twohandquicken)
    end
  end

  describe "require_weapon integration" do
    defp setup_player_mock(char_id) do
      stub(UnitRegistry, :get_unit_info, fn :player, ^char_id ->
        {:ok,
         %{
           unit_id: char_id,
           unit_type: :player,
           race: :formless,
           element: :neutral,
           element_level: 1,
           boss_flag: false,
           size: :medium,
           stats: %{
             max_hp: 100,
             max_sp: 50,
             hp: 100,
             sp: 50,
             level: 1,
             base_level: 1,
             str: 1,
             agi: 1,
             vit: 1,
             int: 1,
             dex: 1,
             luk: 1,
             mdef: 0
           }
         }}
      end)
    end

    test "swapping to a one-handed weapon ends the status" do
      setup_player_mock(1)
      :ok = Interpreter.apply_status(:player, 1, :sc_twohandquicken, val1: 3, val2: 7)

      Interpreter.enforce_weapon_requirements(:player, 1, :one_handed_sword)

      refute StatusStorage.has_status?(:player, 1, :sc_twohandquicken)
    end

    test "keeping the two-handed sword equipped leaves the status active" do
      setup_player_mock(1)
      :ok = Interpreter.apply_status(:player, 1, :sc_twohandquicken, val1: 3, val2: 7)

      Interpreter.enforce_weapon_requirements(:player, 1, :two_handed_sword)

      assert StatusStorage.has_status?(:player, 1, :sc_twohandquicken)
    end
  end
end
