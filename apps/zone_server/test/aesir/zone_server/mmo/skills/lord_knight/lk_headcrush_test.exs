defmodule Aesir.ZoneServer.Mmo.Skills.LordKnight.LkHeadcrushTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.LordKnight.LkHeadcrush
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :set_mimic_from_context
  setup :verify_on_exit!

  test "a boss is refused before the attack spends SP" do
    boss = mob([:boss])
    caster = %PlayerState{character_id: 5_130}
    {:ok, definition} = Catalog.by_name(:lk_headcrush)
    stub(TargetResolver, :resolve, fn 6_130 -> {:ok, self(), boss, :mob} end)
    reject(&Combat.execute_skill_attack/3)

    assert {:error, :boss_immune} =
             LkHeadcrush.validate(caster, {:unit, 6_130}, 5, definition)
  end

  @tag game_mode: :renewal
  test "a landed strike bleeds a normal mob for 108 seconds in Renewal" do
    assert_bleed_duration(108_000)
  end

  @tag game_mode: :pre_renewal
  test "a landed strike bleeds a normal mob for 120 seconds in classic" do
    assert_bleed_duration(120_000)
  end

  test "undead-element, undead-race, and demon targets never bleed" do
    caster = %PlayerState{character_id: 5_130}
    {:ok, definition} = Catalog.by_name(:lk_headcrush)

    targets = %{
      6_130 => CombatTestHelper.create_mob_combatant(unit_id: 6_130, element: {:undead, 1}),
      6_131 => CombatTestHelper.create_mob_combatant(unit_id: 6_131, race: :undead),
      6_132 => CombatTestHelper.create_mob_combatant(unit_id: 6_132, race: :demon)
    }

    stub(Combat, :resolve_combatant, fn id -> {:ok, Map.fetch!(targets, id)} end)
    stub(Combat, :execute_skill_attack, fn _caster, _target, _opts -> {:ok, %{hit?: true}} end)
    reject(&StatusInterpreter.apply_status/4)

    for id <- Map.keys(targets) do
      assert {:ok, ^caster} = LkHeadcrush.cast(caster, {:unit, id}, 5, definition)
    end
  end

  test "a missed strike never applies Bleeding" do
    caster = %PlayerState{character_id: 5_130}
    {:ok, definition} = Catalog.by_name(:lk_headcrush)
    stub(Combat, :execute_skill_attack, fn _caster, 6_130, _opts -> {:ok, %{hit?: false}} end)
    reject(&Combat.resolve_combatant/1)
    reject(&StatusInterpreter.apply_status/4)

    assert {:ok, ^caster} = LkHeadcrush.cast(caster, {:unit, 6_130}, 5, definition)
  end

  test "a level five strike deals 300 percent weapon damage with no criticals" do
    assert {:ok, definition} = Catalog.by_name(:lk_headcrush)
    assert definition.id == 398
    assert definition.range == 4
    assert definition.sp_cost == List.duplicate(23, 5)
    caster = %PlayerState{character_id: 5_130}

    stub(Combat, :resolve_combatant, fn 6_130 ->
      {:ok, CombatTestHelper.create_mob_combatant(unit_id: 6_130)}
    end)

    expect(Combat, :execute_skill_attack, fn ^caster, 6_130, opts ->
      assert opts[:skill_id] == 398
      assert opts[:skill_level] == 5
      assert opts[:skill_ratio] == 300
      assert opts[:skip_crit] == true
      assert opts[:skip_range] == true
      assert opts[:report_hit] == true
      {:ok, %{hit?: false}}
    end)

    assert {:ok, ^caster} = LkHeadcrush.cast(caster, {:unit, 6_130}, 5, definition)
  end

  defp assert_bleed_duration(expected_duration) do
    caster = %PlayerState{character_id: 5_130}
    {:ok, definition} = Catalog.by_name(:lk_headcrush)
    target_ref = {:mob, 6_130}

    stub(Combat, :resolve_combatant, fn ^target_ref ->
      {:ok, CombatTestHelper.create_mob_combatant(unit_id: 6_130)}
    end)

    stub(Combat, :execute_skill_attack, fn _caster, ^target_ref, _opts ->
      {:ok, %{hit?: true}}
    end)

    expect(StatusInterpreter, :apply_status, fn :mob, 6_130, :sc_bleeding, params ->
      assert params[:val1] == 5
      assert params[:duration] == expected_duration
      assert params[:caster_id] == caster.character_id
      assert params[:source_type] == :player
      :ok
    end)

    :rand.seed(:exsss, {2, 3, 4})
    assert {:ok, ^caster} = LkHeadcrush.cast(caster, {:unit, target_ref}, 5, definition)
  end

  defp mob(modes) do
    data = %MobDefinition{
      id: 1002,
      aegis_name: "test_mob",
      name: "Test Mob",
      level: 10,
      hp: 100,
      stats: %{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
      attack_range: 1,
      size: :medium,
      race: :brute,
      element: {:earth, 1},
      walk_speed: 200,
      attack_delay: 1_000,
      attack_motion: 500,
      client_attack_motion: 400,
      damage_motion: 300,
      modes: modes
    }

    spawn = %MobSpawn{
      mob: 1002,
      amount: 1,
      respawn_time: 5_000,
      spawn_area: %SpawnArea{x: 150, y: 150}
    }

    MobState.new(6_130, data, spawn, "prontera", 150, 150)
  end
end
