defmodule Aesir.ZoneServer.Mmo.Combat.PolymorphTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Net.SpriteChange
  alias Aesir.ZoneServer.Mmo.ItemDrop.GroundItem
  alias Aesir.ZoneServer.Mmo.ItemManagement.EquipScript
  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.BonusKeys
  alias Aesir.ZoneServer.Mmo.Mechanics
  alias Aesir.ZoneServer.Mmo.MobManagement
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.PolymorphPool
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.AIStateMachine
  alias Aesir.ZoneServer.Unit.Mob.Handlers.CombatHandler
  alias Aesir.ZoneServer.Unit.Mob.Handlers.StatsHandler
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Mob.Stats
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_private
  setup :setup_ets_tables

  test "class-change bonuses overwrite rather than sum, and ammunition cannot contribute" do
    assert {:ok, :class_change} = BonusKeys.destination("bClassChange")

    program =
      EquipScript.parse!(
        "ctx = bonus(ctx, :class_change, 300)\nctx = bonus(ctx, :class_change, 100)\nctx"
      )

    assert EquipScript.eval(program, %{refine: 0}).class_change == 100
    assert BonusKeys.slot_destination(:class_change, :arrow) == nil
  end

  test "changing a monster's attack delay cannot move its already established deadline" do
    {:ok, data} = MobManagement.get_mob_by_id(1002)
    spawn = %MobSpawn{mob: 1002, amount: 1, respawn_time: 5000, spawn_area: nil}
    state = MobState.new(919, data, spawn, "prontera", 100, 100)
    delayed = MobState.start_attack_delay(state, 10_000)
    deadline = 10_000 + MobState.get_attack_delay(state)
    changed = %{delayed | calculated: %{delayed.calculated | adelay: 5000, amotion: 4000}}

    refute changed.calculated.adelay == delayed.calculated.adelay
    refute AIStateMachine.attack_delay_over?(changed, deadline - 1)
    assert AIStateMachine.attack_delay_over?(changed, deadline)
  end

  test "a form change rebuilds vitals but retains its level, loot, elapsed attack delay and fired effects" do
    {:ok, data} = MobManagement.get_mob_by_id(1002)
    {:ok, replacement} = MobManagement.get_mob_by_id(1001)
    spawn = %MobSpawn{mob: 1002, amount: 1, respawn_time: 5000, spawn_area: nil}
    item = GroundItem.new(501, 3, 100, 100)
    state = MobState.new(919, data, spawn, "prontera", 100, 100)
    state = MobState.start_attack_delay(state, 10_000)

    state = %{
      state
      | level: 42,
        hp: 1,
        sp: 0,
        skill_cooldowns: %{10 => 20_000},
        aggro_list: %{17 => 99},
        target_ref: {:player, 17},
        attacked_ref: {:player, 17},
        norm_attacked_ref: {:player, 17},
        skill_state: :berserk,
        looted_items: [item],
        deferred_epoch: 7
    }

    UnitRegistry.register_unit(:mob, 919, MobState, state, self())
    SpatialIndex.add_unit(:mob, 919, 100, 100, "prontera")
    parent = self()

    stub(Broadcast, :to_in_range, fn _, _, _, _, packet ->
      send(parent, {:packet, packet})
      :ok
    end)

    {:noreply, changed} = CombatHandler.handle_polymorph(1001, state)

    assert changed.mob_id == 1001
    assert changed.hp == replacement.hp
    assert changed.sp == replacement.sp
    assert MobState.get_level(changed) == 42
    assert changed.mob_data.level == replacement.level
    assert changed.skill_state == :berserk
    assert changed.skill_cooldowns == %{}
    assert changed.aggro_list == %{}
    assert changed.target_ref == nil
    assert changed.attack_target == nil
    assert changed.attacked_ref == nil
    assert changed.norm_attacked_ref == nil
    assert changed.looted_items == [item]
    assert changed.deferred_epoch == 7
    assert changed.attack_delay_until == state.attack_delay_until
    assert_received {:packet, %SpriteChange{gid: 919, type: 0, val: 1001}}

    # A runtime level outside the allowed range adopts the replacement's level.
    {:noreply, out_of_range} = CombatHandler.handle_polymorph(1001, %{state | level: 999})
    assert MobState.get_level(out_of_range) == replacement.level
  end

  test "a form change refuses an unchanged, unknown, treasure, guardian or summon form" do
    {:ok, data} = MobManagement.get_mob_by_id(1002)
    spawn = %MobSpawn{mob: 1002, amount: 1, respawn_time: 5000, spawn_area: nil}
    state = MobState.new(919, data, spawn, "prontera", 100, 100)
    UnitRegistry.register_unit(:mob, 919, MobState, state, self())
    stub(Broadcast, :to_in_range, fn _, _, _, _, _packet -> :ok end)

    assert {:noreply, ^state} = CombatHandler.handle_polymorph(1002, state)
    assert {:noreply, ^state} = CombatHandler.handle_polymorph(999_999, state)

    guardian = %{state | guild_id: 7}
    assert {:noreply, ^guardian} = CombatHandler.handle_polymorph(1001, guardian)

    emperium = %{state | mob_id: 1288}
    assert {:noreply, ^emperium} = CombatHandler.handle_polymorph(1001, emperium)

    summon = %{state | owner_player_id: 5}
    assert {:noreply, ^summon} = CombatHandler.handle_polymorph(1001, summon)

    treasure = %{state | mob_data: %{data | race_groups: [:treasure]}}
    assert {:noreply, ^treasure} = CombatHandler.handle_polymorph(1001, treasure)
  end

  test "a form change resets the snapshot and later selections restore only what they select" do
    {:ok, data} = MobManagement.get_mob_by_id(1002)
    spawn = %MobSpawn{mob: 1002, amount: 1, respawn_time: 5000, spawn_area: nil}
    state = MobState.new(919, data, spawn, "prontera", 100, 100)
    UnitRegistry.register_unit(:mob, 919, MobState, state, self())
    SpatialIndex.add_unit(:mob, 919, 100, 100, "prontera")
    stub(Broadcast, :to_in_range, fn _, _, _, _, _packet -> :ok end)

    # A held Blessing raises the form's STR.
    StatusStorage.apply_status(:mob, 919, :sc_blessing, val1: 5, val2: 10)
    {:noreply, held} = StatsHandler.handle_status_changed(:sc_blessing, :apply, state)
    assert held.calculated.str == held.base.str + 10

    # The form change resets the snapshot to the replacement's raw base.
    {:noreply, reshaped} = CombatHandler.handle_polymorph(1001, held)
    fresh = Mechanics.mob_formulas().base(reshaped)
    assert reshaped.calculated == fresh
    assert reshaped.calculated.str == fresh.str

    # A later unrelated event refreshes only its own selection.
    StatusStorage.apply_status(:mob, 919, :sc_increaseagi, val2: 1)
    {:noreply, faster} = StatsHandler.handle_status_changed(:sc_increaseagi, :apply, reshaped)
    assert faster.calculated.str == fresh.str
    assert faster.calculated.agi == fresh.agi + 1

    # A full calculation restores every applicable held contribution.
    entries = StatusStorage.get_unit_statuses(:mob, 919)
    all = Mechanics.mob_formulas().expand_calc_flags(["All"])
    restored = Stats.recalculate(faster, entries, all)
    assert restored.str == fresh.str + 10
    assert restored.agi == fresh.agi + 1
  end

  test "a form change cancels an in-flight cast without writing a cooldown" do
    {:ok, data} = MobManagement.get_mob_by_id(1002)
    spawn = %MobSpawn{mob: 1002, amount: 1, respawn_time: 5000, spawn_area: nil}
    state = MobState.new(919, data, spawn, "prontera", 100, 100)
    timer = Process.send_after(self(), :stale_cast, 60_000)

    state = %{
      state
      | casting: %{row: %{skill_id: 10, delay: 7_000}, complete_at: 0, timer_ref: timer}
    }

    UnitRegistry.register_unit(:mob, 919, MobState, state, self())
    SpatialIndex.add_unit(:mob, 919, 100, 100, "prontera")
    stub(Broadcast, :to_in_range, fn _, _, _, _, _packet -> :ok end)

    {:noreply, changed} = CombatHandler.handle_polymorph(1001, state)

    assert changed.casting == nil
    assert changed.skill_cooldowns == %{}
    assert Process.read_timer(timer) == false
    refute_received :stale_cast
  end

  test "a form change without full recovery keeps the HP percentage and the damage history" do
    previous = Application.get_env(:zone_server, :monster_class_change_full_recover)
    Application.put_env(:zone_server, :monster_class_change_full_recover, false)

    on_exit(fn ->
      Application.put_env(:zone_server, :monster_class_change_full_recover, previous)
    end)

    {:ok, data} = MobManagement.get_mob_by_id(1002)
    # A large old form makes a low percentage round to zero, which is the
    # branch the source floors at 1 HP.
    data = %{data | hp: 5_000}
    spawn = %MobSpawn{mob: 1002, amount: 1, respawn_time: 5000, spawn_area: nil}
    state = MobState.new(919, data, spawn, "prontera", 100, 100)
    state = %{state | hp: div(state.calculated.max_hp, 2), aggro_list: %{17 => 99}}
    UnitRegistry.register_unit(:mob, 919, MobState, state, self())
    SpatialIndex.add_unit(:mob, 919, 100, 100, "prontera")
    stub(Broadcast, :to_in_range, fn _, _, _, _, _packet -> :ok end)

    hp_rate = div(state.hp * 100, state.calculated.max_hp)
    {:noreply, changed} = CombatHandler.handle_polymorph(1001, state)

    assert changed.hp == max(div(changed.base.max_hp * hp_rate, 100), 1)
    assert changed.aggro_list == %{17 => 99}
    assert changed.mob_id == 1001

    # A dead-percentage form keeps at least 1 HP.
    {:noreply, floored} = CombatHandler.handle_polymorph(1001, %{state | hp: 1})
    assert floored.hp == 1
  end

  test "the monster pool uses rejection sampling with a bounded default, not weighted totals" do
    certain = %{default: 1001, entries: [{1002, 1_000_000}]}
    assert PolymorphPool.choose(certain, fn 1 -> 1 end) == 1002
    parent = self()
    rejected = %{default: 1001, entries: [{1002, 1}]}

    rng = fn
      1 ->
        1

      1_000_000 ->
        send(parent, :rejection)
        2
    end

    assert PolymorphPool.choose(rejected, rng) == 1001
    assert_received :rejection
    assert_received :rejection
    assert_received :rejection
    refute_received :rejection
    assert PolymorphPool.choose(%{default: 1001, entries: []}, rng) == 0
  end
end
