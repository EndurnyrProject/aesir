defmodule Aesir.ZoneServer.Mmo.Skills.Dancer.DcWinkcharmTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Dancer.DcWinkcharm
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @caster_id 1_000
  @target_id 2_000

  setup :verify_on_exit!
  setup :set_mimic_from_context
  setup :setup_ets_tables

  setup do
    Catalog.reload()
    :ok
  end

  test "definition matches the pinned Wink of Charm data and platinum grant name" do
    assert {:ok, DcWinkcharm} = Catalog.active_module_for(:dc_winkcharm)
    assert {:ok, definition} = Catalog.by_id(1011)

    assert definition.name == :dc_winkcharm
    assert definition.max_level == 1
    assert definition.target_type == :target_any
    assert definition.damage_type == :no_damage
    assert definition.range == 9
    assert definition.sp_cost == [40]
    assert definition.cast_time == [800]
    assert definition.fixed_cast_time == [200]
    assert definition.after_cast_delay == [2_000]
    assert definition.cooldown == [10_000]
    assert definition.duration == [10_000]
    assert definition.quest_skill
    assert definition.quest_owner_job == :dancer

    platinum_source =
      Path.expand(
        "../../../../../../lib/aesir/zone_server/content/npc/functions/f_getplatinumskills.ex",
        __DIR__
      )
      |> File.read!()

    assert platinum_source =~ "skill(ctx, :dc_winkcharm, 1, :permanent)"
  end

  test "a Demihuman boss is rejected by the separate boss gate before race resolution" do
    target = register_mob([:boss], :demi_human)
    reject(&Combat.resolve_combatant/1)

    assert {:error, :boss_immune} =
             DcWinkcharm.validate(
               %PlayerState{character_id: @caster_id},
               {:unit, target.instance_id},
               1,
               nil
             )
  end

  test "an ineligible race is rejected before effect resolution" do
    target = register_mob([], :formless)

    assert {:error, :invalid_target_race} =
             DcWinkcharm.validate(
               %PlayerState{character_id: @caster_id},
               {:unit, target.instance_id},
               1,
               nil
             )
  end

  test "Demon, Demihuman, Angel, player-human, and Doram races are eligible" do
    Enum.each([:demon, :demi_human, :angel, :player_human, :player_doram], fn race ->
      target = register_mob([], race)

      assert :ok =
               DcWinkcharm.validate(
                 %PlayerState{character_id: @caster_id},
                 {:unit, target.instance_id},
                 1,
                 nil
               )
    end)
  end

  test "monster charm uses caster level minus target level plus 40 and stores the caster id" do
    target = register_mob([], :demon)
    caster = player_state(50)

    expect(StatusInterpreter, :apply_status, fn :mob, @target_id, :sc_winkcharm, params ->
      assert params == [duration: 10_000, success_rate: 65, caster_id: @caster_id]
      :ok
    end)

    assert {:ok, ^caster} = DcWinkcharm.cast(caster, {:unit, target.instance_id}, 1, definition())
  end

  test "a player target is rejected today by the PvP targeting seam" do
    target = register_player_target()

    stub(Combat, :resolve_combatant, fn @target_id ->
      {:ok, %{race: :player_human, progression: %{base_level: 25}}}
    end)

    assert {:error, :invalid_target} =
             DcWinkcharm.validate(player_state(50), {:unit, target.character_id}, 1, definition())
  end

  test "a self target is rejected without raising" do
    assert {:error, :invalid_target} =
             DcWinkcharm.validate(player_state(50), :self, 1, definition())
  end

  test "an unsupported ground target is rejected without raising" do
    assert {:error, :invalid_target} =
             DcWinkcharm.validate(player_state(50), {:ground, 10, 10}, 1, definition())
  end

  test "the player branch applies Confusion only when reached behind the PvP seam" do
    target = register_player_target()
    caster = player_state(50)

    stub(Combat, :resolve_combatant, fn @target_id ->
      {:ok, %{race: :player_human, progression: %{base_level: 25}}}
    end)

    expect(StatusInterpreter, :apply_status, fn :player, @target_id, :sc_confusion, params ->
      assert params == [duration: 10_000, success_rate: 100, caster_id: @caster_id]
      :ok
    end)

    assert {:ok, ^caster} =
             DcWinkcharm.cast(caster, {:unit, target.character_id}, 1, definition())
  end

  defp register_player_target do
    target = %PlayerState{
      character_id: @target_id,
      action_state: :idle,
      stats: %{current_state: %{hp: 100}}
    }

    :ok = UnitRegistry.register_unit(:player, @target_id, PlayerState, target, self())
    target
  end

  defp player_state(base_level) do
    %PlayerState{
      character_id: @caster_id,
      stats: %Stats{progression: %PlayerProgression{base_level: base_level}}
    }
  end

  defp definition do
    {:ok, definition} = Catalog.by_id(1011)
    definition
  end

  defp register_mob(modes, race) do
    mob_data = %MobDefinition{
      id: 1_002,
      aegis_name: "TEST_MOB",
      name: "Test Mob",
      level: 25,
      hp: 1_000,
      sp: 100,
      stats: %{str: 40, agi: 30, vit: 50, int: 20, dex: 35, luk: 15},
      atk: 50,
      matk: 60,
      def: 25,
      mdef: 10,
      attack_range: 1,
      skill_range: 9,
      chase_range: 12,
      walk_speed: 200,
      attack_delay: 1_200,
      attack_motion: 500,
      client_attack_motion: 400,
      damage_motion: 300,
      element: {:neutral, 1},
      race: race,
      size: :medium,
      modes: modes
    }

    spawn_ref = %MobSpawn{
      mob: 1_002,
      amount: 1,
      respawn_time: 5_000,
      spawn_area: %SpawnArea{x: 11, y: 10}
    }

    state = MobState.new(@target_id, mob_data, spawn_ref, "prontera", 11, 10)
    UnitRegistry.register_unit(:mob, @target_id, MobState, state, self())
    :ok = SpatialIndex.update_unit_position(:mob, @target_id, 11, 10, "prontera")
    state
  end
end
