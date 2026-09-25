defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.BerserkTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Berserk
  alias Aesir.ZoneServer.Mmo.StatusEffect.Helpers
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage

  setup :set_mimic_from_context
  setup :verify_on_exit!

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})
    Mimic.copy(Helpers)
    Mimic.copy(Interpreter)
    :ok
  end

  @tag game_mode: :renewal
  test "Renewal uses +200% ATK and +15 ASPD alongside the full Berserk modifier set" do
    assert Berserk.modifiers(%StatusEntry{}, %{}) ==
             Map.merge(shared_modifiers(), %{atk_rate: 200, aspd: 15})
  end

  @tag game_mode: :pre_renewal
  test "classic uses +100% ATK and +30% ASPD rate alongside the same defenses" do
    assert Berserk.modifiers(%StatusEntry{}, %{}) ==
             Map.merge(shared_modifiers(), %{atk_rate: 100, aspd_rate: 30})
  end

  test "on apply grants infinite Endure and queues full HP with zero SP" do
    expect(Interpreter, :apply_status, fn :player, 5, :sc_endure, params ->
      assert params[:val1] == 10
      assert params[:val4] == 1
      assert params[:caster_id] == 5
      assert params[:duration] == 300_000
      :ok
    end)

    expect(Helpers, :set_vitals, fn {:player, 5}, [hp: :max, sp: 0] -> :ok end)

    assert {:ok, %StatusEntry{state: %{penalty_armed: true}}} =
             Berserk.on_apply({:player, 5}, %StatusEntry{}, %{})
  end

  test "a drain that would kill removes Berserk without dealing damage" do
    reject(&Helpers.deal_damage/2)

    assert :remove =
             Berserk.on_tick({:player, 5}, %StatusEntry{}, %{target: %{hp: 100, max_hp: 3_000}})
  end

  test "a drain that reaches 100 or lower ends Berserk after charging" do
    expect(Helpers, :deal_damage, fn {:player, 5}, 150 -> :ok end)

    assert :remove =
             Berserk.on_tick({:player, 5}, %StatusEntry{}, %{target: %{hp: 240, max_hp: 3_000}})
  end

  test "a safe drain keeps Berserk active" do
    entry = %StatusEntry{}
    expect(Helpers, :deal_damage, fn {:player, 5}, 150 -> :ok end)

    assert {:ok, ^entry} =
             Berserk.on_tick({:player, 5}, entry, %{target: %{hp: 2_000, max_hp: 3_000}})
  end

  test "taking damage at 100 HP ends Berserk; damage above it does not" do
    entry = %StatusEntry{}
    assert :remove = Berserk.on_damage({:player, 5}, entry, %{}, %{target: %{hp: 100}})
    assert {:ok, ^entry} = Berserk.on_damage({:player, 5}, entry, %{}, %{target: %{hp: 101}})
  end

  test "natural expiry caps HP at 100 and removes only Berserk-owned Endure" do
    :ok = StatusStorage.apply_status(:player, 5, :sc_endure, val4: 1, duration: 300_000)
    expect(Helpers, :set_vitals, fn {:player, 5}, [hp: 100] -> :ok end)
    expect(Interpreter, :remove_status, fn :player, 5, :sc_endure -> :ok end)

    assert :ok =
             Berserk.on_expire(
               {:player, 5},
               %StatusEntry{state: %{penalty_armed: true}},
               %{target: %{hp: 2_000}}
             )
  end

  test "a disarmed penalty leaves HP unchanged but still removes Berserk-owned Endure" do
    :ok = StatusStorage.apply_status(:player, 5, :sc_endure, val4: 1, duration: 300_000)
    reject(&Helpers.set_vitals/2)
    expect(Interpreter, :remove_status, fn :player, 5, :sc_endure -> :ok end)

    assert :ok =
             Berserk.on_expire(
               {:player, 5},
               %StatusEntry{state: %{penalty_armed: false}},
               %{target: %{hp: 2_000}}
             )
  end

  test "expiry preserves an unrelated finite Endure" do
    :ok = StatusStorage.apply_status(:player, 5, :sc_endure, val4: 0, duration: 30_000)
    reject(&Helpers.set_vitals/2)
    reject(&Interpreter.remove_status/3)
    assert :ok = Berserk.on_expire({:player, 5}, %StatusEntry{}, %{target: %{hp: 100}})
    assert StatusStorage.has_status?(:player, 5, :sc_endure)
  end

  defp shared_modifiers do
    %{
      max_hp_rate: 200,
      flee_rate: -50,
      def_override: 0,
      mdef_override: 0,
      def2_rate: -100,
      mdef2_rate: -100,
      movement_speed: -25,
      hp_regen: -100,
      sp_regen: -100,
      skill_hp_regen_rate: -100,
      skill_sp_regen_rate: -100
    }
  end
end
