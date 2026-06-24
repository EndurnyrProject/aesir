defmodule Aesir.ZoneServer.Mmo.StatusEffect.InterpreterDisplayTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusEffect.StatusDisplay
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.UnitRegistry

  defmodule TickExpiringStatus do
    use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
      id: :sc_test_tick_expiring,
      properties: [:debuff],
      icon: :provoke

    @impl true
    def on_tick(_target, _instance, _context), do: :remove
  end

  defmodule AbsorbExpiringStatus do
    use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
      id: :sc_test_absorb_expiring,
      properties: [:buff],
      icon: :provoke

    @impl true
    def absorb_damage(_target, _instance, _hit_info, _context), do: :remove
  end

  defmodule DamageExpiringStatus do
    use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
      id: :sc_test_damage_expiring,
      properties: [:debuff],
      icon: :provoke

    @impl true
    def on_damage(_target, _instance, _damage_info, _context), do: :remove
  end

  defmodule VetoStatus do
    use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
      id: :sc_test_veto,
      properties: [:buff],
      icon: :provoke

    @impl true
    def on_apply(_target, _instance, _context), do: :remove
  end

  setup :set_mimic_from_context
  setup :verify_on_exit!
  setup :setup_ets_tables

  describe "apply hook" do
    test "a genuine apply calls StatusDisplay.on_applied with the stored instance" do
      target_id = 1
      test_pid = self()

      setup_unit_mock(target_id)
      Registry.register_module(TickExpiringStatus)
      Mimic.copy(StatusDisplay)

      stub(StatusDisplay, :on_applied, fn unit_type, unit_id, status_id, instance ->
        send(test_pid, {:on_applied, unit_type, unit_id, status_id, instance})
        :ok
      end)

      assert :ok =
               Interpreter.apply_status(:player, target_id, :sc_test_tick_expiring,
                 duration: 30_000
               )

      assert_received {:on_applied, :player, ^target_id, :sc_test_tick_expiring, instance}
      assert is_integer(instance.expires_at)
    end

    test "the on_apply :remove veto does not call StatusDisplay.on_applied" do
      target_id = 1

      setup_unit_mock(target_id)
      Registry.register_module(VetoStatus)
      Mimic.copy(StatusDisplay)

      reject(&StatusDisplay.on_applied/4)

      assert :ok = Interpreter.apply_status(:player, target_id, :sc_test_veto)
      refute StatusStorage.has_status?(:player, target_id, :sc_test_veto)
    end
  end

  describe "remove hook" do
    test "a manual remove_status calls StatusDisplay.on_removed with the removed instance" do
      target_id = 1
      test_pid = self()

      setup_unit_mock(target_id)
      Registry.register_module(TickExpiringStatus)
      Mimic.copy(StatusDisplay)
      stub(StatusDisplay, :on_applied, fn _, _, _, _ -> :ok end)

      stub(StatusDisplay, :on_removed, fn unit_type, unit_id, status_id, instance ->
        send(test_pid, {:on_removed, unit_type, unit_id, status_id, instance})
        :ok
      end)

      :ok = Interpreter.apply_status(:player, target_id, :sc_test_tick_expiring)
      :ok = Interpreter.remove_status(:player, target_id, :sc_test_tick_expiring)

      assert_received {:on_removed, :player, ^target_id, :sc_test_tick_expiring, instance}
      assert instance.type == :sc_test_tick_expiring
    end

    test "a tick-driven expiry calls StatusDisplay.on_removed" do
      target_id = 1
      test_pid = self()

      setup_unit_mock(target_id)
      Registry.register_module(TickExpiringStatus)
      Mimic.copy(StatusDisplay)
      stub(StatusDisplay, :on_applied, fn _, _, _, _ -> :ok end)

      stub(StatusDisplay, :on_removed, fn unit_type, unit_id, status_id, _instance ->
        send(test_pid, {:on_removed, unit_type, unit_id, status_id})
        :ok
      end)

      :ok = Interpreter.apply_status(:player, target_id, :sc_test_tick_expiring)
      :ok = Interpreter.process_tick(:player, target_id, :sc_test_tick_expiring)

      assert_received {:on_removed, :player, ^target_id, :sc_test_tick_expiring}
      refute StatusStorage.has_status?(:player, target_id, :sc_test_tick_expiring)
    end

    test "an on_damage :remove calls StatusDisplay.on_removed" do
      target_id = 1
      test_pid = self()

      setup_unit_mock(target_id)
      Registry.register_module(DamageExpiringStatus)
      Mimic.copy(StatusDisplay)
      stub(StatusDisplay, :on_applied, fn _, _, _, _ -> :ok end)

      stub(StatusDisplay, :on_removed, fn _, _, status_id, _ ->
        send(test_pid, {:on_removed, status_id})
        :ok
      end)

      :ok = Interpreter.apply_status(:player, target_id, :sc_test_damage_expiring)
      Interpreter.on_damage(:player, target_id, %{damage: 100, element: :neutral})

      assert_received {:on_removed, :sc_test_damage_expiring}
    end

    test "an absorb_damage :remove calls StatusDisplay.on_removed" do
      target_id = 1
      test_pid = self()

      setup_unit_mock(target_id)
      Registry.register_module(AbsorbExpiringStatus)
      Mimic.copy(StatusDisplay)
      stub(StatusDisplay, :on_applied, fn _, _, _, _ -> :ok end)

      stub(StatusDisplay, :on_removed, fn _, _, status_id, _ ->
        send(test_pid, {:on_removed, status_id})
        :ok
      end)

      :ok = Interpreter.apply_status(:player, target_id, :sc_test_absorb_expiring)
      Interpreter.absorb_damage(:player, target_id, 100, %{element: :neutral})

      assert_received {:on_removed, :sc_test_absorb_expiring}
    end
  end

  describe "mob path" do
    test "a mob status apply and tick-expiry emit the same display hooks" do
      mob_id = 500
      test_pid = self()

      setup_unit_mock(mob_id)
      Registry.register_module(TickExpiringStatus)
      Mimic.copy(StatusDisplay)

      stub(StatusDisplay, :on_applied, fn :mob, ^mob_id, status_id, _ ->
        send(test_pid, {:on_applied, status_id})
        :ok
      end)

      stub(StatusDisplay, :on_removed, fn :mob, ^mob_id, status_id, _ ->
        send(test_pid, {:on_removed, status_id})
        :ok
      end)

      :ok = Interpreter.apply_status(:mob, mob_id, :sc_test_tick_expiring)
      assert_received {:on_applied, :sc_test_tick_expiring}

      :ok = Interpreter.process_tick(:mob, mob_id, :sc_test_tick_expiring)
      assert_received {:on_removed, :sc_test_tick_expiring}
    end
  end

  describe "end-to-end through Broadcast (tick expiry)" do
    test "a tick-driven expiry broadcasts StatusChange{on: false}" do
      target_id = 1
      test_pid = self()

      setup_unit_mock(target_id)
      Registry.register_module(TickExpiringStatus)

      Mimic.copy(Aesir.ZoneServer.Unit.SpatialIndex)
      Mimic.copy(Aesir.ZoneServer.Unit.Broadcast)

      stub(Aesir.ZoneServer.Unit.SpatialIndex, :get_unit_position, fn _type, _id ->
        {:ok, {100, 100, "prontera"}}
      end)

      stub(Aesir.ZoneServer.Unit.Broadcast, :to_in_range, fn _map,
                                                             _x,
                                                             _y,
                                                             _range,
                                                             packet,
                                                             _opts ->
        send(test_pid, {:broadcast, packet})
        :ok
      end)

      :ok = Interpreter.apply_status(:player, target_id, :sc_test_tick_expiring)
      assert_received {:broadcast, %Aesir.Net.StatusChange{on: true}}

      :ok = Interpreter.process_tick(:player, target_id, :sc_test_tick_expiring)
      assert_received {:broadcast, %Aesir.Net.StatusChange{on: false}}
    end
  end

  defp setup_unit_mock(unit_id) do
    Mimic.copy(Aesir.ZoneServer.Mmo.StatusEffect.Resistance)
    Mimic.copy(UnitRegistry)

    stub(UnitRegistry, :get_unit_info, fn _unit_type, _unit_id ->
      {:ok,
       %{
         unit_id: unit_id,
         unit_type: :player,
         race: :human,
         element: :neutral,
         element_level: 1,
         boss_flag: false,
         size: :medium,
         stats: %{max_hp: 1000, max_sp: 100, hp: 800, sp: 80, level: 50, base_level: 50}
       }}
    end)

    stub(Aesir.ZoneServer.Mmo.StatusEffect.Resistance, :roll_success, fn _ -> true end)
  end
end
