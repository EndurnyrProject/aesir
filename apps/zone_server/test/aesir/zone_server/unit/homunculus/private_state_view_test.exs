defmodule Aesir.ZoneServer.Unit.Homunculus.PrivateStateViewTest do
  use ExUnit.Case, async: true

  alias Aesir.Net.HomunculusAiSkillConfig
  alias Aesir.Net.HomunculusCooldown
  alias Aesir.Net.HomunculusHpRange
  alias Aesir.Net.HomunculusHpThreshold
  alias Aesir.ZoneServer.Mmo.Homunculus.Ai.Config
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Homunculus.PrivateStateView
  alias Aesir.ZoneServer.Unit.Homunculus.Runtime

  test "projects every owner-private field with deterministic skills, cooldowns, and AI" do
    now = 10_000
    state = active_state()

    runtime = %Runtime{
      private_dirty: true,
      clocks_online: true,
      active_deadline_ms: now + 12_345,
      active_expiry_timer_ref: make_ref(),
      cooldown_timer_ref: make_ref(),
      checkpoint_timer_ref: make_ref(),
      movement_path: [{1, 2}]
    }

    packet = PrivateStateView.build(state, runtime, now)

    assert packet.durable_id == 42
    assert packet.world_gid == 70_001
    assert packet.name == "Hildr"
    assert packet.rename_eligible
    assert packet.species_id == 6_001
    refute packet.evolved
    assert packet.appearance_id == 6_001
    assert packet.lifecycle == :HOMUNCULUS_LIFECYCLE_ACTIVE
    assert packet.activity == :HOMUNCULUS_ACTIVITY_CASTING
    assert packet.current_target_id == 77
    assert packet.level == 50
    assert packet.exp == 123
    assert packet.next_exp > 0
    assert packet.skill_points == 1
    assert {packet.hp, packet.max_hp, packet.sp, packet.max_sp} == {900, 1_000, 150, 200}

    assert packet.stats == %Aesir.Net.HomunculusDisplayedStats{
             str: 11,
             agi: 12,
             vit: 13,
             int: 14,
             dex: 15,
             luk: 16,
             atk: 101,
             matk: 102,
             def: 103,
             mdef: 104,
             hit: 105,
             flee: 106,
             critical: 107,
             aspd: 130
           }

    assert packet.hunger == 20
    assert packet.intimacy_hundredths == 92_000
    assert packet.intimacy_grade == :HOMUNCULUS_INTIMACY_GRADE_LOYAL
    assert packet.food_item_id == 537
    assert packet.active_remaining_ms == 12_345

    assert Enum.map(packet.skills, & &1.skill_id) == [8_001, 8_002, 8_003, 8_004]
    assert Enum.map(packet.skills, & &1.level) == [3, 0, 0, 0]
    assert Enum.map(packet.skills, & &1.max_level) == [5, 5, 5, 3]
    assert Enum.map(packet.skills, & &1.learnable) == [true, true, false, false]
    assert List.last(packet.skills).intimacy_required_hundredths == 91_000

    assert packet.cooldowns == [
             %HomunculusCooldown{skill_id: 8_001, remaining_ms: 2_000},
             %HomunculusCooldown{skill_id: 8_003, remaining_ms: 5_000}
           ]

    assert packet.ai_config.stance == :HOMUNCULUS_AI_STANCE_AGGRESSIVE
    assert packet.ai_config.allowed_mob_class_ids == [1_001, 1_002]
    assert packet.ai_config.denied_mob_class_ids == [1_003, 1_004]

    assert packet.ai_config.skills == [
             %HomunculusAiSkillConfig{
               skill_id: 8_001,
               mode: :HOMUNCULUS_AI_SKILL_MODE_AUTO,
               priority: 10,
               self_hp_threshold: %HomunculusHpThreshold{percent: 30},
               owner_hp_threshold: nil,
               target_hp_range: %HomunculusHpRange{min_percent: 20, max_percent: 80}
             },
             %HomunculusAiSkillConfig{
               skill_id: 8_003,
               mode: :HOMUNCULUS_AI_SKILL_MODE_MANUAL,
               priority: 50,
               self_hp_threshold: nil,
               owner_hp_threshold: nil,
               target_hp_range: nil
             }
           ]
  end

  test "projects active, rested, and dead clocks without runtime leakage" do
    active = active_state()
    offline = %Runtime{private_dirty: false}

    assert PrivateStateView.build(%{active | world_gid: nil}, offline, 100).active_remaining_ms ==
             99_999

    rested = %{
      active
      | lifecycle: :rested,
        world_gid: nil,
        action_state: :idle,
        active_remaining_ms: 0,
        cooldowns: %{8_001 => 321}
    }

    rested_packet = PrivateStateView.build(rested, offline, 100)
    assert rested_packet.lifecycle == :HOMUNCULUS_LIFECYCLE_RESTED
    assert rested_packet.activity == :HOMUNCULUS_ACTIVITY_IDLE
    assert rested_packet.world_gid == 0
    assert rested_packet.active_remaining_ms == 0
    assert rested_packet.cooldowns == [%HomunculusCooldown{skill_id: 8_001, remaining_ms: 321}]

    dead = %{rested | lifecycle: :dead, hp: 0, action_state: :dead}
    dead_packet = PrivateStateView.build(dead, offline, 100)
    assert dead_packet.lifecycle == :HOMUNCULUS_LIFECYCLE_DEAD
    assert dead_packet.activity == :HOMUNCULUS_ACTIVITY_UNSPECIFIED
  end

  test "uses the max-level next-EXP sentinel" do
    packet = PrivateStateView.build(%{active_state() | level: 99}, %Runtime{private_dirty: false})
    assert packet.next_exp == 0
  end

  test "contains only protocol fields and no process, timer, queue, or publication internals" do
    packet = PrivateStateView.build(active_state(), %Runtime{private_dirty: false})
    keys = packet |> Map.from_struct() |> Map.keys() |> MapSet.new()

    assert keys ==
             MapSet.new([
               :durable_id,
               :world_gid,
               :name,
               :rename_eligible,
               :species_id,
               :evolved,
               :appearance_id,
               :lifecycle,
               :activity,
               :current_target_id,
               :level,
               :exp,
               :next_exp,
               :skill_points,
               :hp,
               :max_hp,
               :sp,
               :max_sp,
               :stats,
               :hunger,
               :intimacy_hundredths,
               :intimacy_grade,
               :food_item_id,
               :active_remaining_ms,
               :skills,
               :cooldowns,
               :ai_config,
               :__uf__
             ])

    inspected = inspect(packet)
    refute inspected =~ "owner_session_pid"
    refute inspected =~ "timer_ref"
    refute inspected =~ "movement_path"
    refute inspected =~ "private_dirty"
    refute inspected =~ "queue"
  end

  defp active_state do
    config = %Config{
      stance: :aggressive,
      leash_distance: 12,
      join_owner_target: false,
      retaliate: true,
      avoid_bosses: false,
      allowed_mob_class_ids: [1_002, 1_001],
      denied_mob_class_ids: [1_004, 1_003],
      auto_feed: true,
      auto_feed_threshold: 20,
      auto_cast_sp_reserve_percent: 30,
      skills: %{
        8_003 => %{
          mode: :manual,
          priority: 50,
          self_hp_threshold: nil,
          owner_hp_threshold: nil,
          target_hp_range: nil
        },
        8_001 => %{
          mode: :auto,
          priority: 10,
          self_hp_threshold: 30,
          owner_hp_threshold: nil,
          target_hp_range: %{min_percent: 20, max_percent: 80}
        }
      }
    }

    %HomunculusState{
      id: 42,
      owner_character_id: 7,
      owner_session_pid: self(),
      class_id: 6_001,
      name: "Hildr",
      rename_available: true,
      lifecycle: :active,
      level: 50,
      exp: 123,
      skill_points: 1,
      hp: 900,
      max_hp: 1_000,
      sp: 150,
      max_sp: 200,
      str: 11,
      agi: 12,
      vit: 13,
      int: 14,
      dex: 15,
      luk: 16,
      hunger: 20,
      intimacy_hundredths: 92_000,
      active_remaining_ms: 99_999,
      learned_skills: %{8_001 => 3},
      cooldowns: %{8_003 => 15_000, 8_001 => 12_000},
      ai_config: config,
      world_gid: 70_001,
      map_name: "private_view_test",
      x: 10,
      y: 20,
      dir: 2,
      action_state: :casting,
      target: {:mob, 77},
      attack_delay_ms: 700,
      combat_stats: %{
        atk: 101,
        matk: 102,
        def: 103,
        mdef: 104,
        hit: 105,
        flee: 106,
        critical: 107,
        perfect_dodge: 0,
        matk_min: 0,
        matk_max: 0,
        soft_mdef: 0
      }
    }
  end
end
