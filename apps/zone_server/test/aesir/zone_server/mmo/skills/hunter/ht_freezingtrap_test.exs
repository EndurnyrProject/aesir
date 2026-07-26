defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.HtFreezingtrapTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.TrapState
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.HtFreezingtrap
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  test "Water damage overrides a Fire endow and cannot crit at maximum CRI" do
    attacker = CombatTestHelper.create_player_combatant(luk: 300)
    defender = CombatTestHelper.create_mob_combatant(element: {:fire, 1}, def: 0)

    stub(ModifierCalculator, :get_all_modifiers, fn
      :player, 1001 -> %{attack_element: :fire}
      _, _ -> %{}
    end)

    :rand.seed(:exsss, {1, 2, 3})

    assert {:ok, %{damage: fire_damage}} =
             DamageCalculator.calculate_damage(attacker, defender, skip_crit: true)

    :rand.seed(:exsss, {1, 2, 3})

    assert {:ok, %{damage: water_damage, is_critical: false}} =
             DamageCalculator.calculate_damage(attacker, defender,
               element: :water,
               skip_crit: true
             )

    assert water_damage > fire_damage
  end

  defp group(attrs \\ []) do
    struct(
      %Group{
        group_id: 1,
        skill_id: 121,
        skill_name: :ht_freezingtrap,
        level: 3,
        caster_id: 1000,
        caster_type: :player,
        map_name: "prontera",
        center: {50, 50},
        cells: [{50, 50}],
        next_tick_at: 0,
        expires_at: 0,
        interval: 1_000,
        state: %{}
      },
      attrs
    )
  end

  test "declares the exact definition and typed lifecycle" do
    definition = HtFreezingtrap.definition()
    assert definition.id == 121
    assert definition.max_level == 5
    assert definition.sp_cost == [10, 10, 10, 10, 10]
    assert definition.item_cost == [%{id: 1065, amount: 2}]
    assert definition.unit_duration == [150_000, 120_000, 90_000, 60_000, 30_000]

    assert {:ok, placement} = HtFreezingtrap.on_place(group())
    refute placement.visible?
    assert placement.cells == [{50, 50}]

    assert %TrapState{phase: :armed, natural_expiry: :drop_item, claymore_spendable?: true} =
             placement.state.trap
  end

  test "damages an activator-centered 3x3 area before freezing connected targets" do
    test_pid = self()
    caster = %PlayerState{character_id: 1000, map_name: "prontera", x: 50, y: 50}

    stub(UnitRegistry, :get_unit, fn :player, 1000 ->
      {:ok, {PlayerState, caster, self()}}
    end)

    expect(SpatialIndex, :get_unit_position, fn :mob, 2001 -> {:ok, {60, 70, "prontera"}} end)

    expect(Combat, :execute_splash_attack, fn ^caster, {60, 70}, 1, opts ->
      assert opts[:skill_id] == 121
      assert opts[:skill_level] == 3
      assert opts[:skill_ratio] == 100
      assert opts[:element] == :water
      assert opts[:ignore_flee]
      assert opts[:skip_crit]
      send(test_pid, :damage_connected)
      [2001, 2002]
    end)

    expect(StatusInterpreter, :apply_status, 2, fn :mob, id, :sc_freeze, params ->
      send(test_pid, {:freeze_attempt, id})
      assert id in [2001, 2002]
      assert params[:duration] == 9_000
      assert params[:caster_id] == 1000
      assert params[:source_type] == :player
      :ok
    end)

    assert :expire = HtFreezingtrap.on_touch(group(), {:mob, 2001})
    assert_received :damage_connected
    assert_received {:freeze_attempt, 2001}
    assert_received {:freeze_attempt, 2002}
  end

  test "mob-owned trap damages players and freezes only connected hits" do
    caster = %MobState{
      instance_id: 1000,
      mob_id: 1002,
      mob_data: %{element: {:neutral, 1}, race: :formless, modes: []},
      spawn_ref: nil,
      map_name: "prontera",
      x: 50,
      y: 50,
      hp: 100,
      max_hp: 100,
      sp: 10,
      max_sp: 10,
      spawned_at: 0
    }

    stub(UnitRegistry, :get_unit, fn :mob, 1000 -> {:ok, {MobState, caster, self()}} end)
    stub(SpatialIndex, :get_unit_position, fn :player, 2001 -> {:ok, {51, 50, "prontera"}} end)
    stub(Combat, :execute_splash_attack, fn ^caster, {51, 50}, 1, _opts -> [2002] end)

    expect(StatusInterpreter, :apply_status, fn :player, 2002, :sc_freeze, params ->
      assert params[:source_type] == :mob
      :ok
    end)

    assert :expire =
             HtFreezingtrap.on_touch(group(caster_type: :mob, level: 5), {:player, 2001})
  end

  test "same-side contact and unavailable combatants leave the trap armed" do
    reject(&Combat.execute_splash_attack/4)
    reject(&StatusInterpreter.apply_status/4)

    assert {:ok, %Group{}} = HtFreezingtrap.on_touch(group(), {:player, 2001})

    stub(UnitRegistry, :get_unit, fn :player, 1000 -> :error end)
    assert {:ok, %Group{}} = HtFreezingtrap.on_touch(group(), {:mob, 2001})
  end
end
