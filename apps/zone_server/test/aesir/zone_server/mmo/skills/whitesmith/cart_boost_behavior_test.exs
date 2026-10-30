defmodule Aesir.ZoneServer.Mmo.Skills.Whitesmith.CartBoostBehaviorTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.GameMode
  alias Aesir.TestMob
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.Skill.Caster.Player
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Whitesmith.WsCartboost
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Mmo.StatusEffect.Resistance
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Mmo.WalkSpeed
  alias Aesir.ZoneServer.PlayerStateFixture
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Stats.CombatStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_private
  setup :setup_ets_tables

  setup do
    stub(Resistance, :roll_success, fn _ -> true end)
    stub(Resistance, :roll_rate, fn _ -> true end)
    caster = player(101)
    :ok = UnitRegistry.register_player(caster, self())
    %{caster: caster}
  end

  test "cart_boost_uses_strongest_haste" do
    assert :ok = apply_status(:sc_cartboost)
    modifiers = ModifierCalculator.get_all_modifiers(:player, 101)
    assert WalkSpeed.calculate(150, modifiers, %{}) == 120

    for {status, params, expected} <- [
          {:sc_windwalk, [val1: 5], 120},
          {:sc_windwalk, [val1: 15], 105},
          {:sc_increaseagi, [val1: 1, val2: 3], 112}
        ] do
      assert :ok = apply_status(status, params)
      modifiers = ModifierCalculator.get_all_modifiers(:player, 101)
      assert WalkSpeed.calculate(150, modifiers, %{}) == expected
      :ok = Interpreter.remove_status(:player, 101, status)
    end

    for inputs <- [%{item_speed: 10}, %{improve_dodge_haste: 10}] do
      assert WalkSpeed.calculate(150, modifiers, inputs) == 120
    end

    for inputs <- [%{item_speed: 30}, %{improve_dodge_haste: 30}] do
      assert WalkSpeed.calculate(150, modifiers, inputs) == 105
    end
  end

  test "decrease_agi_is_removed_without_granting_cart_boost" do
    assert :ok = apply_status(:sc_decreaseagi)
    assert :ok = apply_status(:sc_quagmire, val2: 5)
    assert :ok = apply_status(:sc_cartboost)
    refute StatusStorage.has_status?(:player, 101, :sc_decreaseagi)
    refute StatusStorage.has_status?(:player, 101, :sc_cartboost)
    assert StatusStorage.has_status?(:player, 101, :sc_quagmire)
  end

  test "quagmire_and_decrease_agi_remove_existing_cart_boost" do
    for status <- [:sc_quagmire, :sc_decreaseagi] do
      assert :ok = apply_status(:sc_cartboost)
      assert :ok = apply_status(status)
      refute StatusStorage.has_status?(:player, 101, :sc_cartboost)
      :ok = Interpreter.remove_status(:player, 101, status)
    end
  end

  test "dont_forget_me_prevents_cart_boost_only_in_classic" do
    :ok = StatusStorage.apply_status(:player, 101, :sc_dontforgetme, val1: 1)

    if GameMode.mode() == :renewal do
      assert :ok = apply_status(:sc_cartboost)
    else
      assert {:error, _reason} = apply_status(:sc_cartboost)
      refute StatusStorage.has_status?(:player, 101, :sc_cartboost)
    end
  end

  test "cart_required_before_cost_and_status_refusal_keeps_paid_caster", %{caster: caster} do
    {:ok, definition} = Catalog.by_id(387)
    without_cart = %{caster | cart_type: 0}
    assert {:error, :cart} = WsCartboost.begin_attempt(without_cart, :self, 1, definition)
    assert without_cart.stats.current_state.sp == 100
    assert {:ok, ^caster} = WsCartboost.begin_attempt(caster, :self, 1, definition)
    assert {:ok, prepared} = Player.cost(caster, WsCartboost, :self, definition, 1)
    {paid, _remaining} = Player.commit_primary(caster, prepared)
    assert :ok = apply_status(:sc_quagmire)
    assert {:ok, ^paid} = WsCartboost.cast(paid, :self, 1, definition)
    assert paid.stats.current_state.sp == 80
    refute StatusStorage.has_status?(:player, 101, :sc_cartboost)
  end

  test "mob_cart_boost_keeps_typed_recipient" do
    {:ok, definition} = Catalog.by_id(387)

    spawn = %MobSpawn{
      mob: 1_002,
      amount: 1,
      respawn_time: 5_000,
      spawn_area: %SpawnArea{x: 10, y: 10}
    }

    mob = MobState.new(201, TestMob.definition(), spawn, "prontera", 10, 10)
    before_ms = System.monotonic_time(:millisecond)
    assert :ok = WsCartboost.mob_cast(mob, {:unit, :player, 101}, 1, definition, %{})
    after_ms = System.monotonic_time(:millisecond)
    held = StatusStorage.get_status(:player, 101, :sc_cartboost)
    assert held.val1 == 1
    assert held.source_type == :mob
    assert held.source_id == 201
    assert held.expires_at >= before_ms + 60_000
    assert held.expires_at <= after_ms + 60_000

    :ok = UnitRegistry.register_unit(:mob, 201, MobState, mob, self())
    assert :ok = WsCartboost.mob_cast(mob, {:unit, :mob, 201}, 1, definition, %{})
    assert StatusStorage.get_status(:mob, 201, :sc_cartboost).source_type == :mob
    assert ModifierCalculator.get_all_modifiers(:mob, 201).haste_rate == 20
  end

  defp apply_status(status, params \\ []) do
    Interpreter.apply_status(
      :player,
      101,
      status,
      Keyword.merge([val1: 1, duration: 60_000, caster_id: 101, source_type: :player], params)
    )
  end

  defp player(id) do
    PlayerStateFixture.build(%{
      character_id: id,
      account_id: id,
      cart_type: 1,
      inventory: %{},
      stats: %{base_stats: %{vit: 0, luk: 0}, combat_stats: %CombatStats{}}
    })
  end
end
