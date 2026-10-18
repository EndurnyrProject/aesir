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

  describe "permanent: true" do
    test "apply_status stores entry with nil expires_at" do
      unit_id = 10

      :ok = Interpreter.apply_status(:player, unit_id, :sc_autoberserk)

      assert %{expires_at: nil} = StatusStorage.get_status(:player, unit_id, :sc_autoberserk)
    end
  end

  test "its tick starts flagged infinite Provoke at the quarter-HP boundary and warp removes it" do
    :ok = Interpreter.apply_status(:player, 1, :sc_autoberserk)
    entry = StatusStorage.get_status(:player, 1, :sc_autoberserk)

    assert {:ok, ^entry} =
             Autoberserk.on_tick({:player, 1}, entry, %{target: %{hp: 250, max_hp: 1_000}})

    assert %{val1: 10, val2: 32, val3: 55, val4: 1, expires_at: nil} =
             StatusStorage.get_status(:player, 1, :sc_provoke)

    Interpreter.remove_on_map_change(:player, 1)
    refute StatusStorage.has_status?(:player, 1, :sc_provoke)
  end

  test "the next tick removes its own Provoke after healing, but not an ordinary Provoke" do
    :ok = Interpreter.apply_status(:player, 2, :sc_autoberserk)
    entry = StatusStorage.get_status(:player, 2, :sc_autoberserk)
    Autoberserk.on_tick({:player, 2}, entry, %{target: %{hp: 200, max_hp: 1_000}})
    assert StatusStorage.has_status?(:player, 2, :sc_provoke)
    Autoberserk.on_tick({:player, 2}, entry, %{target: %{hp: 251, max_hp: 1_000}})
    refute StatusStorage.has_status?(:player, 2, :sc_provoke)

    :ok = Interpreter.apply_status(:player, 2, :sc_provoke, val1: 5, val2: 17, val3: 30, val4: 0)
    Autoberserk.on_tick({:player, 2}, entry, %{target: %{hp: 600, max_hp: 1_000}})
    assert %{val4: 0} = StatusStorage.get_status(:player, 2, :sc_provoke)
  end

  test "ending Auto Berserk removes only the Provoke it created" do
    :ok = Interpreter.apply_status(:player, 3, :sc_autoberserk)
    entry = StatusStorage.get_status(:player, 3, :sc_autoberserk)
    Autoberserk.on_tick({:player, 3}, entry, %{target: %{hp: 200, max_hp: 1_000}})
    Interpreter.remove_status(:player, 3, :sc_autoberserk)
    refute StatusStorage.has_status?(:player, 3, :sc_provoke)
  end

  test "death ends infinite Auto Berserk and its own Provoke" do
    :ok = Interpreter.apply_status(:player, 5, :sc_autoberserk)
    entry = StatusStorage.get_status(:player, 5, :sc_autoberserk)
    Autoberserk.on_tick({:player, 5}, entry, %{target: %{hp: 200, max_hp: 1_000}})
    assert StatusStorage.has_status?(:player, 5, :sc_provoke)

    Interpreter.remove_on_death(:player, 5)
    refute StatusStorage.has_status?(:player, 5, :sc_autoberserk)
    refute StatusStorage.has_status?(:player, 5, :sc_provoke)
  end

  test "damage does not apply Provoke before the next status tick" do
    :ok = Interpreter.apply_status(:player, 4, :sc_autoberserk)
    Interpreter.on_damage(:player, 4, %{damage: 800, hp_after: 200, max_hp: 1_000})
    refute StatusStorage.has_status?(:player, 4, :sc_provoke)
  end
end
