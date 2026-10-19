defmodule Aesir.ZoneServer.Unit.Mob.StatsHandlerTest do
  @moduledoc """
  Owner-side reconciliation of the calculated snapshot: which events select
  fields, the source consequences they carry, and the single publication each
  event produces.
  """

  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobMode
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.Handlers.StatsHandler
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Movement
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @map "stats_handler_map"
  @slave_modes [:can_move, :no_random_walk, :can_attack]

  setup :setup_ets_tables
  setup :set_mimic_private

  setup do
    :ets.insert(EtsTable.table_for(:map_cache), {@map, MapData.new(@map, 60, 60)})
    :ok
  end

  describe "handle_status_changed/3 selection" do
    test "a generic tick is not a calculated event" do
      state = register(mob_state())

      assert {:noreply, ^state} =
               StatsHandler.handle_status_changed(:sc_decreaseagi, :tick, state)
    end

    test "an unknown identity selects nothing" do
      state = register(mob_state())

      assert {:noreply, ^state} =
               StatsHandler.handle_status_changed(:sc_increase_agi, :apply, state)
    end

    test "a dead monster drops the event" do
      dead = %{register(mob_state()) | is_dead: true}

      assert {:noreply, ^dead} =
               StatsHandler.handle_status_changed(:sc_decreaseagi, :apply, dead)
    end
  end

  describe "ceiling consequence" do
    test "a lowered ceiling clamps HP once and a later raise never heals" do
      state = register(mob_state())
      :ok = StatusStorage.apply_status(:mob, state.instance_id, :sc_incmhprate, val1: -50)

      assert {:noreply, lowered} =
               StatsHandler.handle_status_changed(:sc_incmhprate, :apply, state)

      assert lowered.calculated.max_hp == 500
      assert lowered.hp == 500
      assert lowered.calculated.max_hp == 500
      assert {:ok, {MobState, registered, _pid}} = UnitRegistry.get_unit(:mob, state.instance_id)
      assert registered == lowered

      StatusStorage.remove_status(:mob, state.instance_id, :sc_incmhprate)
      :ok = StatusStorage.apply_status(:mob, state.instance_id, :sc_deluge, val1: 5, val2: 15)

      assert {:noreply, raised} = StatsHandler.handle_status_changed(:sc_deluge, :apply, lowered)
      assert raised.calculated.max_hp == 1150
      assert raised.hp == 500
    end
  end

  describe "speed consequence" do
    test "re-targets the pending walk without repricing it" do
      state =
        register(%{
          mob_state(walk_speed: 200)
          | movement_state: :moving,
            walk_path: [{31, 30}, {32, 30}],
            pending_step: {:pending, 123}
        })

      :ok = StatusStorage.apply_status(:mob, state.instance_id, :sc_decreaseagi, val1: 1)

      assert {:noreply, slowed} =
               StatsHandler.handle_status_changed(:sc_decreaseagi, :apply, state)

      assert slowed.calculated.speed == 250
      assert slowed.walk_target == {32, 30}
      assert slowed.pending_step == {:pending, 123}
    end
  end

  describe "mode consequence" do
    test "a selection dropping movement and attack stops both but keeps the cast" do
      state =
        register(%{
          mob_state(modes: [:can_move, :aggressive, :can_attack])
          | movement_state: :moving,
            walk_path: [{31, 30}],
            pending_step: {:pending, 1},
            attack_target: {:player, 7},
            attack_timer_at: 1_000,
            casting: %{row: :probe}
        })

      :ok =
        StatusStorage.apply_status(:mob, state.instance_id, :sc_modechange,
          val1: 1,
          val4: MobMode.mask([:can_move, :can_attack])
        )

      assert {:noreply, stopped} =
               StatsHandler.handle_status_changed(:sc_modechange, :apply, state)

      assert stopped.calculated.mode == MobMode.mask([:aggressive])
      assert stopped.movement_state == :standing
      assert stopped.walk_path == []
      assert stopped.attack_target == nil
      assert stopped.attack_timer_at == nil
      assert stopped.casting == %{row: :probe}
    end

    test "a standing mob is not re-positioned when the selection drops movement" do
      reject(&Movement.set_position/4)

      state = register(mob_state(modes: [:can_move, :aggressive, :can_attack]))

      :ok =
        StatusStorage.apply_status(:mob, state.instance_id, :sc_modechange,
          val1: 1,
          val4: MobMode.mask([:can_move])
        )

      assert {:noreply, stopped} =
               StatsHandler.handle_status_changed(:sc_modechange, :apply, state)

      assert stopped.calculated.mode == MobMode.mask([:aggressive, :can_attack])
      assert stopped.movement_state == :standing
    end
  end

  describe "replace_base/3" do
    test "recalculates only the selection and publishes nothing" do
      state = register(mob_state())
      :ok = StatusStorage.apply_status(:mob, state.instance_id, :sc_blessing, val1: 10, val2: 10)

      new_base = %{state.base | speed: 400}
      updated = StatsHandler.replace_base(%{state | calculated: state.base}, new_base, ["Speed"])

      assert updated.calculated.speed == 400
      assert updated.base.speed == 400
      assert updated.calculated.str == state.base.str
      assert {:ok, {MobState, registered, _pid}} = UnitRegistry.get_unit(:mob, state.instance_id)
      assert registered == state

      assert {:noreply, restored} =
               StatsHandler.handle_status_changed(:sc_intravision, :removed, updated)

      assert restored.calculated.str == state.base.str + 10
    end
  end

  describe "initialize_slave_mode/1" do
    test "keeps the raw base mode and restores the held entry through All" do
      state = mob_state(modes: [:can_move, :aggressive]) |> MobState.set_master(42)
      register(state)

      assert :ok = StatsHandler.initialize_slave_mode(state)
      mask = MobMode.mask(@slave_modes)

      assert %StatusEntry{val2: ^mask} =
               StatusStorage.get_status(:mob, state.instance_id, :sc_modechange)

      assert {:noreply, derived} =
               StatsHandler.handle_status_changed(:sc_modechange, :apply, state)

      assert derived.base.mode == MobMode.mask([:can_move, :aggressive])
      assert derived.calculated.mode == mask

      assert StatusStorage.get_status(:mob, state.instance_id, :sc_modechange) != nil

      reset = %{derived | calculated: derived.base}

      assert {:noreply, restored} =
               StatsHandler.handle_status_changed(:sc_intravision, :removed, reset)

      assert restored.base.mode == MobMode.mask([:can_move, :aggressive])
      assert restored.calculated.mode == mask
    end

    test "writes no entry when the form already declares the selection" do
      state = mob_state(modes: @slave_modes) |> MobState.set_master(42)
      register(state)

      assert :ok = StatsHandler.initialize_slave_mode(state)
      assert StatusStorage.get_status(:mob, state.instance_id, :sc_modechange) == nil
    end
  end

  defp register(%MobState{} = state) do
    UnitRegistry.register_unit(:mob, state.instance_id, MobState, state, self())
    state
  end

  defp mob_state(opts \\ []) do
    modes = Keyword.get(opts, :modes, [:can_move, :aggressive])

    mob_data =
      struct!(MobDefinition, %{
        id: 1001,
        aegis_name: "test_mob",
        name: "Test Mob",
        level: 25,
        hp: 1000,
        sp: 100,
        stats: %{str: 40, agi: 30, vit: 50, int: 20, dex: 35, luk: 15},
        atk: 50,
        matk: 60,
        def: 25,
        mdef: 10,
        attack_range: 1,
        skill_range: 10,
        chase_range: 12,
        walk_speed: Keyword.get(opts, :walk_speed, 200),
        attack_delay: 1200,
        attack_motion: 500,
        client_attack_motion: 400,
        damage_motion: 300,
        element: {:neutral, 1},
        race: :formless,
        size: :medium,
        modes: modes
      })

    spawn_ref =
      struct!(MobSpawn, %{
        mob: 1001,
        amount: 1,
        respawn_time: 5000,
        spawn_area: struct!(SpawnArea, %{x: 30, y: 30})
      })

    MobState.new(1, mob_data, spawn_ref, @map, 30, 30)
  end
end
