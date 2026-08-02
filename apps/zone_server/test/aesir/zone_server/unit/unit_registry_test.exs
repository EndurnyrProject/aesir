defmodule Aesir.ZoneServer.Unit.UnitRegistryTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  # Mock module for testing
  defmodule MockEntity do
    @behaviour Aesir.ZoneServer.Unit

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
    def living?(state), do: state.hp > 0

    @impl true
    def corpse?(_state), do: false

    @impl true
    def get_process_pid(_state), do: nil

    @impl true
    def get_custom_immunities(_state), do: []
  end

  setup :verify_on_exit!
  setup :set_mimic_from_context
  setup :setup_ets_tables

  defp register_owned_mob(instance_id, owner_player_id, mob_id, dead? \\ false) do
    state =
      struct(MobState,
        instance_id: instance_id,
        owner_player_id: owner_player_id,
        mob_id: mob_id,
        is_dead: dead?
      )

    UnitRegistry.register_unit(:mob, instance_id, MobState, state, nil)
  end

  describe "count_living_owned_mobs/2" do
    test "filters by owner and mob class and reflects unregistering" do
      register_owned_mob(1, 42, 1002)
      register_owned_mob(2, 42, 1002)
      register_owned_mob(3, 43, 1002)
      register_owned_mob(4, 42, 1003)
      register_owned_mob(5, 42, 1002, true)

      assert UnitRegistry.count_living_owned_mobs(42, 1002) == 2

      UnitRegistry.unregister_unit(:mob, 1)
      assert UnitRegistry.count_living_owned_mobs(42, 1002) == 1
    end
  end

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

  describe "get_unit_info/2 equipment publish" do
    test "player entity info carries the equipment modifier slice" do
      state = player_state_with_equipment(%{{:res_eff, :sc_freeze} => 500})
      UnitRegistry.register_player(state, self())

      assert {:ok, info} = UnitRegistry.get_unit_info(:player, state.character_id)
      assert info.equip_modifiers == %{{:res_eff, :sc_freeze} => 500}
    end

    test "a stats recompute with new equipment refreshes the published slice" do
      state = player_state_with_equipment(%{{:res_eff, :sc_freeze} => 500})
      char_id = state.character_id
      UnitRegistry.register_player(state, self())

      recomputed = put_in(state.stats.modifiers.equipment, %{{:res_eff, :sc_stun} => 300})
      assert :ok = UnitRegistry.update_unit_state(:player, char_id, recomputed)

      assert {:ok, info} = UnitRegistry.get_unit_info(:player, char_id)
      assert info.equip_modifiers == %{{:res_eff, :sc_stun} => 300}
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

  defp player_state_with_equipment(equipment) do
    character = %Character{
      id: 5001,
      account_id: 500,
      name: "Publisher",
      last_map: "prontera",
      last_x: 50,
      last_y: 50,
      sex: "M",
      hair: 1,
      hair_color: 0,
      clothes_color: 0,
      head_mid: 0,
      head_bottom: 0,
      robe: 0,
      str: 1,
      agi: 1,
      vit: 1,
      int: 1,
      dex: 1,
      luk: 1,
      base_level: 1,
      job_level: 1,
      class: 0
    }

    state = PlayerState.new(character)
    put_in(state.stats.modifiers.equipment, equipment)
  end
end
