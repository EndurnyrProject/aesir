defmodule Aesir.ZoneServer.Mmo.Skills.Assassin.AsSplasherTest do
  use ExUnit.Case, async: false
  use Mimic

  @moduletag :capture_log

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobSkill.Db
  alias Aesir.ZoneServer.Mmo.MobSkill.Executor
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter, as: SkillInterpreter
  alias Aesir.ZoneServer.Mmo.Skills.Assassin.AsSplasher
  alias Aesir.ZoneServer.Mmo.StatusEffect.Dispel
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Mmo.StatusTickManager
  alias Aesir.ZoneServer.PlayerStateFixture
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.SpecialEffect
  alias Aesir.ZoneServer.Unit.Stats.CombatStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables
  setup :verify_on_exit!

  test "defines Venom Splasher's exact player and mob-safe contract" do
    assert {:ok, definition} = Catalog.by_id(141)
    assert definition.name == :as_splasher
    assert definition.display_name == "Venom Splasher"
    assert definition.max_level == 10
    assert definition.target_type == :target_enemy
    assert definition.damage_type == :no_damage
    assert definition.requires == []
    assert definition.range == 1
    assert definition.cast_time == List.duplicate(500, 10)
    assert definition.fixed_cast_time == List.duplicate(500, 10)
    assert definition.sp_cost == Enum.to_list(12..30//2)
    assert definition.cooldown == Enum.to_list(11_000..2_000//-1_000)
    assert definition.item_cost == []
    assert definition.hp_cost == []
    assert definition.hp_cost_rate == []
  end

  test "the imported Gaster row resolves to the mob-safe skill" do
    assert %{skill_id: 141, skill: "AS_SPLASHER", level: 5, cast_time: 0, delay: 5_000} =
             Enum.find(Db.rows_for(3_740), &(&1.skill_id == 141))

    assert {:ok, %{requires: []}} = Catalog.by_id(141)
  end

  test "the imported Gaster row reaches the mob terminal ratio through the real executor" do
    target = player_target(4_100)
    register_player(target)

    caster =
      %{mob_target(3_100) | mob_id: 3_740, target_ref: {:player, target.character_id}, sp: 0}

    register_mob(caster)
    assert row = Enum.find(Db.rows_for(caster.mob_id), &(&1.skill_id == 141))

    expect(Combat, :execute_forced_no_card_splash, fn ^caster, {100, 100}, 2, opts ->
      assert opts[:skill_level] == 5
      assert opts[:skill_ratio] == 900
      []
    end)

    expect(SpecialEffect, :play, fn {:player, 4_100}, :splasher -> :ok end)

    assert :ok = Executor.execute(caster, row)

    assert %{
             source_id: 3_100,
             source_type: :mob,
             state: %{remaining_ms: 7_000, poison_react_level: 0}
           } = entry = StatusStorage.get_status(:player, target.character_id, :sc_splasher)

    assert caster.sp == 0
    assert :stop == run_exact_ticks(:player, target.character_id, entry.generation)
    refute StatusStorage.has_status?(:player, target.character_id, :sc_splasher)
  end

  test "a player arms target-owned tickless state with a Poison React snapshot" do
    caster = player_caster(%{139 => 7})
    target = mob_target(2_000)
    register_mob(target)

    assert {:ok, ^caster} =
             AsSplasher.cast(caster, {:unit, target.instance_id}, 3, AsSplasher.definition())

    assert %{
             val1: 3,
             tick: 0,
             next_tick_at: nil,
             source_id: 1_000,
             source_type: :player,
             state: %{remaining_ms: 9_000, poison_react_level: 7}
           } = entry = StatusStorage.get_status(:mob, target.instance_id, :sc_splasher)

    assert is_integer(entry.generation)
    assert entry.expires_at == entry.started_at + 10_500
  end

  test "the real manager chain keeps absolute Splasher deadlines through terminal explosion" do
    source = player_caster(%{})
    register_player(source)

    expect(Combat, :execute_forced_no_card_splash, 2, fn ^source, {100, 100}, 2, opts ->
      assert opts[:skill_ratio] in [500, 1_400]
      []
    end)

    expect(SpecialEffect, :play, 2, fn {:mob, target_id}, :splasher ->
      assert target_id in [2_010, 2_019]
      :ok
    end)

    for {level, target_id} <- [{1, 2_010}, {10, 2_019}] do
      target = mob_target(target_id)
      register_mob(target)
      countdown_ms = (12 - level) * 1_000

      :ok =
        StatusInterpreter.apply_status(:mob, target_id, :sc_splasher,
          val1: level,
          duration: countdown_ms + 1_500,
          caster_id: source.character_id,
          source_type: :player,
          state: %{remaining_ms: countdown_ms, poison_react_level: 0}
        )

      backdated_start = System.monotonic_time(:millisecond) - 20_000

      :ok =
        StatusStorage.update_status(:mob, target_id, :sc_splasher, fn entry ->
          %{entry | started_at: backdated_start}
        end)

      entry = StatusStorage.get_status(:mob, target_id, :sc_splasher)
      first_due = entry.started_at + 1_000
      state = %StatusTickManager.State{}

      assert {:noreply, ^state} =
               StatusTickManager.handle_cast(
                 {:schedule_exact_tick, :mob, target_id, :sc_splasher, entry.generation,
                  first_due},
                 state
               )

      assert_receive {:exact_status_tick, :mob, ^target_id, :sc_splasher, _, ^first_due} = message

      assert drive_manager_ticks(message, state, first_due) ==
               entry.started_at + countdown_ms + 500

      refute StatusStorage.has_status?(:mob, target_id, :sc_splasher)
      refute_receive {:exact_status_tick, :mob, ^target_id, :sc_splasher, _, _}
    end
  end

  test "the player cast path commits only SP and the DB cooldown after arming" do
    caster = player_caster(%{139 => 6, 141 => 3})
    target = mob_target(2_025)
    register_mob(target)
    now = System.monotonic_time(:millisecond)

    assert {:ok, updated} =
             SkillInterpreter.complete_cast(caster, 141, 3, {:unit, target.instance_id})

    assert updated.stats.current_state.sp == 84
    assert updated.inventory == caster.inventory
    assert updated.skill_cooldowns[141] in (now + 8_500)..(now + 9_500)

    assert %{state: %{poison_react_level: 6}} =
             StatusStorage.get_status(:mob, target.instance_id, :sc_splasher)
  end

  test "a mob arm stores no player passive contribution or resource obligation" do
    target = player_target(4_000)
    register_player(target)

    caster = %MobState{
      instance_id: 3_000,
      mob_id: 3_740,
      mob_data: %{skill_range: 1},
      spawn_ref: nil,
      map_name: "prontera",
      x: 99,
      y: 100,
      hp: 100,
      max_hp: 100,
      sp: 0,
      max_sp: 0,
      spawned_at: 0
    }

    assert {:ok, ^caster} =
             AsSplasher.cast(caster, {:unit, target.character_id}, 5, AsSplasher.definition())

    assert %{
             source_id: 3_000,
             source_type: :mob,
             state: %{remaining_ms: 7_000, poison_react_level: 0}
           } = StatusStorage.get_status(:player, target.character_id, :sc_splasher)
  end

  test "replacement and every ordinary cleanup path leave exact timers stale" do
    caster = player_caster(%{139 => 4})
    target = mob_target(2_050)
    register_mob(target)

    assert {:ok, ^caster} =
             AsSplasher.cast(caster, {:unit, target.instance_id}, 2, AsSplasher.definition())

    first = StatusStorage.get_status(:mob, target.instance_id, :sc_splasher)

    assert {:ok, ^caster} =
             AsSplasher.cast(caster, {:unit, target.instance_id}, 3, AsSplasher.definition())

    current = StatusStorage.get_status(:mob, target.instance_id, :sc_splasher)
    assert current.generation > first.generation

    assert :stop =
             StatusInterpreter.process_tick_if_current(
               :mob,
               target.instance_id,
               :sc_splasher,
               first.generation
             )

    cleanup_paths = [
      fn -> StatusInterpreter.remove_status(:mob, target.instance_id, :sc_splasher) end,
      fn -> StatusInterpreter.remove_on_death(:mob, target.instance_id) end,
      fn -> StatusInterpreter.remove_on_map_change(:mob, target.instance_id) end,
      fn -> StatusInterpreter.remove_all_statuses(:mob, target.instance_id) end,
      fn -> Dispel.dispel({:mob, target.instance_id}) end
    ]

    Enum.each(cleanup_paths, fn cleanup ->
      assert {:ok, ^caster} =
               AsSplasher.cast(caster, {:unit, target.instance_id}, 3, AsSplasher.definition())

      generation = StatusStorage.get_status(:mob, target.instance_id, :sc_splasher).generation
      assert :ok = cleanup.()
      assert StatusStorage.get_status(:mob, target.instance_id, :sc_splasher) == nil

      assert :stop =
               StatusInterpreter.process_tick_if_current(
                 :mob,
                 target.instance_id,
                 :sc_splasher,
                 generation
               )
    end)
  end

  test "only one natural current-generation terminal tick explodes" do
    caster = player_caster(%{139 => 10})
    target = mob_target(2_060)
    register_player(caster)
    register_mob(target)

    assert {:ok, ^caster} =
             AsSplasher.cast(caster, {:unit, target.instance_id}, 10, AsSplasher.definition())

    StatusStorage.update_status(:mob, target.instance_id, :sc_splasher, fn entry ->
      %{entry | state: %{entry.state | remaining_ms: 500}}
    end)

    entry = StatusStorage.get_status(:mob, target.instance_id, :sc_splasher)

    expect(Combat, :execute_forced_no_card_splash, fn ^caster, {100, 100}, 2, opts ->
      assert opts[:skill_ratio] == 1_600
      []
    end)

    expect(SpecialEffect, :play, fn {:mob, 2_060}, :splasher -> :ok end)

    assert :stop =
             StatusInterpreter.process_tick_if_current(
               :mob,
               target.instance_id,
               :sc_splasher,
               entry.generation
             )

    assert StatusStorage.get_status(:mob, target.instance_id, :sc_splasher) == nil

    assert :stop =
             StatusInterpreter.process_tick_if_current(
               :mob,
               target.instance_id,
               :sc_splasher,
               entry.generation
             )
  end

  test "an exact tick cleans a target lost outside ordinary session teardown" do
    caster = player_caster(%{139 => 1})
    target = mob_target(2_075)
    register_mob(target)

    assert {:ok, ^caster} =
             AsSplasher.cast(caster, {:unit, target.instance_id}, 1, AsSplasher.definition())

    generation = StatusStorage.get_status(:mob, target.instance_id, :sc_splasher).generation
    :ok = UnitRegistry.unregister_unit(:mob, target.instance_id)

    assert :stop =
             StatusInterpreter.process_tick_if_current(
               :mob,
               target.instance_id,
               :sc_splasher,
               generation
             )

    assert StatusStorage.get_status(:mob, target.instance_id, :sc_splasher) == nil
  end

  test "validation rejects dead and status-immune targets" do
    dead = %{mob_target(2_100) | hp: 0, is_dead: true}
    register_mob(dead)

    assert {:error, :invalid_target} =
             AsSplasher.validate(
               player_caster(%{}),
               {:unit, dead.instance_id},
               1,
               AsSplasher.definition()
             )

    immune = mob_target(2_101)
    immune = %{immune | mob_data: %{immune.mob_data | modes: [:status_immune]}}
    register_mob(immune)

    assert {:error, :invalid_target} =
             AsSplasher.validate(
               player_caster(%{}),
               {:unit, immune.instance_id},
               1,
               AsSplasher.definition()
             )
  end

  defp drive_manager_ticks(message, state, due_at) do
    assert {:noreply, ^state} = StatusTickManager.handle_info(message, state)

    case message do
      {:exact_status_tick, unit_type, unit_id, status_id, generation, ^due_at} ->
        case StatusStorage.get_status(unit_type, unit_id, status_id) do
          nil ->
            due_at

          _entry ->
            next_due = due_at + 500

            assert_receive {:exact_status_tick, ^unit_type, ^unit_id, ^status_id, ^generation,
                            ^next_due} = next_message

            drive_manager_ticks(next_message, state, next_due)
        end
    end
  end

  defp run_exact_ticks(unit_type, unit_id, generation) do
    case StatusInterpreter.process_tick_if_current(
           unit_type,
           unit_id,
           :sc_splasher,
           generation
         ) do
      :continue -> run_exact_ticks(unit_type, unit_id, generation)
      :stop -> :stop
    end
  end

  defp player_caster(learned_skills) do
    %PlayerState{
      character_id: 1_000,
      map_name: "prontera",
      action_state: :idle,
      x: 99,
      y: 100,
      stats: %{
        combat_stats: %CombatStats{},
        current_state: %{sp: 100},
        progression: %{learned_skills: learned_skills}
      }
    }
    |> PlayerStateFixture.build()
  end

  defp player_target(character_id) do
    %PlayerState{
      character_id: character_id,
      map_name: "prontera",
      action_state: :idle,
      x: 100,
      y: 100,
      stats: %{
        combat_stats: %CombatStats{},
        current_state: %{hp: 100, sp: 100},
        progression: %{learned_skills: %{}}
      }
    }
    |> PlayerStateFixture.build()
  end

  defp mob_target(instance_id) do
    definition = %MobDefinition{
      id: 1,
      aegis_name: "PORING",
      name: "Poring",
      level: 1,
      hp: 100,
      stats: %{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
      attack_range: 1,
      size: :medium,
      race: :brute,
      element: {:water, 1},
      walk_speed: 200,
      attack_delay: 1_000,
      attack_motion: 500,
      client_attack_motion: 500,
      damage_motion: 500,
      modes: []
    }

    %MobState{
      instance_id: instance_id,
      mob_id: definition.id,
      mob_data: definition,
      spawn_ref: nil,
      map_name: "prontera",
      x: 100,
      y: 100,
      hp: 100,
      max_hp: 100,
      sp: 0,
      max_sp: 0,
      spawned_at: 0
    }
  end

  defp register_mob(mob) do
    :ok = UnitRegistry.register_unit(:mob, mob.instance_id, MobState, mob, self())
    :ok = SpatialIndex.add_unit(:mob, mob.instance_id, mob.x, mob.y, mob.map_name)
  end

  defp register_player(player) do
    :ok = UnitRegistry.register_player(player, self())
    :ok = SpatialIndex.add_player(player.character_id, player.x, player.y, player.map_name)
  end
end
