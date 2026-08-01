defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.MaximizePowerTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.MaximizePower
  alias Aesir.ZoneServer.Mmo.StatusEffect.Helpers
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Resistance
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Mmo.StatusTickManager
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_from_context
  setup :verify_on_exit!
  setup :setup_ets_tables

  setup do
    Mimic.copy(Resistance)
    Mimic.copy(UnitRegistry)

    stub(Resistance, :roll_success, fn _ -> true end)

    stub(UnitRegistry, :get_unit_info, fn :player, player_id ->
      {:ok,
       %{
         unit_id: player_id,
         unit_type: :player,
         race: :human,
         element: :neutral,
         element_level: 1,
         boss_flag: false,
         size: :medium,
         stats: %{max_hp: 100, max_sp: 100, hp: 100, sp: 10}
       }}
    end)

    :ok
  end

  test "defines weapon maximization and base SP regen suppression" do
    entry = %StatusEntry{type: :sc_maximizepower, state: %{}}

    assert MaximizePower.id() == :sc_maximizepower
    assert MaximizePower.metadata().icon == :maximize
    assert MaximizePower.modifiers(entry, %{}) == %{max_weapon_damage: true, sp_regen: -100}
  end

  test "drains one SP when the tick can be paid" do
    entry = %StatusEntry{type: :sc_maximizepower, state: %{}}

    expect(Helpers, :consume_sp, fn {:player, 1}, 1 -> :ok end)

    assert MaximizePower.on_tick({:player, 1}, entry, %{target: %{sp: 1}}) == {:ok, entry}
  end

  test "removes itself without draining when SP is empty" do
    entry = %StatusEntry{type: :sc_maximizepower, state: %{}}

    reject(&Helpers.consume_sp/2)

    assert MaximizePower.on_tick({:player, 1}, entry, %{target: %{sp: 0}}) == :remove
  end

  test "process_tick removes the active status when SP is empty" do
    player_id = 1_000

    assert :ok =
             Interpreter.apply_status(:player, player_id, :sc_maximizepower,
               caster_id: player_id,
               tick: 1_000
             )

    stub(UnitRegistry, :get_unit_info, fn :player, ^player_id ->
      {:ok,
       %{
         unit_id: player_id,
         unit_type: :player,
         race: :human,
         element: :neutral,
         element_level: 1,
         boss_flag: false,
         size: :medium,
         stats: %{max_hp: 100, max_sp: 100, hp: 100, sp: 0}
       }}
    end)

    assert :ok = Interpreter.process_tick(:player, player_id, :sc_maximizepower)
    refute StatusStorage.has_status?(:player, player_id, :sc_maximizepower)
  end

  test "stores and schedules the caster-provided per-level tick interval" do
    now = System.monotonic_time(:millisecond)

    for {player_id, tick} <- [{1_001, 1_000}, {1_005, 5_000}] do
      assert :ok =
               Interpreter.apply_status(:player, player_id, :sc_maximizepower,
                 caster_id: player_id,
                 tick: tick
               )

      assert %StatusEntry{tick: ^tick, next_tick_at: next_tick_at} =
               StatusStorage.get_status(:player, player_id, :sc_maximizepower)

      assert Interpreter.get_all_modifiers(:player, player_id) == %{
               max_weapon_damage: true,
               sp_regen: -100
             }

      assert next_tick_at in (now + tick)..(System.monotonic_time(:millisecond) + tick)
    end
  end

  test "the scheduler drains at the stored interval and schedules the next tick from it" do
    player_id = 1_005
    test_pid = self()

    stub(UnitRegistry, :unit_exists?, fn :player, ^player_id -> true end)

    assert :ok =
             Interpreter.apply_status(:player, player_id, :sc_maximizepower,
               caster_id: player_id,
               tick: 5_000
             )

    stub(UnitRegistry, :get_unit, fn :player, ^player_id ->
      {:ok, {PlayerState, %{}, test_pid}}
    end)

    due_at = System.monotonic_time(:millisecond) - 1
    :ok = StatusStorage.update_next_tick(:player, player_id, :sc_maximizepower, due_at)
    now = System.monotonic_time(:millisecond)

    assert {:noreply, %StatusTickManager.State{}} =
             StatusTickManager.handle_info(:tick, %StatusTickManager.State{})

    assert_receive {:"$gen_cast", {:unit, {:drain_sp, 1}}}

    assert %StatusEntry{tick: 5_000, next_tick_at: next_tick_at} =
             StatusStorage.get_status(:player, player_id, :sc_maximizepower)

    assert next_tick_at in (now + 5_000)..(System.monotonic_time(:millisecond) + 5_000)
  end

  test "never expires on a timer, because it is toggled off rather than timed out" do
    player_id = 82_411

    :ok = Interpreter.apply_status(:player, player_id, :sc_maximizepower, tick: 3_000)

    assert %StatusEntry{expires_at: nil, next_tick_at: next_tick_at} =
             StatusStorage.get_status(:player, player_id, :sc_maximizepower)

    refute is_nil(next_tick_at)
  end
end
