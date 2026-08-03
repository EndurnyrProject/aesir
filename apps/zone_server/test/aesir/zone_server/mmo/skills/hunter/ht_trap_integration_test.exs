defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.HtTrapIntegrationTest.FakeMob do
  @moduledoc """
  A stand-in mob session that walks onto a trap from inside its OWN process.

  This exercises the real callback path from movement through the serialized
  skill-unit manager, including damage delivery back to the mover process.
  """
  use GenServer

  alias Aesir.ZoneServer.Unit.Movement

  def start_link(init), do: GenServer.start_link(__MODULE__, init)

  @impl true
  def init(init), do: {:ok, init}

  @impl true
  def handle_call({:walk_to, new_state}, _from, %{mob_id: id, map: map} = state) do
    Movement.set_position(:mob, id, new_state, map)
    {:reply, :ok, %{state | mob_state: new_state}}
  end

  @impl true
  def handle_cast({:combat, {:apply_damage, damage, attacker_id}}, %{test_pid: test_pid} = state) do
    send(test_pid, {:applied, damage, attacker_id})
    {:noreply, state}
  end
end

defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.HtTrapIntegrationTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  import Aesir.TestWait
  import Mimic

  alias Aesir.Net.Knockback
  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobSkill.Executor
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.Skill.Unit.TrapState
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.HtAnklesnare
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.HtTrapIntegrationTest.FakeMob
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Resistance
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.Stats.BaseStats
  alias Aesir.ZoneServer.Unit.Stats.CombatStats
  alias Aesir.ZoneServer.Unit.Stats.CurrentState
  alias Aesir.ZoneServer.Unit.Stats.DerivedStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup do
    Mimic.copy(Resistance)
    :ok
  end

  setup {Aesir.MimicMode, :global}
  setup :setup_runtime_tables

  setup do
    manager =
      start_supervised!({Manager, name: nil, schedule_tick: fn _pid, _interval -> :ok end})

    Process.put({Manager, :server}, manager)
    {:ok, manager: manager}
  end

  @caster_id 1000
  @mob_id 2001
  @map "prontera"
  @trap {50, 50}

  defp build_caster do
    stats = %Stats{
      base_stats: %BaseStats{str: 1, agi: 1, vit: 1, int: 40, dex: 50, luk: 1},
      combat_stats: %CombatStats{atk: 1, def: 1, hit: 1, flee: 1, perfect_dodge: 1, matk: 1},
      derived_stats: %DerivedStats{max_hp: 100, max_sp: 50, aspd: 150},
      current_state: %CurrentState{hp: 100, sp: 50},
      progression: %PlayerProgression{base_level: 50, job_level: 1, learned_skills: %{}},
      equipment: %Equipment{}
    }

    struct(PlayerState,
      character_id: @caster_id,
      account_id: @caster_id,
      x: 40,
      y: 40,
      map_name: @map,
      action_state: :idle,
      stats: stats
    )
  end

  defp build_mob_state(x, y) do
    mob_definition =
      struct(MobDefinition,
        id: 1002,
        aegis_name: "TEST_MOB",
        name: "TestMob",
        level: 1,
        hp: 1000,
        sp: 50,
        base_exp: 10,
        job_exp: 5,
        atk: 10,
        matk: 0,
        def: 5,
        mdef: 3,
        stats: %{str: 10, agi: 10, vit: 10, int: 5, dex: 10, luk: 5},
        attack_range: 1,
        skill_range: 10,
        chase_range: 12,
        element: {:neutral, 1},
        race: :formless,
        size: :medium,
        walk_speed: 200,
        attack_delay: 1000,
        attack_motion: 500,
        client_attack_motion: 500,
        damage_motion: 400,
        ai_type: 0,
        modes: [],
        drops: []
      )

    mob_spawn =
      struct(MobSpawn,
        mob: 1002,
        amount: 1,
        respawn_time: 5_000,
        spawn_area: struct(MobSpawn.SpawnArea, x: x, y: y, xs: 0, ys: 0)
      )

    struct(MobState,
      instance_id: @mob_id,
      mob_id: 1002,
      mob_data: mob_definition,
      spawn_ref: mob_spawn,
      x: x,
      y: y,
      map_name: @map,
      hp: 1000,
      max_hp: 1000,
      sp: 50,
      max_sp: 50,
      spawned_at: System.system_time(:second),
      aggro_list: %{}
    )
  end

  defp landmine_group do
    struct(Group,
      group_id: 999,
      skill_id: 116,
      skill_name: :ht_landmine,
      level: 3,
      caster_id: @caster_id,
      caster_type: :player,
      map_name: @map,
      center: @trap,
      cells: [@trap],
      next_tick_at: System.monotonic_time(:millisecond) + 60_000,
      expires_at: System.monotonic_time(:millisecond) + 60_000,
      interval: 1_000,
      visibility: :party_only,
      state: %{base_damage: 250, trap: struct(TrapState, reclaim_item_id: 1065)}
    )
  end

  test "a real mob cast captures a player already at the trap without displacing it" do
    player = start_real_player(id: @caster_id, map_name: @map, position: @trap)
    mob = %{build_mob_state(40, 40) | target_ref: {:player, @caster_id}}

    UnitRegistry.register_unit(:mob, @mob_id, MobState, mob, self())
    flush_packets()

    row = %{
      skill: "HT_ANKLESNARE",
      skill_id: 117,
      level: 1,
      target: :target,
      emotion: nil
    }

    assert :ok = Executor.execute(mob, row)

    assert [%{__struct__: Group, group_id: group_id, caster_type: :mob, visibility: :party_only}] =
             Storage.all()

    assert :ok = Manager.trigger(group_id, {:player, @caster_id}, :on_touch)

    assert_eventually(fn ->
      match?(
        %{
          __struct__: Group,
          target_type: :player,
          target_id: @caster_id,
          state: %{trap: %{__struct__: TrapState, phase: :captured}}
        },
        Storage.get(group_id)
      )
    end)

    assert %{
             __struct__: Group,
             state: %{trap: %{__struct__: TrapState, link_id: link_id}}
           } = Storage.get(group_id)

    assert %{source_type: :mob, state: %{group_id: ^group_id, link_id: ^link_id}} =
             StatusStorage.get_status(:player, @caster_id, :sc_anklesnare)

    assert {50, 50} ==
             {PlayerSession.get_state(player.pid).game_state.x,
              PlayerSession.get_state(player.pid).game_state.y}

    refute_receive {:packet_sent, %{__struct__: Knockback}, _channel}, 50
  end

  test "capturing a real mob pulls it onto the trap cell through its session" do
    _caster = start_real_player(id: @caster_id, map_name: @map, position: {40, 40})
    mob = start_real_mob(unit_id: @mob_id, map_name: @map, position: {49, 50})
    :ok = Storage.insert(ankle_group(1))

    assert :ok = Manager.trigger(1, {:mob, @mob_id}, :on_touch)

    assert_eventually(fn ->
      state = MobSession.get_state(mob.pid)
      group = Storage.get(1)
      {state.x, state.y} == @trap and group.state.trap.phase == :captured
    end)

    assert StatusStorage.has_status?(:mob, @mob_id, :sc_anklesnare)
  end

  test "a concurrently displaced player is still captured and the stale pull no-ops" do
    UnitRegistry.register_unit(:mob, @mob_id, MobState, build_mob_state(40, 40), self())
    player = start_real_player(id: @caster_id, map_name: @map, position: {49, 50})
    :ok = Storage.insert(ankle_group(2, :mob, @mob_id))

    :ok = :sys.suspend(player.pid)

    GenServer.cast(
      player.pid,
      {:movement, {:displace, 49, 50, @map, 48, 50}}
    )

    assert :ok = Manager.trigger(2, {:player, @caster_id}, :on_touch)
    :ok = :sys.resume(player.pid)

    assert_eventually(fn -> PlayerSession.get_state(player.pid).game_state.x == 48 end)
    Process.sleep(50)

    state = PlayerSession.get_state(player.pid).game_state
    assert {state.x, state.y} == {48, 50}
    assert Storage.get(2).state.trap.phase == :captured
    assert StatusStorage.has_status?(:player, @caster_id, :sc_anklesnare)
  end

  test "a captured snare rejects further triggers, reclaim, and spring", %{manager: manager} do
    _caster = start_real_player(id: @caster_id, map_name: @map, position: {40, 40})
    first = start_real_mob(unit_id: @mob_id, map_name: @map, position: {49, 50})
    second = start_real_mob(unit_id: @mob_id + 1, map_name: @map, position: {49, 50})
    :ok = Storage.insert(ankle_group(5))

    assert :ok = Manager.trigger(5, {:mob, @mob_id}, :on_touch)
    assert Storage.get(5).state.trap.phase == :captured
    assert StatusStorage.has_status?(:mob, @mob_id, :sc_anklesnare)

    assert :ok = Manager.trigger(5, {:mob, @mob_id + 1}, :on_touch)
    refute StatusStorage.has_status?(:mob, @mob_id + 1, :sc_anklesnare)
    assert Storage.get(5).target_id == @mob_id

    assert {:error, _reason} =
             Manager.reclaim_trap(manager, {:player, @caster_id}, @map, 50, 50)

    assert {:error, _reason} = Manager.spring_trap(manager, @map, 50, 50)

    assert_eventually(fn ->
      {MobSession.get_state(first.pid).x, MobSession.get_state(first.pid).y} == @trap
    end)

    assert {49, 50} == {MobSession.get_state(second.pid).x, MobSession.get_state(second.pid).y}
  end

  test "session status immunity and an existing snare reject before movement" do
    _caster = start_real_player(id: @caster_id, map_name: @map, position: {40, 40})

    immune =
      start_real_mob(
        unit_id: @mob_id,
        map_name: @map,
        position: {49, 50},
        modes: [:status_immune]
      )

    :ok = Storage.insert(ankle_group(6))
    assert :ok = Manager.trigger(6, {:mob, @mob_id}, :on_touch)
    Process.sleep(50)
    assert {49, 50} == {MobSession.get_state(immune.pid).x, MobSession.get_state(immune.pid).y}
    assert Storage.get(6).state.trap.phase == :armed

    snared = start_real_mob(unit_id: @mob_id + 1, map_name: @map, position: {49, 50})

    :ok =
      StatusStorage.apply_status(:mob, @mob_id + 1, :sc_anklesnare,
        duration: 5_000,
        state: %{group_id: 999, link_id: 999}
      )

    :ok = Storage.insert(ankle_group(7))
    assert :ok = Manager.trigger(7, {:mob, @mob_id + 1}, :on_touch)
    Process.sleep(50)
    assert {49, 50} == {MobSession.get_state(snared.pid).x, MobSession.get_state(snared.pid).y}
    assert Storage.get(7).state.trap.phase == :armed

    assert %{state: %{group_id: 999}} =
             StatusStorage.get_status(:mob, @mob_id + 1, :sc_anklesnare)
  end

  @tag :capture_log
  test "capture materialization failure destroys the group and the status self-heals" do
    _caster = start_real_player(id: @caster_id, map_name: @map, position: {40, 40})
    _mob = start_real_mob(unit_id: @mob_id, map_name: @map, position: {49, 50})

    blocker =
      ankle_group(80)
      |> Map.put(:visibility, :public)
      |> Map.update!(:state, fn state ->
        Map.merge(state, %{
          exclusive_terrain: true,
          cell_attrs: %{@trap => %{state: %{exclusive_terrain: true}}}
        })
      end)

    trap =
      ankle_group(8)
      |> Map.update!(:state, &Map.put(&1, :exclusive_terrain, true))

    assert :ok = Manager.register(blocker)
    assert :ok = Storage.insert(trap)
    assert :ok = Manager.trigger(8, {:mob, @mob_id}, :on_touch)

    assert nil == Storage.get(8)
    assert [] == Storage.get_cells_by_group(8)

    assert :ok = Interpreter.process_tick(:mob, @mob_id, :sc_anklesnare)
    refute StatusStorage.has_status?(:mob, @mob_id, :sc_anklesnare)
  end

  test "a dead target leaves the snare armed without a status" do
    _caster = start_real_player(id: @caster_id, map_name: @map, position: {40, 40})
    mob = start_real_mob(unit_id: @mob_id, map_name: @map, position: {49, 50}, hp: 100)
    :ok = Storage.insert(ankle_group(4))

    MobSession.apply_damage(mob.pid, 100)
    assert_eventually(fn -> MobSession.get_state(mob.pid).is_dead end)
    UnitRegistry.register_unit(:mob, @mob_id, MobState, MobSession.get_state(mob.pid), mob.pid)

    assert :ok = Manager.trigger(4, {:mob, @mob_id}, :on_touch)

    assert Storage.get(4).state.trap.phase == :armed
    refute StatusStorage.has_status?(:mob, @mob_id, :sc_anklesnare)
  end

  test "Skid Trap moves and stops real MobSessions at every level and becomes visibly used" do
    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)

    for repetition <- 1..3, level <- 1..5 do
      index = (repetition - 1) * 5 + level
      y = 20 + index * 8
      group_id = 10_000 + index
      mob_id = @mob_id + index
      mob_state = %{build_mob_state(50, y) | instance_id: mob_id}
      {:ok, mob_pid} = MobSession.start_link(%{state: mob_state, awake: false})
      UnitRegistry.register_unit(:mob, mob_id, MobState, mob_state, mob_pid)
      SpatialIndex.add_unit(:mob, mob_id, 50, y, @map)

      group = %{
        landmine_group()
        | group_id: group_id,
          skill_id: 115,
          skill_name: :ht_skidtrap,
          level: level,
          center: {50, y},
          origin: {49, y},
          cells: [{50, y}],
          state: %{trap: %TrapState{reclaim_item_id: 1065}}
      }

      :ok = Storage.insert(group)
      assert :ok = Manager.trigger(manager(), group_id, {:mob, mob_id}, :on_touch)

      expected = collision_landing({50, y}, level + 5)

      assert eventually(fn ->
               %{x: x, y: current_y} = MobSession.get_state(mob_pid)
               {x, current_y} == expected
             end)

      assert %{expires_at: stop_expires_at} =
               StatusStorage.get_status(:mob, mob_id, :sc_stop)

      stop_remaining = stop_expires_at - System.monotonic_time(:millisecond)
      assert stop_remaining in 2_500..3_000

      assert %Group{visibility: :public, expires_at: expires_at, state: %{trap: trap}} =
               Storage.get(group_id)

      assert trap.phase == :used
      remaining = expires_at - System.monotonic_time(:millisecond)
      assert remaining in 1_000..1_500
    end
  end

  test "boss, status-immune, and same-side real mobs leave Skid Trap armed" do
    for {group_id, modes, caster_type} <- [
          {11_001, [:boss], :player},
          {11_002, [:status_immune], :player},
          {11_003, [], :mob}
        ] do
      mob_id = @mob_id + group_id
      mob_state = build_mob_state(50, 50)

      mob_state = %{
        mob_state
        | instance_id: mob_id,
          mob_data: %{mob_state.mob_data | modes: modes}
      }

      {:ok, mob_pid} = MobSession.start_link(%{state: mob_state, awake: false})
      UnitRegistry.register_unit(:mob, mob_id, MobState, mob_state, mob_pid)
      SpatialIndex.add_unit(:mob, mob_id, 50, 50, @map)

      group = %{
        landmine_group()
        | group_id: group_id,
          skill_id: 115,
          skill_name: :ht_skidtrap,
          caster_type: caster_type,
          center: {50, 50},
          origin: {49, 50},
          cells: [{50, 50}],
          state: %{trap: %TrapState{reclaim_item_id: 1065}}
      }

      :ok = Storage.insert(group)
      assert :ok = Manager.trigger(manager(), group_id, {:mob, mob_id}, :on_touch)

      assert %Group{visibility: :party_only, state: %{trap: %{phase: :armed}}} =
               Storage.get(group_id)

      refute StatusStorage.has_status?(:mob, mob_id, :sc_stop)
      assert %{x: 50, y: 50} = MobSession.get_state(mob_pid)
    end
  end

  test "an enemy mob stepping onto a Land Mine leaves one used state without deadlocking" do
    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)
    stub(Resistance, :roll_success, fn _success_rate -> true end)

    caster = build_caster()
    UnitRegistry.register_unit(:player, @caster_id, PlayerState, caster, self())

    {sx, sy} = {49, 50}
    mob_state = build_mob_state(sx, sy)

    {:ok, fake_mob} =
      FakeMob.start_link(%{test_pid: self(), mob_id: @mob_id, map: @map, mob_state: mob_state})

    UnitRegistry.register_unit(:mob, @mob_id, MobState, mob_state, fake_mob)
    SpatialIndex.add_unit(:mob, @mob_id, sx, sy, @map)

    :ok = Storage.insert(landmine_group())

    assert [%{__struct__: Group, group_id: 999, visibility: :party_only}] =
             Storage.get_groups_at_cell(@map, 50, 50)

    assert [] = Storage.get_cells_by_group(999)
    assert %{groups: []} = Aesir.ZoneServer.Mmo.Skill.Unit.snapshot(@map)

    {tx, ty} = @trap
    walked = %{mob_state | x: tx, y: ty, movement_state: :moving}

    # The movement call waits for the Manager callback and must not deadlock.
    assert :ok = GenServer.call(fake_mob, {:walk_to, walked})

    assert_receive {:applied, damage, @caster_id}, 1_000
    assert damage > 0

    assert %{
             __struct__: Group,
             visibility: :public,
             expires_at: expires_at,
             state: %{trap: %TrapState{phase: :used}}
           } = Storage.get(999)

    remaining = expires_at - System.monotonic_time(:millisecond)
    assert remaining in 1_300..1_500
    assert [_cell] = Storage.get_cells_by_group(999)

    assert %{source_id: @caster_id, source_type: :player} =
             StatusStorage.get_status(:mob, @mob_id, :sc_stun)
  end

  defp manager, do: Process.get({Manager, :server})

  defp collision_landing(start, distance) do
    Enum.reduce_while(1..distance, start, fn _step, {x, y} = current ->
      next = {x + 1, y}

      if Cell.step_traversable?(@map, current, next),
        do: {:cont, next},
        else: {:halt, current}
    end)
  end

  defp ankle_group(group_id, caster_type \\ :player, caster_id \\ @caster_id, center \\ @trap) do
    struct(Group,
      group_id: group_id,
      skill_id: 117,
      skill_name: :ht_anklesnare,
      level: 1,
      caster_id: caster_id,
      caster_type: caster_type,
      map_name: @map,
      center: center,
      cells: [center],
      next_tick_at: System.monotonic_time(:millisecond) + 60_000,
      expires_at: System.monotonic_time(:millisecond) + 60_000,
      interval: 1_000,
      visibility: :party_only,
      state: %{trap: struct(TrapState, reclaim_item_id: 1065)},
      handler: HtAnklesnare
    )
  end

  defp setup_runtime_tables(context) do
    sandbox = Ecto.Adapters.SQL.Sandbox
    :ok = apply(sandbox, :checkout, [Aesir.Repo])
    :ok = apply(sandbox, :mode, [Aesir.Repo, {:shared, self()}])
    apply(Elixir.Aesir.TestEtsSetup, :setup_ets_tables, [context])
  end

  defp start_real_player(opts) do
    apply(Elixir.Aesir.ZoneServer.SessionHelpers, :start_player_session, [opts])
  end

  defp start_real_mob(opts) do
    apply(Elixir.Aesir.ZoneServer.SessionHelpers, :start_mob_session, [opts])
  end

  defp flush_packets do
    receive do
      {:packet_sent, _packet, _channel} -> flush_packets()
    after
      50 -> :ok
    end
  end
end
