defmodule Aesir.ZoneServer.Mmo.StatusEffect.DispelTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.StatusEffect.Dispel
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusEffect.StatusDisplay
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.UnitRegistry

  defmodule ExpireReportingStatus do
    use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
      id: :sc_test_dispel_expire,
      no_dispel: false,
      properties: [:buff],
      icon: :provoke

    @impl true
    def on_expire({unit_type, unit_id}, %{state: %{test_pid: test_pid}}, _context) do
      send(test_pid, {:on_expire, unit_type, unit_id})
      :ok
    end
  end

  setup :verify_on_exit!
  setup :set_mimic_from_context
  setup :setup_ets_tables

  setup do
    Mimic.copy(UnitRegistry)

    stub(UnitRegistry, :get_unit_info, fn unit_type, unit_id ->
      {:ok,
       %{
         unit_id: unit_id,
         unit_type: unit_type,
         race: :human,
         element: :neutral,
         element_level: 1,
         boss_flag: false,
         size: :medium,
         stats: %{max_hp: 1000, max_sp: 500, current_hp: 1000, current_sp: 500}
       }}
    end)

    stub(UnitRegistry, :get_unit, fn _unit_type, _unit_id -> {:error, :not_found} end)

    Interpreter.init()

    {:ok, unit_id: :rand.uniform(100_000)}
  end

  describe "dispel/1" do
    test "removes a dispellable buff", %{unit_id: unit_id} do
      StatusStorage.apply_status(:player, unit_id, :sc_blessing, val1: 10, duration: 60_000)

      Dispel.dispel({:player, unit_id})

      refute StatusStorage.has_status?(:player, unit_id, :sc_blessing)
    end

    # rAthena's Dispell iterates all of status_db and skips only SCF_NODISPELL
    # entries - there is no buff/debuff distinction. Do not "fix" this test to
    # spare debuffs. See src/map/skills/mage/dispell.cpp:46-71.
    test "removes debuffs too", %{unit_id: unit_id} do
      StatusStorage.apply_status(:player, unit_id, :sc_poison, val1: 1, duration: 60_000)
      StatusStorage.apply_status(:player, unit_id, :sc_blind, val1: 1, duration: 60_000)

      Dispel.dispel({:player, unit_id})

      refute StatusStorage.has_status?(:player, unit_id, :sc_poison)
      refute StatusStorage.has_status?(:player, unit_id, :sc_blind)
    end

    test "leaves no_dispel statuses alone", %{unit_id: unit_id} do
      StatusStorage.apply_status(:player, unit_id, :sc_hiding, val1: 1, duration: 60_000)
      StatusStorage.apply_status(:player, unit_id, :sc_poembragi, val1: 1, duration: 60_000)

      Dispel.dispel({:player, unit_id})

      assert StatusStorage.has_status?(:player, unit_id, :sc_hiding)
      assert StatusStorage.has_status?(:player, unit_id, :sc_poembragi)
    end

    # The removal must go through the interpreter, never a bulk ETS delete:
    # on_expire, the icon delta and calc-flag recomputation all hang off it.
    test "runs each status's on_expire and icon removal", %{unit_id: unit_id} do
      test_pid = self()
      Registry.register_module(ExpireReportingStatus)
      Mimic.copy(StatusDisplay)

      stub(StatusDisplay, :on_removed, fn unit_type, id, status_id, _instance ->
        send(test_pid, {:on_removed, unit_type, id, status_id})
        :ok
      end)

      StatusStorage.apply_status(:player, unit_id, :sc_test_dispel_expire,
        duration: 60_000,
        state: %{test_pid: test_pid}
      )

      Dispel.dispel({:player, unit_id})

      assert_received {:on_expire, :player, ^unit_id}
      assert_received {:on_removed, :player, ^unit_id, :sc_test_dispel_expire}
      refute StatusStorage.has_status?(:player, unit_id, :sc_test_dispel_expire)
    end
  end

  describe "dispel/1 on a mob" do
    # rAthena's mob_unlocktarget: a dispelled mob forgets its aggro and idles.
    test "drops the mob's aggro target", %{unit_id: unit_id} do
      test_pid = self()
      stub(UnitRegistry, :get_unit, fn :mob, _id -> {:ok, {MobStub, %{}, test_pid}} end)

      StatusStorage.apply_status(:mob, unit_id, :sc_blessing, val1: 10, duration: 60_000)

      Dispel.dispel({:mob, unit_id})

      assert_received {:"$gen_cast", {:ai, {:set_target, nil}}}
      refute StatusStorage.has_status?(:mob, unit_id, :sc_blessing)
    end

    test "is a no-op for a mob that has already despawned", %{unit_id: unit_id} do
      stub(UnitRegistry, :get_unit, fn :mob, _id -> {:error, :not_found} end)

      assert :ok = Dispel.dispel({:mob, unit_id})
    end
  end

  describe "dispel/1 on a player" do
    test "never touches the mob aggro path", %{unit_id: unit_id} do
      reject(&UnitRegistry.get_unit/2)

      assert :ok = Dispel.dispel({:player, unit_id})
    end
  end
end
