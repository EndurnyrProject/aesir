defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.AutoberserkTest do
  @moduledoc false
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Autoberserk
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_from_context
  setup :verify_on_exit!
  setup :setup_ets_tables

  setup do
    Mimic.copy(UnitRegistry)
    Mimic.copy(Aesir.ZoneServer.Mmo.StatusEffect.Resistance)

    stub(UnitRegistry, :get_unit_info, fn _unit_type, unit_id ->
      {:ok,
       %{
         unit_id: unit_id,
         unit_type: :player,
         race: :human,
         element: :neutral,
         element_level: 1,
         boss_flag: false,
         size: :medium,
         stats: %{
           max_hp: 1_000,
           max_sp: 100,
           hp: 800,
           sp: 80,
           level: 50,
           base_level: 50,
           str: 10,
           agi: 10,
           vit: 10,
           int: 10,
           dex: 10,
           luk: 10,
           mdef: 5
         }
       }}
    end)

    stub(Aesir.ZoneServer.Mmo.StatusEffect.Resistance, :roll_success, fn _ -> true end)

    :ok
  end

  describe "id/0" do
    test "returns :sc_autoberserk" do
      assert Autoberserk.id() == :sc_autoberserk
    end
  end

  describe "on_damage/4 — follow-up SC_PROVOKE when below 25% HP" do
    test "requests sc_provoke follow-up when hp_after drops below 25% of max_hp" do
      unit_id = 1
      :ok = Interpreter.apply_status(:player, unit_id, :sc_autoberserk)

      damage_info = %{damage: 800, element: :neutral, hp_after: 200, max_hp: 1_000}

      Interpreter.on_damage(:player, unit_id, damage_info)

      assert StatusStorage.has_status?(:player, unit_id, :sc_provoke)
    end

    test "does not request sc_provoke when hp_after is exactly 25% of max_hp" do
      unit_id = 2
      :ok = Interpreter.apply_status(:player, unit_id, :sc_autoberserk)

      damage_info = %{damage: 250, element: :neutral, hp_after: 250, max_hp: 1_000}

      Interpreter.on_damage(:player, unit_id, damage_info)

      refute StatusStorage.has_status?(:player, unit_id, :sc_provoke)
    end

    test "does not request sc_provoke when hp_after is above 25% of max_hp" do
      unit_id = 3
      :ok = Interpreter.apply_status(:player, unit_id, :sc_autoberserk)

      damage_info = %{damage: 100, element: :neutral, hp_after: 600, max_hp: 1_000}

      Interpreter.on_damage(:player, unit_id, damage_info)

      refute StatusStorage.has_status?(:player, unit_id, :sc_provoke)
    end

    test "does not double-apply sc_provoke when already provoked" do
      unit_id = 4

      :ok = Interpreter.apply_status(:player, unit_id, :sc_autoberserk)
      :ok = Interpreter.apply_status(:player, unit_id, :sc_provoke, val1: 10, val2: 32, val3: 55)

      assert StatusStorage.has_status?(:player, unit_id, :sc_provoke)

      damage_info = %{damage: 800, element: :neutral, hp_after: 200, max_hp: 1_000}

      Interpreter.on_damage(:player, unit_id, damage_info)

      assert StatusStorage.has_status?(:player, unit_id, :sc_provoke)
    end
  end
end
