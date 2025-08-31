defmodule Aesir.ZoneServer.Unit.UnitRegistryTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Unit.UnitRegistry

  # Mock module for testing
  defmodule MockEntity do
    @behaviour Aesir.ZoneServer.Unit.Entity

    @impl true
    def get_entity_info(state) do
      %{
        id: state.id,
        type: :mock,
        hp: state.hp,
        max_hp: state.max_hp
      }
    end

    @impl true
    def get_unit_type(_state), do: :mock

    @impl true
    def get_unit_id(state), do: state.id

    @impl true
    def get_stats(_state) do
      %{
        str: 1,
        agi: 1,
        vit: 1,
        int: 1,
        dex: 1,
        luk: 1
      }
    end

    @impl true
    def get_element(_state), do: :neutral

    @impl true
    def get_race(_state), do: :formless

    @impl true
    def get_size(_state), do: :medium

    @impl true
    def is_boss?(_state), do: false

    @impl true
    def get_process_pid(_state), do: nil

    @impl true
    def get_custom_immunities(_state), do: []
  end

  setup :verify_on_exit!
  setup :set_mimic_from_context
  setup :setup_ets_tables

  describe "register_unit/5" do
    test "registers a unit successfully" do
      state = %{id: 1, hp: 100, max_hp: 100}
      assert :ok = UnitRegistry.register_unit(:player, 1, MockEntity, state, self())

      assert {:ok, {MockEntity, ^state, pid}} = UnitRegistry.get_unit(:player, 1)
      assert pid == self()
    end

    test "can register multiple units with different types" do
      state1 = %{id: 1, hp: 100, max_hp: 100}
      state2 = %{id: 2, hp: 200, max_hp: 200}

      assert :ok = UnitRegistry.register_unit(:player, 1, MockEntity, state1)
      assert :ok = UnitRegistry.register_unit(:mob, 2, MockEntity, state2)

      assert {:ok, {MockEntity, ^state1, nil}} = UnitRegistry.get_unit(:player, 1)
      assert {:ok, {MockEntity, ^state2, nil}} = UnitRegistry.get_unit(:mob, 2)
    end

    test "overwrites existing unit with same type and id" do
      old_state = %{id: 1, hp: 50, max_hp: 100}
      new_state = %{id: 1, hp: 100, max_hp: 100}

      assert :ok = UnitRegistry.register_unit(:player, 1, MockEntity, old_state)
      assert :ok = UnitRegistry.register_unit(:player, 1, MockEntity, new_state)

      assert {:ok, {MockEntity, ^new_state, nil}} = UnitRegistry.get_unit(:player, 1)
    end
  end

  describe "unregister_unit/2" do
    test "unregisters an existing unit" do
      state = %{id: 1, hp: 100, max_hp: 100}
      UnitRegistry.register_unit(:player, 1, MockEntity, state)

      assert :ok = UnitRegistry.unregister_unit(:player, 1)
      assert {:error, :not_found} = UnitRegistry.get_unit(:player, 1)
    end

    test "returns ok even if unit doesn't exist" do
      assert :ok = UnitRegistry.unregister_unit(:player, 999)
    end
  end

  describe "get_unit/2" do
    test "returns unit data when unit exists" do
      state = %{id: 1, hp: 100, max_hp: 100}
      UnitRegistry.register_unit(:player, 1, MockEntity, state, self())

      assert {:ok, {MockEntity, ^state, pid}} = UnitRegistry.get_unit(:player, 1)
      assert pid == self()
    end

    test "returns error when unit doesn't exist" do
      assert {:error, :not_found} = UnitRegistry.get_unit(:player, 999)
    end
  end

  describe "get_unit_info/2" do
    test "returns entity info when unit exists" do
      state = %{id: 1, hp: 75, max_hp: 100}
      UnitRegistry.register_unit(:player, 1, MockEntity, state)

      assert {:ok, info} = UnitRegistry.get_unit_info(:player, 1)
      assert info.id == 1
      assert info.type == :mock
      assert info.hp == 75
      assert info.max_hp == 100
    end

    test "returns error when unit doesn't exist" do
      assert {:error, :not_found} = UnitRegistry.get_unit_info(:player, 999)
    end
  end

  describe "update_unit_state/3" do
    test "updates state of existing unit" do
      old_state = %{id: 1, hp: 50, max_hp: 100}
      new_state = %{id: 1, hp: 75, max_hp: 100}

      UnitRegistry.register_unit(:player, 1, MockEntity, old_state, self())

      assert :ok = UnitRegistry.update_unit_state(:player, 1, new_state)
      assert {:ok, {MockEntity, ^new_state, pid}} = UnitRegistry.get_unit(:player, 1)
      assert pid == self()
    end

    test "returns error when unit doesn't exist" do
      assert {:error, :not_found} = UnitRegistry.update_unit_state(:player, 999, %{})
    end
  end

  describe "unit_exists?/2" do
    test "returns true when unit exists" do
      UnitRegistry.register_unit(:player, 1, MockEntity, %{})
      assert UnitRegistry.unit_exists?(:player, 1)
    end

    test "returns false when unit doesn't exist" do
      refute UnitRegistry.unit_exists?(:player, 999)
    end
  end

  describe "list_units_by_type/1" do
    test "returns list of unit ids for given type" do
      UnitRegistry.register_unit(:player, 1, MockEntity, %{})
      UnitRegistry.register_unit(:player, 2, MockEntity, %{})
      UnitRegistry.register_unit(:mob, 3, MockEntity, %{})

      player_ids = UnitRegistry.list_units_by_type(:player)
      assert 1 in player_ids
      assert 2 in player_ids
      assert length(player_ids) == 2

      mob_ids = UnitRegistry.list_units_by_type(:mob)
      assert mob_ids == [3]
    end

    test "returns empty list when no units of type exist" do
      assert UnitRegistry.list_units_by_type(:npc) == []
    end
  end

  describe "count_units_by_type/1" do
    test "returns count of units by type" do
      UnitRegistry.register_unit(:player, 1, MockEntity, %{})
      UnitRegistry.register_unit(:player, 2, MockEntity, %{})
      UnitRegistry.register_unit(:mob, 3, MockEntity, %{})

      assert UnitRegistry.count_units_by_type(:player) == 2
      assert UnitRegistry.count_units_by_type(:mob) == 1
      assert UnitRegistry.count_units_by_type(:npc) == 0
    end
  end

  describe "count_all_units/0" do
    test "returns total count of all units" do
      assert UnitRegistry.count_all_units() == 0

      UnitRegistry.register_unit(:player, 1, MockEntity, %{})
      UnitRegistry.register_unit(:player, 2, MockEntity, %{})
      UnitRegistry.register_unit(:mob, 3, MockEntity, %{})

      assert UnitRegistry.count_all_units() == 3
    end
  end

  describe "cleanup_units_for_pid/1" do
    test "removes all units associated with a specific pid" do
      pid = self()
      other_pid = spawn(fn -> :timer.sleep(1000) end)

      UnitRegistry.register_unit(:player, 1, MockEntity, %{}, pid)
      UnitRegistry.register_unit(:player, 2, MockEntity, %{}, other_pid)
      UnitRegistry.register_unit(:mob, 3, MockEntity, %{}, pid)

      assert :ok = UnitRegistry.cleanup_units_for_pid(pid)

      assert {:error, :not_found} = UnitRegistry.get_unit(:player, 1)
      assert {:ok, _} = UnitRegistry.get_unit(:player, 2)
      assert {:error, :not_found} = UnitRegistry.get_unit(:mob, 3)

      Process.exit(other_pid, :kill)
    end

    test "does nothing when no units match the pid" do
      UnitRegistry.register_unit(:player, 1, MockEntity, %{})

      assert :ok = UnitRegistry.cleanup_units_for_pid(self())
      assert {:ok, _} = UnitRegistry.get_unit(:player, 1)
    end
  end
end
