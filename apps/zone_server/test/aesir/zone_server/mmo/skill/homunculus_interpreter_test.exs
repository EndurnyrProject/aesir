defmodule Aesir.ZoneServer.Mmo.Skill.HomunculusInterpreterTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Mmo.Combat.AutoAttack
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.CastingHandler
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.CombatHandler
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables
  setup :verify_on_exit!

  setup do
    Mimic.copy(AutoAttack)
    Mimic.copy(CharacterPersistence)
    stub(CharacterPersistence, :update_stats, fn _id, _attrs, _opts -> :ok end)
    on_exit(&Catalog.reload/0)
    Catalog.reload()
    :ok
  end

  test "catalog discovers shipped Homunculus namespace modules without requiring every tree row" do
    assert {:ok, %{id: 8001, name: :hlif_heal}} = Catalog.by_id(8001)

    assert {:ok, Aesir.ZoneServer.Mmo.Skills.Homunculus.TestSupport} =
             Catalog.active_module_for(:hlif_heal)

    assert {:ok, %{id: 8003}} = Catalog.by_id(8003)
    assert :error = Catalog.active_module_for(:hlif_brain)
    assert {:ok, %{id: 8004}} = Catalog.by_id(8004)
    assert :error = Catalog.by_id(8005)
  end

  test "restricted begin validates and settles an instant cast" do
    caster = homunculus()

    assert {:instant, updated, effects} =
             Interpreter.begin_homunculus_cast(caster, 8001, 1, :self)

    assert updated.sp == 90
    assert Map.has_key?(updated.cooldowns, 8001)

    assert effects == [
             {:homunculus, {:apply_heal, 1_500_001, 5, {:homunculus, 1_500_001}}}
           ]
  end

  test "begin rejects invalid caster, tree, rank, SP, cooldown, and passive skills" do
    now = System.monotonic_time(:millisecond)
    caster = homunculus()

    for {updated, expected} <- [
          {%{caster | lifecycle: :dead, hp: 0, action_state: :dead}, :dead},
          {%{caster | movement_state: :moving}, :moving},
          {%{caster | action_state: :attacking}, :busy},
          {%{caster | class_id: 6002}, :wrong_species},
          {%{caster | learned_skills: %{}}, :skill_not_learned},
          {%{caster | sp: 9}, :insufficient_sp},
          {%{caster | cooldowns: %{8001 => now + 10_000}}, :on_cooldown}
        ] do
      assert {:error, ^expected} =
               Interpreter.begin_homunculus_cast(updated, 8001, 1, :self)
    end

    assert {:error, :skill_not_learned} =
             Interpreter.begin_homunculus_cast(caster, 8001, 2, :self)

    assert {:error, :passive_skill} =
             Interpreter.begin_homunculus_cast(caster, 8003, 1, :self)

    assert {:error, :unknown_skill} =
             Interpreter.begin_homunculus_cast(caster, 8005, 1, :self)
  end

  test "evolved-only skills require the current evolved form" do
    original = %{homunculus() | learned_skills: %{8004 => 1}}
    evolved = %{original | class_id: 6009}

    assert {:error, :skill_not_learned} =
             Interpreter.begin_homunculus_cast(original, 8004, 1, :self)

    assert {:instant, updated, []} =
             Interpreter.begin_homunculus_cast(evolved, 8004, 1, :self)

    assert updated.sp == 99
  end

  test "status gates cannot be bypassed by cast caller policy" do
    caster = homunculus()
    StatusStorage.apply_status(:homunculus, caster.world_gid, :sc_stun)

    assert {:error, :status_blocked} =
             Interpreter.begin_homunculus_cast(caster, 8001, 1, :self)
  end

  test "target relationship, type, liveness, and range are checked at begin" do
    caster = homunculus()
    near = mob(1_600_010, 12, 10)
    far = mob(1_600_011, 20, 10)
    dead = %{mob(1_600_012, 12, 10) | hp: 0, is_dead: true}
    Enum.each([near, far, dead], &register_mob/1)

    assert {:casting, _info} =
             Interpreter.begin_homunculus_cast(
               caster,
               8002,
               1,
               {:unit, {:mob, near.instance_id}}
             )

    assert {:error, :out_of_range} =
             Interpreter.begin_homunculus_cast(
               caster,
               8002,
               1,
               {:unit, {:mob, far.instance_id}}
             )

    assert {:error, :target_dead} =
             Interpreter.begin_homunculus_cast(
               caster,
               8002,
               1,
               {:unit, {:mob, dead.instance_id}}
             )

    assert {:error, :invalid_target} =
             Interpreter.begin_homunculus_cast(caster, 8002, 1, :self)

    assert {:error, :invalid_target} =
             Interpreter.begin_homunculus_cast(caster, 8002, 1, {:unit, near.instance_id})
  end

  test "ally support requires the caster's exact social root" do
    caster = homunculus()
    register_active(caster, owner())

    foreign_player = %{owner() | character_id: 200, x: 11}

    UnitRegistry.register_unit(
      :player,
      foreign_player.character_id,
      PlayerState,
      foreign_player,
      self()
    )

    SpatialIndex.add_unit(:player, foreign_player.character_id, 11, 10, foreign_player.map_name)

    foreign_homunculus = %{
      caster
      | id: 2,
        owner_character_id: 200,
        world_gid: 1_500_002,
        x: 11
    }

    UnitRegistry.register_unit(
      :homunculus,
      foreign_homunculus.world_gid,
      HomunculusState,
      foreign_homunculus,
      self()
    )

    SpatialIndex.add_unit(
      :homunculus,
      foreign_homunculus.world_gid,
      11,
      10,
      foreign_homunculus.map_name
    )

    assert {:error, :invalid_target} =
             Interpreter.begin_homunculus_cast(
               caster,
               8001,
               1,
               {:unit, {:player, foreign_player.character_id}}
             )

    assert {:error, :invalid_target} =
             Interpreter.begin_homunculus_cast(
               caster,
               8001,
               1,
               {:unit, {:homunculus, foreign_homunculus.world_gid}}
             )
  end

  test "completion revalidates the latest target before settlement" do
    session = session()
    register_active(session.homunculus, session.game_state)
    target = mob(1_600_020, 12, 10)
    register_mob(target)

    assert {:ok, casting_session} =
             CastingHandler.begin(session, 8002, 1, {:unit, {:mob, target.instance_id}})

    token = casting_session.homunculus.casting.token
    timer_ref = casting_session.homunculus_runtime.cast_timer_ref
    UnitRegistry.update_unit_state(:mob, target.instance_id, %{target | hp: 0, is_dead: true})

    assert {:noreply, cancelled} = CastingHandler.complete(timer_ref, token, casting_session)
    assert cancelled.homunculus.sp == 100
    assert cancelled.homunculus.cooldowns == %{}
    assert cancelled.homunculus.casting == nil
    refute_received {:homunculus_test_attack, _, _}
  end

  test "instant aggregate-local Homunculus and owner effects apply directly" do
    session = session()
    register_active(session.homunculus, session.game_state)

    assert {:ok, self_targeted} = CastingHandler.begin(session, 8001, 1, :self)
    assert self_targeted.homunculus.hp == 55
    assert self_targeted.homunculus.sp == 90

    owner_session = %{session | homunculus: %{session.homunculus | cooldowns: %{}}}

    assert {:ok, owner_targeted} =
             CastingHandler.begin(owner_session, 8001, 1, {:unit, {:player, 100}})

    assert owner_targeted.game_state.stats.current_state.hp == 57
    assert Process.alive?(self())
  end

  test "a basic attack immediately cancels an active cast" do
    stub(AutoAttack, :execute_homunculus_attack, fn _caster, _target_ref -> :ok end)

    session = session()
    register_active(session.homunculus, session.game_state)
    target = mob(1_600_030, 12, 10)
    register_mob(target)

    assert {:ok, casting_session} =
             CastingHandler.begin(session, 8002, 1, {:unit, {:mob, target.instance_id}})

    token = casting_session.homunculus.casting.token
    timer_ref = casting_session.homunculus_runtime.cast_timer_ref

    assert {:noreply, attacked} =
             CombatHandler.handle(
               {:basic_attack, casting_session.homunculus.world_gid, {:mob, target.instance_id}},
               casting_session
             )

    assert attacked.homunculus.action_state == :idle
    assert attacked.homunculus.casting == nil
    assert attacked.homunculus_runtime.cast_timer_ref == nil
    assert {:noreply, ^attacked} = CastingHandler.complete(timer_ref, token, attacked)
  end

  test "timed aggregate cast settles only for the matching token and timer reference" do
    session = session()
    register_active(session.homunculus, session.game_state)
    target = mob(1_600_001, 12, 10)
    register_mob(target)

    assert {:ok, casting_session} =
             CastingHandler.begin(session, 8002, 1, {:unit, {:mob, target.instance_id}})

    token = casting_session.homunculus.casting.token
    timer_ref = casting_session.homunculus_runtime.cast_timer_ref
    assert casting_session.homunculus.sp == 100
    assert casting_session.homunculus.action_state == :casting

    assert {:noreply, ^casting_session} =
             CastingHandler.complete(make_ref(), token, casting_session)

    assert {:noreply, completed} = CastingHandler.complete(timer_ref, token, casting_session)
    assert completed.homunculus.sp == 80
    assert completed.homunculus.action_state == :idle
    assert completed.homunculus.casting == nil
    assert completed.homunculus_runtime.cast_timer_ref == nil
    assert_received {:homunculus_test_attack, {:unit, {:mob, 1_600_001}}, 1}

    assert {:noreply, ^completed} = CastingHandler.complete(timer_ref, token, completed)
    refute_received {:homunculus_test_attack, _, _}
  end

  defp session do
    %SessionState{game_state: owner(), connection_pid: self(), homunculus: homunculus()}
  end

  defp owner do
    %PlayerState{
      character_id: 100,
      map_name: "hom_cast_map",
      x: 10,
      y: 10,
      dir: 0,
      action_state: :idle,
      movement_state: :standing,
      stats: %{
        current_state: %{hp: 50, sp: 100},
        derived_stats: %{max_hp: 100, max_sp: 100},
        progression: %{learned_skills: %{}}
      }
    }
  end

  defp register_active(homunculus, owner) do
    UnitRegistry.register_unit(
      :homunculus,
      homunculus.world_gid,
      HomunculusState,
      homunculus,
      self()
    )

    SpatialIndex.add_unit(
      :homunculus,
      homunculus.world_gid,
      homunculus.x,
      homunculus.y,
      homunculus.map_name
    )

    UnitRegistry.register_unit(:player, owner.character_id, PlayerState, owner, self())
    SpatialIndex.add_unit(:player, owner.character_id, owner.x, owner.y, owner.map_name)
  end

  defp register_mob(mob) do
    UnitRegistry.register_unit(:mob, mob.instance_id, MobState, mob, self())
    SpatialIndex.add_unit(:mob, mob.instance_id, mob.x, mob.y, mob.map_name)
  end

  defp mob(id, x, y) do
    %MobState{
      instance_id: id,
      mob_id: 1,
      mob_data: nil,
      spawn_ref: nil,
      x: x,
      y: y,
      map_name: "hom_cast_map",
      hp: 100,
      max_hp: 100,
      sp: 0,
      max_sp: 0,
      spawned_at: 0
    }
  end

  defp homunculus do
    %HomunculusState{
      id: 1,
      owner_character_id: 100,
      owner_session_pid: self(),
      class_id: 6001,
      name: "Lif",
      lifecycle: :active,
      level: 20,
      hp: 50,
      max_hp: 100,
      sp: 100,
      max_sp: 100,
      dex: 1,
      int: 1,
      learned_skills: %{8001 => 1, 8002 => 1, 8003 => 1},
      world_gid: 1_500_001,
      map_name: "hom_cast_map",
      x: 10,
      y: 10,
      action_state: :idle,
      movement_state: :standing
    }
  end
end
