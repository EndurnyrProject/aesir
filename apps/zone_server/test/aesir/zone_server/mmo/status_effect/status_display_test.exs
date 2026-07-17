defmodule Aesir.ZoneServer.Mmo.StatusEffect.StatusDisplayTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog
  import Mimic

  alias Aesir.Net.StatusChange
  alias Aesir.Net.UnitStateChange
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusEffect.StatusDisplay
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.SpecialEffect

  setup :verify_on_exit!

  defp definition(overrides) do
    Map.merge(
      %{
        icon: nil,
        opt1: nil,
        opt2: nil,
        option: nil,
        opt3: nil,
        on_apply_effect: nil
      },
      Map.new(overrides)
    )
  end

  defp timed_instance(type, overrides \\ []) do
    now_mono = System.monotonic_time(:millisecond)

    base = %StatusEntry{
      type: type,
      val1: 0,
      val2: 0,
      val3: 0,
      val4: 0,
      tick: 0,
      flag: 0,
      source_id: 1,
      state: %{},
      phase: nil,
      started_at: now_mono,
      expires_at: now_mono + 30_000,
      next_tick_at: now_mono + 1_000,
      tick_count: 0
    }

    struct(base, overrides)
  end

  defp stub_position do
    stub(SpatialIndex, :get_unit_position, fn _type, _id ->
      {:ok, {100, 100, "prontera"}}
    end)
  end

  describe "on_applied/4 icon broadcast" do
    test "broadcasts StatusChange{on: true} with non-zero timers and vals for an icon status" do
      test_pid = self()
      stub_position()

      instance = timed_instance(:sc_provoke, val1: 5, val2: 6, val3: 7)

      stub(Registry, :get_definition, fn :sc_provoke -> definition(icon: :provoke) end)

      stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, packet, _opts ->
        send(test_pid, {:broadcast, packet})
        :ok
      end)

      reject(&SpecialEffect.play/3)

      StatusDisplay.on_applied(:player, 2_000, :sc_provoke, instance)

      assert_received {:broadcast,
                       %StatusChange{
                         unit_id: 2_000,
                         efst: 0,
                         on: true,
                         val1: 5,
                         val2: 6,
                         val3: 7,
                         total_ms: total_ms,
                         remain_ms: remain_ms
                       }}

      assert total_ms > 0
      assert remain_ms > 0
    end

    test "permanent (expires_at nil) status sends total_ms and remain_ms of 0" do
      test_pid = self()
      stub_position()

      instance = timed_instance(:sc_provoke, expires_at: nil)

      stub(Registry, :get_definition, fn :sc_provoke -> definition(icon: :provoke) end)

      stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, packet, _opts ->
        send(test_pid, {:broadcast, packet})
        :ok
      end)

      StatusDisplay.on_applied(:player, 2_000, :sc_provoke, instance)

      assert_received {:broadcast, %StatusChange{on: true, total_ms: 0, remain_ms: 0}}
    end

    test "an icon-only buff emits no UnitStateChange" do
      stub_position()

      instance = timed_instance(:sc_provoke)

      stub(Registry, :get_definition, fn :sc_provoke -> definition(icon: :provoke) end)

      stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, %StatusChange{}, _opts -> :ok end)

      StatusDisplay.on_applied(:player, 2_000, :sc_provoke, instance)
    end

    test "a nil-resolving icon atom broadcasts no StatusChange and logs a warning" do
      stub_position()

      instance = timed_instance(:sc_provoke)

      stub(Registry, :get_definition, fn :sc_provoke ->
        definition(icon: :definitely_not_an_efst)
      end)

      reject(&Broadcast.to_in_range/6)

      log =
        capture_log(fn ->
          assert :ok = StatusDisplay.on_applied(:player, 2_000, :sc_provoke, instance)
        end)

      assert log =~ "definitely_not_an_efst"
    end
  end

  describe "on_applied/4 opt aggregate broadcast" do
    test "an opt-bearing status broadcasts a UnitStateChange with the resolved bit" do
      test_pid = self()
      stub_position()

      instance = timed_instance(:sc_poison)

      stub(Registry, :get_definition, fn
        :sc_poison -> definition(opt2: :poison)
      end)

      stub(StatusStorage, :get_unit_statuses, fn :mob, 50 -> [instance] end)

      stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, packet, _opts ->
        send(test_pid, {:broadcast, packet})
        :ok
      end)

      StatusDisplay.on_applied(:mob, 50, :sc_poison, instance)

      assert_received {:broadcast, %UnitStateChange{unit_id: 50, health_state: 1, body_state: 0}}
    end
  end

  describe "on_applied/4 on_apply_effect" do
    test "fires Unit.SpecialEffect.play/3 when on_apply_effect is set" do
      test_pid = self()
      stub_position()

      instance = timed_instance(:sc_provoke)

      stub(Registry, :get_definition, fn :sc_provoke ->
        definition(on_apply_effect: :hit1)
      end)

      stub(SpecialEffect, :play, fn source_unit, effect_atom, target ->
        send(test_pid, {:effect, source_unit, effect_atom, target})
        :ok
      end)

      StatusDisplay.on_applied(:player, 2_000, :sc_provoke, instance)

      assert_received {:effect, {:player, 2_000}, :hit1, :area}
    end
  end

  describe "on_removed/4" do
    test "broadcasts StatusChange{on: false} for an icon status" do
      test_pid = self()
      stub_position()

      instance = timed_instance(:sc_provoke)

      stub(Registry, :get_definition, fn :sc_provoke -> definition(icon: :provoke) end)

      stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, packet, _opts ->
        send(test_pid, {:broadcast, packet})
        :ok
      end)

      StatusDisplay.on_removed(:player, 2_000, :sc_provoke, instance)

      assert_received {:broadcast, %StatusChange{unit_id: 2_000, efst: 0, on: false}}
    end

    test "recomputes the aggregate from storage (post-removal) for an opt status" do
      test_pid = self()
      stub_position()

      instance = timed_instance(:sc_poison)

      stub(Registry, :get_definition, fn
        :sc_poison -> definition(opt2: :poison)
      end)

      stub(StatusStorage, :get_unit_statuses, fn :mob, 50 -> [] end)

      stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, packet, _opts ->
        send(test_pid, {:broadcast, packet})
        :ok
      end)

      StatusDisplay.on_removed(:mob, 50, :sc_poison, instance)

      assert_received {:broadcast, %UnitStateChange{unit_id: 50, health_state: 0}}
    end
  end

  describe "spawn_state/2 aggregation" do
    test "OR's opt2 bits across multiple active statuses" do
      poison = timed_instance(:sc_poison)
      curse = timed_instance(:sc_curse)

      stub(StatusStorage, :get_unit_statuses, fn :player, 3 -> [poison, curse] end)

      stub(Registry, :get_definition, fn
        :sc_poison -> definition(opt2: :poison)
        :sc_curse -> definition(opt2: :curse)
      end)

      assert %{health_state: 3, body_state: 0, effect_state: 0, virtue: 0} =
               StatusDisplay.spawn_state(:player, 3)
    end

    test "opt1 returns the single active ailment" do
      stone = timed_instance(:sc_stone)

      stub(StatusStorage, :get_unit_statuses, fn :player, 3 -> [stone] end)

      stub(Registry, :get_definition, fn :sc_stone -> definition(opt1: :stone) end)

      assert %{body_state: 1, health_state: 0} = StatusDisplay.spawn_state(:player, 3)
    end

    test "no opt-bearing status yields an all-zero aggregate" do
      buff = timed_instance(:sc_provoke)

      stub(StatusStorage, :get_unit_statuses, fn :player, 3 -> [buff] end)

      stub(Registry, :get_definition, fn :sc_provoke -> definition(icon: :provoke) end)

      assert %{body_state: 0, health_state: 0, effect_state: 0, virtue: 0} =
               StatusDisplay.spawn_state(:player, 3)
    end
  end

  describe "spawn_state/2 dynamic_option" do
    test "ORs the cart sprite bit derived from the live instance into effect_state" do
      cart = timed_instance(:sc_push_cart, val2: 2)

      stub(StatusStorage, :get_unit_statuses, fn :player, 3 -> [cart] end)

      stub(Registry, :get_definition, fn
        :sc_push_cart -> definition(module: Effects.PushCart)
      end)

      assert %{effect_state: 128, body_state: 0, health_state: 0, virtue: 0} =
               StatusDisplay.spawn_state(:player, 3)
    end

    test "a tier-1 cart lights up the :cart1 bit" do
      cart = timed_instance(:sc_push_cart, val2: 1)

      stub(StatusStorage, :get_unit_statuses, fn :player, 3 -> [cart] end)

      stub(Registry, :get_definition, fn
        :sc_push_cart -> definition(module: Effects.PushCart)
      end)

      assert %{effect_state: 8} = StatusDisplay.spawn_state(:player, 3)
    end

    test "a status whose module has no dynamic_option leaves effect_state untouched" do
      poison = timed_instance(:sc_poison)

      stub(StatusStorage, :get_unit_statuses, fn :player, 3 -> [poison] end)

      stub(Registry, :get_definition, fn
        :sc_poison -> definition(module: Effects.Poison, opt2: :poison)
      end)

      assert %{effect_state: 0, health_state: 1} = StatusDisplay.spawn_state(:player, 3)
    end
  end

  describe "active_icons/2" do
    test "returns one StatusChange{on: true} per active icon-bearing status" do
      provoke = timed_instance(:sc_provoke)
      poison = timed_instance(:sc_poison)

      stub(StatusStorage, :get_unit_statuses, fn :player, 3 -> [provoke, poison] end)

      stub(Registry, :get_definition, fn
        :sc_provoke -> definition(icon: :provoke)
        :sc_poison -> definition(opt2: :poison)
      end)

      icons = StatusDisplay.active_icons(:player, 3)

      assert [%StatusChange{unit_id: 3, efst: 0, on: true}] = icons
    end

    test "excludes a status whose icon atom does not resolve" do
      provoke = timed_instance(:sc_provoke)
      bogus = timed_instance(:sc_bogus)

      stub(StatusStorage, :get_unit_statuses, fn :player, 3 -> [provoke, bogus] end)

      stub(Registry, :get_definition, fn
        :sc_provoke -> definition(icon: :provoke)
        :sc_bogus -> definition(icon: :definitely_not_an_efst)
      end)

      log =
        capture_log(fn ->
          assert [%StatusChange{unit_id: 3, efst: 0, on: true}] =
                   StatusDisplay.active_icons(:player, 3)
        end)

      assert log =~ "definitely_not_an_efst"
    end
  end
end
