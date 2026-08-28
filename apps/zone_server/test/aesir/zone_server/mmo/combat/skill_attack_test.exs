defmodule Aesir.ZoneServer.Mmo.Combat.SkillAttackTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Mmo.Combat.AttackValidator
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.EquipAutocast
  alias Aesir.ZoneServer.Mmo.Combat.EquipComa
  alias Aesir.ZoneServer.Mmo.Combat.EquipVanish
  alias Aesir.ZoneServer.Mmo.Combat.Knockback
  alias Aesir.ZoneServer.Mmo.Combat.OnHitEffects
  alias Aesir.ZoneServer.Mmo.Combat.SkillAttack
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  defmodule TestUnit do
    defstruct [:combatant, :hp, :x, :y]

    def to_combatant(%__MODULE__{combatant: combatant}), do: combatant
    def living?(%__MODULE__{hp: hp}), do: hp > 0
    def is_boss?(%__MODULE__{}), do: false
  end

  defmodule HpLessUnit do
    defstruct [:combatant]

    def to_combatant(%__MODULE__{combatant: combatant}), do: combatant
    def living?(%__MODULE__{}), do: true
    def is_boss?(%__MODULE__{}), do: false
  end

  setup :set_mimic_from_context
  setup :verify_on_exit!
  setup :setup_ets_tables

  setup do
    Mimic.copy(Cell)
    Mimic.copy(MapCache)
    Mimic.copy(EquipAutocast)
    Mimic.copy(EquipComa)
    Mimic.copy(EquipVanish)
    Mimic.copy(Knockback)
    Mimic.copy(OnHitEffects)
    :ok
  end

  test "streams every multi-hit fragment through delivery before calculating the next" do
    attacker =
      CombatTestHelper.create_player_combatant(
        unit_id: 1001,
        position: {100, 100},
        attack_range: 1
      )

    target = CombatTestHelper.create_mob_combatant(unit_id: 2001, position: {101, 100})
    caster_state = %TestUnit{combatant: attacker, hp: 100}
    target_state = %TestUnit{combatant: target, hp: 1_000}
    test_pid = self()

    stub(TargetResolver, :resolve, fn {:mob, 2001} ->
      {:ok, self(), target_state, :mob}
    end)

    stub(TargetResolver, :ensure_targetable, fn ^target_state, :mob -> :ok end)
    stub(AttackValidator, :validate, fn ^attacker, ^target, _opts -> :ok end)
    stub(Targeting, :validate_enemy, fn ^attacker, ^target -> :ok end)
    stub(StatusInterpreter, :before_weapon_hit, fn :mob, 2001, _attack_info -> :continue end)

    expect(DamageCalculator, :calculate_damage, 3, fn ^attacker, ^target, _opts ->
      fragment = Process.get(:fragment, 0) + 1
      Process.put(:fragment, fragment)
      send(test_pid, {:event, {:calculate, fragment}})
      {:ok, %{damage: 40, is_critical: false}}
    end)

    expect(EquipComa, :trigger?, fn ^attacker, ^target ->
      send(test_pid, {:event, {:coma, Process.get(:fragment)}})
      false
    end)

    stub(EquipVanish, :after_hit, fn ^attacker, ^target, _pid, _flag ->
      send(test_pid, {:event, {:vanish, Process.get(:fragment)}})
      :ok
    end)

    stub(StatusInterpreter, :absorb_damage, fn :mob, 2001, 40, _hit_info ->
      send(test_pid, {:event, {:prepare, Process.get(:fragment)}})
      40
    end)

    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet ->
      send(test_pid, {:event, {:packet, Process.get(:fragment)}})
      :ok
    end)

    stub(MobSession, :apply_damage, fn _pid, 40, 1001 ->
      send(test_pid, {:event, {:damage, Process.get(:fragment)}})
      :ok
    end)

    stub(StatusInterpreter, :after_damage_taken, fn :mob, 2001, _hit_info ->
      send(test_pid, {:event, {:after_damage, Process.get(:fragment)}})
      0
    end)

    stub(OnHitEffects, :after_hit, fn ^attacker, ^target, _result, _opts ->
      send(test_pid, {:event, {:on_hit, Process.get(:fragment)}})
      :ok
    end)

    stub(EquipAutocast, :on_attack, fn ^attacker, ^target, _flag ->
      send(test_pid, {:event, {:attacker_autocast, Process.get(:fragment)}})
      []
    end)

    stub(EquipAutocast, :when_hit, fn ^target, ^attacker, _flag ->
      send(test_pid, {:event, {:target_autocast, Process.get(:fragment)}})
      []
    end)

    expect(Knockback, :skill, fn ^attacker, ^target, 7, result, [] ->
      assert result == %{hit?: true, target_survives?: true, coma?: false}
      send(test_pid, {:event, {:knockback, Process.get(:fragment)}})
      :ok
    end)

    assert {:ok, %{hit?: true, damage: 120, target_survives?: true, coma?: false}} =
             SkillAttack.execute_skill_attack(caster_state, {:mob, 2001},
               skill_id: 7,
               skill_level: 1,
               hit_count: 3,
               ignore_flee: true,
               report_hit: true
             )

    assert event_sequence(29) == [
             {:calculate, 1},
             {:coma, 1},
             {:vanish, 1},
             {:prepare, 1},
             {:packet, 1},
             {:damage, 1},
             {:after_damage, 1},
             {:on_hit, 1},
             {:attacker_autocast, 1},
             {:target_autocast, 1},
             {:calculate, 2},
             {:vanish, 2},
             {:prepare, 2},
             {:packet, 2},
             {:damage, 2},
             {:after_damage, 2},
             {:on_hit, 2},
             {:attacker_autocast, 2},
             {:target_autocast, 2},
             {:calculate, 3},
             {:vanish, 3},
             {:prepare, 3},
             {:packet, 3},
             {:damage, 3},
             {:after_damage, 3},
             {:on_hit, 3},
             {:attacker_autocast, 3},
             {:target_autocast, 3},
             {:knockback, 3}
           ]
  end

  test "equipment skill blow displaces a connected zero-damage skill and floors signed totals" do
    attacker = CombatTestHelper.create_player_combatant(unit_id: 1001, position: {100, 100})
    target = CombatTestHelper.create_mob_combatant(unit_id: 2001, position: {101, 100})
    target_state = %TestUnit{combatant: target, hp: 100}
    map_name = target.map_name

    stub(TargetResolver, :resolve, fn {:mob, 2001} ->
      {:ok, self(), target_state, :mob}
    end)

    stub(TargetResolver, :ensure_targetable, fn ^target_state, :mob -> :ok end)
    stub(AttackValidator, :validate, fn _attacker, ^target, _opts -> :ok end)
    stub(Targeting, :validate_enemy, fn _attacker, ^target -> :ok end)
    stub(StatusInterpreter, :before_weapon_hit, fn :mob, 2001, _attack_info -> :continue end)

    stub(DamageCalculator, :calculate_damage, fn _attacker, ^target, _opts ->
      {:ok, %{damage: 0, is_critical: false}}
    end)

    reject(&EquipComa.trigger?/2)
    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)

    stub(MobSession, :apply_damage, fn _pid, 0, 1001 ->
      send(self(), :damage_delivered)
      :ok
    end)

    stub(SpatialIndex, :get_unit_position, fn :mob, 2001 ->
      {:ok, {101, 100, map_name}}
    end)

    stub(UnitRegistry, :get_unit, fn :mob, 2001 ->
      {:ok, {TestUnit, target_state, self()}}
    end)

    stub(MapCache, :get, fn ^map_name -> {:ok, :map} end)
    stub(Cell, :step_traversable?, fn ^map_name, _from, _to -> true end)

    cases = [
      {%{{:add_skill_blow, 7} => 2}, [], {103, 100}},
      {%{{:add_skill_blow, 7} => -2}, [base_distance: 1], nil},
      {%{{:add_skill_blow, 7} => -1}, [base_distance: 1], nil}
    ]

    for {equipment, knockback_options, destination} <- cases do
      caster = %TestUnit{combatant: %{attacker | equip_modifiers: equipment}, hp: 100}

      assert :ok =
               SkillAttack.execute_skill_attack(
                 caster,
                 {:mob, 2001},
                 [skill_id: 7, skill_level: 1, ignore_flee: true] ++ knockback_options
               )

      assert_receive :damage_delivered

      if destination do
        {dst_x, dst_y} = destination

        assert_receive {
          :"$gen_cast",
          {:movement, {:displace, 101, 100, ^map_name, ^dst_x, ^dst_y}}
        }
      else
        refute_receive {:"$gen_cast", {:movement, {:displace, _, _, _, _, _}}}
      end
    end
  end

  test "connected HP-less no-report attacks deliver once and retain equipment knockback" do
    attacker =
      CombatTestHelper.create_player_combatant(unit_id: 1001, position: {100, 100})
      |> Map.replace!(:equip_modifiers, %{{:add_skill_blow, 7} => 2})

    target = CombatTestHelper.create_mob_combatant(unit_id: 2001, position: {101, 100})
    caster_state = %TestUnit{combatant: attacker, hp: 100}
    target_state = %HpLessUnit{combatant: target}
    map_name = target.map_name

    stub(TargetResolver, :resolve, fn {:mob, 2001} ->
      {:ok, self(), target_state, :mob}
    end)

    expect(TargetResolver, :ensure_targetable, fn ^target_state, :mob -> :ok end)
    stub(AttackValidator, :validate, fn ^attacker, ^target, _opts -> :ok end)
    stub(Targeting, :validate_enemy, fn ^attacker, ^target -> :ok end)
    stub(StatusInterpreter, :before_weapon_hit, fn :mob, 2001, _attack_info -> :continue end)

    stub(DamageCalculator, :calculate_damage, fn ^attacker, ^target, _opts ->
      {:ok, %{damage: 40, is_critical: false}}
    end)

    expect(EquipComa, :trigger?, fn ^attacker, ^target -> false end)
    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)

    expect(MobSession, :apply_damage, fn _pid, 40, 1001 ->
      send(self(), :damage_delivered)
      :ok
    end)

    stub(SpatialIndex, :get_unit_position, fn :mob, 2001 ->
      {:ok, {101, 100, map_name}}
    end)

    stub(UnitRegistry, :get_unit, fn :mob, 2001 ->
      {:ok, {HpLessUnit, target_state, self()}}
    end)

    stub(MapCache, :get, fn ^map_name -> {:ok, :map} end)
    stub(Cell, :step_traversable?, fn ^map_name, _from, _to -> true end)

    assert :ok =
             SkillAttack.execute_skill_attack(caster_state, {:mob, 2001},
               skill_id: 7,
               skill_level: 1,
               ignore_flee: true,
               base_distance: 4,
               native_requires_survival: true
             )

    assert_received :damage_delivered

    assert_receive {
      :"$gen_cast",
      {:movement, {:displace, 101, 100, ^map_name, 103, 100}}
    }

    refute_receive {:"$gen_cast", {:movement, {:displace, _, _, _, _, _}}}
  end

  test "staged HP-less misses and calculation errors return before delivery" do
    attacker = CombatTestHelper.create_player_combatant(unit_id: 1001, position: {100, 100})

    target =
      CombatTestHelper.create_mob_combatant(unit_id: 2001, position: {101, 100})
      |> Map.update!(:combat_stats, &Map.put(&1, :perfect_dodge, 1_000))

    caster_state = %TestUnit{combatant: attacker, hp: 100}
    target_state = %HpLessUnit{combatant: target}

    stub(TargetResolver, :resolve, fn {:mob, 2001} ->
      {:ok, self(), target_state, :mob}
    end)

    stub(TargetResolver, :ensure_targetable, fn ^target_state, :mob -> :ok end)
    stub(AttackValidator, :validate, fn ^attacker, ^target, _opts -> :ok end)
    stub(Targeting, :validate_enemy, fn ^attacker, ^target -> :ok end)
    stub(StatusInterpreter, :before_weapon_hit, fn :mob, 2001, _attack_info -> :continue end)
    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)

    expect(DamageCalculator, :calculate_damage, fn ^attacker, ^target, _opts ->
      {:error, :failed}
    end)

    reject(&EquipComa.trigger?/2)
    reject(&Knockback.skill/5)
    reject(&MobSession.apply_damage/3)

    assert {:ok, :miss} =
             SkillAttack.prepare_staged_skill_attack(caster_state, {:mob, 2001},
               skill_id: 8_001,
               skill_level: 1
             )

    assert {:error, :failed} =
             SkillAttack.prepare_staged_skill_attack(caster_state, {:mob, 2001},
               skill_id: 8_001,
               skill_level: 1,
               ignore_flee: true
             )
  end

  test "one successful coma decision marks every fragment and guarantees aggregate survival" do
    attacker =
      CombatTestHelper.create_player_combatant(
        unit_id: 1001,
        position: {100, 100},
        attack_range: 1
      )

    target = CombatTestHelper.create_mob_combatant(unit_id: 2001, position: {101, 100})
    caster_state = %TestUnit{combatant: attacker, hp: 100}
    target_state = %TestUnit{combatant: target, hp: 100}

    stub(TargetResolver, :resolve, fn {:mob, 2001} ->
      {:ok, self(), target_state, :mob}
    end)

    stub(TargetResolver, :ensure_targetable, fn ^target_state, :mob -> :ok end)
    stub(AttackValidator, :validate, fn ^attacker, ^target, _opts -> :ok end)
    stub(Targeting, :validate_enemy, fn ^attacker, ^target -> :ok end)
    stub(StatusInterpreter, :before_weapon_hit, fn :mob, 2001, _attack_info -> :continue end)

    expect(DamageCalculator, :calculate_damage, 2, fn ^attacker, ^target, _opts ->
      {:ok, %{damage: 80, is_critical: false}}
    end)

    expect(EquipComa, :trigger?, fn ^attacker, ^target -> true end)

    expect(StatusInterpreter, :absorb_damage, 2, fn :mob, 2001, 80, hit_info ->
      assert hit_info.coma?
      80
    end)

    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)
    reject(&MobSession.apply_damage/3)
    expect(MobSession, :apply_coma, 2, fn _pid, {:player, 1001} -> :ok end)

    expect(Knockback, :skill, fn ^attacker, ^target, 7, result, options ->
      assert result == %{hit?: true, target_survives?: true, coma?: true}

      assert options == [
               base_distance: 3,
               origin: {99, 100},
               native_enabled: false,
               native_target_types: [:player],
               native_requires_survival: true
             ]

      :ok
    end)

    assert {:ok, %{hit?: true, damage: 160, target_survives?: true, coma?: true}} =
             SkillAttack.execute_skill_attack(caster_state, {:mob, 2001},
               skill_id: 7,
               skill_level: 1,
               hit_count: 2,
               ignore_flee: true,
               report_hit: true,
               base_distance: 3,
               origin: {99, 100},
               native_enabled: false,
               native_target_types: [:player],
               native_requires_survival: true
             )
  end

  test "staged physical hits fix coma during preparation and retain it through delayed delivery" do
    attacker = CombatTestHelper.create_player_combatant(unit_id: 1001, position: {100, 100})
    target = CombatTestHelper.create_mob_combatant(unit_id: 2001, position: {101, 100})
    caster_state = %TestUnit{combatant: attacker, hp: 100}
    target_state = %TestUnit{combatant: target, hp: 100}
    test_pid = self()

    stub(TargetResolver, :resolve, fn {:mob, 2001} ->
      {:ok, self(), target_state, :mob}
    end)

    stub(TargetResolver, :ensure_targetable, fn ^target_state, :mob -> :ok end)
    stub(AttackValidator, :validate, fn ^attacker, ^target, _opts -> :ok end)
    stub(Targeting, :validate_enemy, fn ^attacker, ^target -> :ok end)
    stub(StatusInterpreter, :before_weapon_hit, fn :mob, 2001, _attack_info -> :continue end)

    expect(DamageCalculator, :calculate_damage, fn ^attacker, ^target, _opts ->
      {:ok, %{damage: 60, is_critical: false}}
    end)

    expect(EquipComa, :trigger?, fn ^attacker, ^target ->
      send(test_pid, :coma_decided)
      true
    end)

    expect(StatusInterpreter, :absorb_damage, fn :mob, 2001, 60, hit_info ->
      assert hit_info.coma?
      60
    end)

    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)
    reject(&MobSession.apply_damage/3)

    expect(MobSession, :apply_coma, fn _pid, {:player, 1001} ->
      send(test_pid, :coma_delivered)
      :ok
    end)

    expect(Knockback, :skill, fn ^attacker, ^target, 8_001, result, [] ->
      assert result == %{hit?: true, target_survives?: true, coma?: true}
      send(test_pid, :knockback_requested)
      :ok
    end)

    assert {:ok, prepared} =
             SkillAttack.prepare_staged_skill_attack(caster_state, {:mob, 2001},
               skill_id: 8_001,
               skill_level: 1,
               ignore_flee: true
             )

    assert_received :coma_decided
    refute_received :coma_delivered
    refute_received :knockback_requested
    assert :ok = SkillAttack.deliver_prepared_skill_hit(prepared)
    assert_received :coma_delivered
    assert_received :knockback_requested
  end

  test "physical splash targets make independent coma decisions" do
    attacker = CombatTestHelper.create_player_combatant(unit_id: 1001, position: {100, 100})
    first = CombatTestHelper.create_mob_combatant(unit_id: 2001, position: {101, 100})
    second = CombatTestHelper.create_mob_combatant(unit_id: 2002, position: {102, 100})
    caster_state = %TestUnit{combatant: attacker, hp: 100, x: 100, y: 100}
    first_state = %TestUnit{combatant: first, hp: 100, x: 101, y: 100}
    second_state = %TestUnit{combatant: second, hp: 100, x: 102, y: 100}
    test_pid = self()

    stub(SpatialIndex, :get_all_units_in_range, fn "test_map", 100, 100, 4 ->
      [{:mob, 2001}, {:mob, 2002}]
    end)

    stub(TargetResolver, :resolve, fn
      :mob, 2001 -> {:ok, self(), first_state, :mob}
      :mob, 2002 -> {:ok, self(), second_state, :mob}
    end)

    stub(TargetResolver, :resolve, fn
      {:mob, 2001} -> {:ok, self(), first_state, :mob}
      {:mob, 2002} -> {:ok, self(), second_state, :mob}
    end)

    stub(Targeting, :validate_enemy, fn ^attacker, target ->
      assert target.unit_id in [2001, 2002]
      :ok
    end)

    stub(StatusInterpreter, :before_weapon_hit, fn :mob, target_id, _attack_info ->
      assert target_id in [2001, 2002]
      :continue
    end)

    stub(DamageCalculator, :calculate_damage, fn ^attacker, target, _opts ->
      assert target.unit_id in [2001, 2002]
      {:ok, %{damage: 40, is_critical: false}}
    end)

    expect(EquipComa, :trigger?, 2, fn ^attacker, target ->
      send(test_pid, {:coma_decision, target.unit_id})
      target.unit_id == 2001
    end)

    stub(StatusInterpreter, :absorb_damage, fn :mob, target_id, 40, hit_info ->
      assert hit_info.coma? == (target_id == 2001)
      40
    end)

    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)
    expect(MobSession, :apply_coma, fn _pid, {:player, 1001} -> :ok end)
    expect(MobSession, :apply_damage, fn _pid, 40, 1001 -> :ok end)

    expect(Knockback, :skill, 2, fn ^attacker, target, 141, result, [] ->
      assert result == %{
               hit?: true,
               target_survives?: true,
               coma?: target.unit_id == 2001
             }

      send(test_pid, {:knockback, target.unit_id})
      :ok
    end)

    assert [2001, 2002] =
             SkillAttack.execute_splash_attack(caster_state, {100, 100}, 2,
               skill_id: 141,
               skill_level: 10,
               ignore_flee: true
             )

    assert_received {:coma_decision, 2001}
    assert_received {:coma_decision, 2002}
    assert_received {:knockback, 2001}
    assert_received {:knockback, 2002}
  end

  test "interception, failed calculation, and zero damage defer coma until a positive fragment" do
    attacker = CombatTestHelper.create_player_combatant(unit_id: 1001, position: {100, 100})
    target = CombatTestHelper.create_mob_combatant(unit_id: 2001, position: {101, 100})
    caster_state = %TestUnit{combatant: attacker, hp: 100}
    target_state = %TestUnit{combatant: target, hp: 100}
    test_pid = self()

    stub(TargetResolver, :resolve, fn {:mob, 2001} ->
      {:ok, self(), target_state, :mob}
    end)

    stub(TargetResolver, :ensure_targetable, fn ^target_state, :mob -> :ok end)
    stub(AttackValidator, :validate, fn ^attacker, ^target, _opts -> :ok end)
    stub(Targeting, :validate_enemy, fn ^attacker, ^target -> :ok end)

    expect(StatusInterpreter, :before_weapon_hit, 4, fn :mob, 2001, _attack_info ->
      call = Process.get(:interception_call, 0) + 1
      Process.put(:interception_call, call)
      if call == 1, do: {:intercept, :blocked}, else: :continue
    end)

    expect(DamageCalculator, :calculate_damage, 3, fn ^attacker, ^target, _opts ->
      call = Process.get(:calculation_call, 0) + 1
      Process.put(:calculation_call, call)

      case call do
        1 -> {:error, :failed}
        2 -> {:ok, %{damage: 0, is_critical: false}}
        3 -> {:ok, %{damage: 25, is_critical: false}}
      end
    end)

    expect(EquipComa, :trigger?, fn ^attacker, ^target ->
      send(test_pid, :coma_decided)
      true
    end)

    stub(StatusInterpreter, :absorb_damage, fn :mob, 2001, 25, hit_info ->
      assert hit_info.coma?
      25
    end)

    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)

    expect(MobSession, :apply_damage, fn _pid, 0, 1001 ->
      refute_received :coma_decided
      :ok
    end)

    expect(MobSession, :apply_coma, fn _pid, {:player, 1001} -> :ok end)

    expect(Knockback, :skill, fn ^attacker, ^target, 7, result, [] ->
      assert result == %{hit?: true, target_survives?: true, coma?: true}
      send(test_pid, :knockback_requested)
      :ok
    end)

    assert {:ok, %{hit?: true, damage: 25, target_survives?: true, coma?: true}} =
             SkillAttack.execute_skill_attack(caster_state, {:mob, 2001},
               skill_id: 7,
               skill_level: 1,
               hit_count: 4,
               ignore_flee: true,
               report_hit: true
             )

    assert_received :coma_decided
    assert_received :knockback_requested
  end

  test "a missed fragment never decides or delivers coma" do
    attacker = CombatTestHelper.create_player_combatant(unit_id: 1001, position: {100, 100})

    target =
      CombatTestHelper.create_mob_combatant(unit_id: 2001, position: {101, 100})
      |> Map.update!(:combat_stats, &Map.put(&1, :perfect_dodge, 1_000))

    caster_state = %TestUnit{combatant: attacker, hp: 100}
    target_state = %TestUnit{combatant: target, hp: 100}

    stub(TargetResolver, :resolve, fn {:mob, 2001} ->
      {:ok, self(), target_state, :mob}
    end)

    stub(TargetResolver, :ensure_targetable, fn ^target_state, :mob -> :ok end)
    stub(AttackValidator, :validate, fn ^attacker, ^target, _opts -> :ok end)
    stub(Targeting, :validate_enemy, fn ^attacker, ^target -> :ok end)
    stub(StatusInterpreter, :before_weapon_hit, fn :mob, 2001, _attack_info -> :continue end)
    reject(&DamageCalculator.calculate_damage/3)
    reject(&EquipComa.trigger?/2)
    reject(&Knockback.skill/5)
    reject(&MobSession.apply_damage/3)
    reject(&MobSession.apply_coma/2)
    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)

    assert {:ok, %{hit?: false, damage: 0, target_survives?: true, coma?: false}} =
             SkillAttack.execute_skill_attack(caster_state, {:mob, 2001},
               skill_id: 7,
               skill_level: 1,
               report_hit: true
             )
  end

  test "a consumed coma roll does not mutate an owner when absorption reduces final damage to zero" do
    attacker = CombatTestHelper.create_player_combatant(unit_id: 1001, position: {100, 100})
    target = CombatTestHelper.create_mob_combatant(unit_id: 2001, position: {101, 100})
    caster_state = %TestUnit{combatant: attacker, hp: 100}
    target_state = %TestUnit{combatant: target, hp: 100}

    stub(TargetResolver, :resolve, fn {:mob, 2001} ->
      {:ok, self(), target_state, :mob}
    end)

    stub(TargetResolver, :ensure_targetable, fn ^target_state, :mob -> :ok end)
    stub(AttackValidator, :validate, fn ^attacker, ^target, _opts -> :ok end)
    stub(Targeting, :validate_enemy, fn ^attacker, ^target -> :ok end)
    stub(StatusInterpreter, :before_weapon_hit, fn :mob, 2001, _attack_info -> :continue end)

    expect(DamageCalculator, :calculate_damage, fn ^attacker, ^target, _opts ->
      {:ok, %{damage: 50, is_critical: false}}
    end)

    expect(EquipComa, :trigger?, fn ^attacker, ^target -> true end)

    expect(StatusInterpreter, :absorb_damage, fn :mob, 2001, 50, hit_info ->
      assert hit_info.coma?
      0
    end)

    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, packet ->
      assert packet.damage == 0
      :ok
    end)

    reject(&MobSession.apply_damage/3)
    reject(&MobSession.apply_coma/2)

    assert {:ok, %{hit?: true, damage: 0, target_survives?: true, coma?: true}} =
             SkillAttack.execute_skill_attack(caster_state, {:mob, 2001},
               skill_id: 7,
               skill_level: 1,
               ignore_flee: true,
               report_hit: true
             )
  end

  test "physical coma marker reaches a player target owner" do
    attacker = CombatTestHelper.create_player_combatant(unit_id: 1001, position: {100, 100})
    target = CombatTestHelper.create_player_combatant(unit_id: 2001, position: {101, 100})
    caster_state = %TestUnit{combatant: attacker, hp: 100}
    target_state = %TestUnit{combatant: target, hp: 100}

    stub(TargetResolver, :resolve, fn {:player, 2001} ->
      {:ok, self(), target_state, :player}
    end)

    stub(TargetResolver, :ensure_targetable, fn ^target_state, :player -> :ok end)
    stub(AttackValidator, :validate, fn ^attacker, ^target, _opts -> :ok end)
    stub(Targeting, :validate_enemy, fn ^attacker, ^target -> :ok end)
    stub(StatusInterpreter, :before_weapon_hit, fn :player, 2001, _info -> :continue end)

    stub(DamageCalculator, :calculate_damage, fn ^attacker, ^target, _opts ->
      {:ok, %{damage: 30, is_critical: false}}
    end)

    expect(EquipComa, :trigger?, fn ^attacker, ^target -> true end)

    expect(StatusInterpreter, :absorb_damage, fn :player, 2001, 30, hit_info ->
      assert hit_info.coma?
      30
    end)

    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)
    reject(&PlayerSession.apply_damage/3)
    expect(PlayerSession, :apply_coma, fn _pid, {:player, 1001} -> :ok end)

    assert {:ok, %{coma?: true}} =
             SkillAttack.execute_skill_attack(caster_state, {:player, 2001},
               skill_id: 7,
               skill_level: 1,
               ignore_flee: true,
               report_hit: true
             )
  end

  test "physical coma marker reaches a Homunculus owner" do
    attacker = CombatTestHelper.create_player_combatant(unit_id: 1001, position: {100, 100})

    target =
      CombatTestHelper.create_mob_combatant(unit_id: 2001, position: {101, 100})
      |> Map.replace!(:unit_type, :homunculus)

    caster_state = %TestUnit{combatant: attacker, hp: 100}
    target_state = %TestUnit{combatant: target, hp: 100}
    test_pid = self()

    owner =
      spawn(fn ->
        receive do
          {:"$gen_cast", message} -> send(test_pid, {:owner_cast, message})
        end
      end)

    stub(TargetResolver, :resolve, fn {:homunculus, 2001} ->
      {:ok, owner, target_state, :homunculus}
    end)

    stub(TargetResolver, :ensure_targetable, fn ^target_state, :homunculus -> :ok end)
    stub(AttackValidator, :validate, fn ^attacker, ^target, _opts -> :ok end)
    stub(Targeting, :validate_enemy, fn ^attacker, ^target -> :ok end)
    stub(StatusInterpreter, :before_weapon_hit, fn :homunculus, 2001, _info -> :continue end)

    stub(DamageCalculator, :calculate_damage, fn ^attacker, ^target, _opts ->
      {:ok, %{damage: 30, is_critical: false}}
    end)

    expect(EquipComa, :trigger?, fn ^attacker, ^target -> true end)

    expect(StatusInterpreter, :absorb_damage, fn :homunculus, 2001, 30, hit_info ->
      assert hit_info.coma?
      30
    end)

    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)

    assert {:ok, %{coma?: true}} =
             SkillAttack.execute_skill_attack(caster_state, {:homunculus, 2001},
               skill_id: 7,
               skill_level: 1,
               ignore_flee: true,
               report_hit: true
             )

    assert_received {:owner_cast, {:homunculus, {:apply_coma, 2001, {:player, 1001}}}}
  end

  test "a targetable skill unit receives ordinary physical damage without coma" do
    attacker = CombatTestHelper.create_player_combatant(unit_id: 1001, position: {100, 100})

    target =
      CombatTestHelper.create_mob_combatant(unit_id: 2001, position: {101, 100})
      |> Map.replace!(:unit_type, :skill_unit)

    caster_state = %TestUnit{combatant: attacker, hp: 100}
    target_state = %TestUnit{combatant: target, hp: 100}
    test_pid = self()

    manager =
      spawn(fn ->
        receive do
          {or_call, from, {:damage_targetable_cell, 2001, 30, {:player, 1001}}}
          when or_call == :"$gen_call" ->
            send(test_pid, :skill_unit_damaged)
            GenServer.reply(from, {:ok, :cell})
        end
      end)

    stub(TargetResolver, :resolve, fn {:skill_unit, 2001} ->
      {:ok, manager, target_state, :skill_unit}
    end)

    stub(TargetResolver, :ensure_targetable, fn ^target_state, :skill_unit -> :ok end)
    stub(AttackValidator, :validate, fn ^attacker, ^target, _opts -> :ok end)
    stub(Targeting, :validate_enemy, fn ^attacker, ^target -> :ok end)
    stub(StatusInterpreter, :before_weapon_hit, fn :skill_unit, 2001, _info -> :continue end)

    stub(DamageCalculator, :calculate_damage, fn ^attacker, ^target, _opts ->
      {:ok, %{damage: 30, is_critical: false}}
    end)

    expect(EquipComa, :trigger?, fn ^attacker, ^target -> false end)
    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)

    assert {:ok, %{hit?: true, damage: 30, coma?: false}} =
             SkillAttack.execute_skill_attack(caster_state, {:skill_unit, 2001},
               skill_id: 7,
               skill_level: 1,
               ignore_flee: true,
               report_hit: true
             )

    assert_received :skill_unit_damaged
  end

  test "mob and Homunculus skill attackers cannot receive equipment coma" do
    target = CombatTestHelper.create_mob_combatant(unit_id: 2001, position: {101, 100})
    target_state = %TestUnit{combatant: target, hp: 100}
    test_pid = self()

    attackers =
      for {unit_type, unit_id} <- [mob: 3001, homunculus: 3002] do
        combatant =
          CombatTestHelper.create_player_combatant(unit_id: unit_id, position: {100, 100})

        %{
          combatant
          | unit_type: unit_type,
            equip_modifiers: %{{:coma_race, target.race} => 10_000}
        }
      end

    stub(TargetResolver, :resolve, fn {:mob, 2001} ->
      {:ok, self(), target_state, :mob}
    end)

    stub(TargetResolver, :ensure_targetable, fn ^target_state, :mob -> :ok end)

    stub(AttackValidator, :validate, fn attacker, ^target, _opts ->
      assert attacker.unit_type in [:mob, :homunculus]
      :ok
    end)

    stub(Targeting, :validate_enemy, fn attacker, ^target ->
      assert attacker.unit_type in [:mob, :homunculus]
      :ok
    end)

    stub(StatusInterpreter, :before_weapon_hit, fn :mob, 2001, _info -> :continue end)

    stub(DamageCalculator, :calculate_damage, fn attacker, ^target, _opts ->
      assert attacker.unit_type in [:mob, :homunculus]
      {:ok, %{damage: 30, is_critical: false}}
    end)

    stub(StatusInterpreter, :absorb_damage, fn :mob, 2001, 30, hit_info ->
      refute hit_info.coma?
      30
    end)

    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)
    reject(&MobSession.apply_coma/2)

    stub(MobSession, :apply_damage, fn _pid, 30, source ->
      send(test_pid, {:ordinary_damage, source})
      :ok
    end)

    Enum.each(attackers, fn attacker ->
      assert {:ok, %{coma?: false}} =
               SkillAttack.execute_skill_attack(
                 %TestUnit{combatant: attacker, hp: 100},
                 {:mob, 2001},
                 skill_id: 7,
                 skill_level: 1,
                 ignore_flee: true,
                 report_hit: true
               )
    end)

    assert_received {:ordinary_damage, 3001}
    assert_received {:ordinary_damage, {:homunculus, 3002}}
  end

  test "forced no-card single hits without a flee roll and carries the Venom Knife hook exemption" do
    attacker =
      CombatTestHelper.create_player_combatant(
        unit_id: 1001,
        position: {100, 100},
        attack_range: 1
      )

    target =
      CombatTestHelper.create_mob_combatant(unit_id: 2001, position: {109, 100})
      |> Map.update!(:combat_stats, &Map.put(&1, :perfect_dodge, 1_000))

    caster_state = %TestUnit{combatant: attacker, hp: 100}
    target_state = %TestUnit{combatant: target, hp: 30}
    test_pid = self()

    stub(TargetResolver, :resolve, fn {:mob, 2001} ->
      {:ok, self(), target_state, :mob}
    end)

    stub(TargetResolver, :ensure_targetable, fn ^target_state, :mob -> :ok end)
    stub(AttackValidator, :validate, fn ^attacker, ^target, _opts -> :ok end)
    stub(Targeting, :validate_enemy, fn ^attacker, ^target -> :ok end)

    expect(StatusInterpreter, :before_weapon_hit, fn :mob, 2001, attack_info ->
      assert attack_info.attacker == {:player, 1001}
      assert attack_info.target == {:mob, 2001}
      assert attack_info.ignores_auto_guard == true
      assert attack_info.basic_attack? == false
      :continue
    end)

    expect(DamageCalculator, :calculate_damage_ignoring_attacker_cards, fn
      ^attacker, ^target, opts ->
        assert opts[:element] == :neutral
        assert opts[:bonus_atk] == 30
        {:ok, %{damage: 40, is_critical: false}}
    end)

    expect(StatusInterpreter, :absorb_damage, fn :mob, 2001, 40, hit_info ->
      assert hit_info.dmg_type == :physical
      assert hit_info.is_short == false
      assert hit_info.skill_id == 1004
      35
    end)

    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, packet ->
      assert packet.damage == 35
      :ok
    end)

    expect(MobSession, :apply_damage, fn _pid, 35, 1001 ->
      send(test_pid, :delivered)
      :ok
    end)

    expect(Knockback, :skill, fn ^attacker, ^target, 1004, result, [] ->
      assert_received :delivered
      assert result == %{hit?: true, target_survives?: false, coma?: false}
      :ok
    end)

    assert {:ok, %{hit?: true, damage: 35, target_survives?: false}} =
             SkillAttack.execute_forced_no_card_attack(caster_state, {:mob, 2001},
               skill_id: 1004,
               skill_level: 1,
               skill_ratio: 500,
               bonus_atk: 30,
               report_hit: true,
               skip_range: true
             )
  end

  test "no-card delivery omits cardfix but retains DEF-ignore and all global/defender hooks" do
    attacker = %{
      CombatTestHelper.create_player_combatant(
        unit_id: 1001,
        position: {100, 100},
        weapon_type: :sword
      )
      | dragonology_level: 5,
        equip_modifiers: %{
          {:addrace, :dragon} => 100,
          {:ignore_def_race, :dragon} => 100,
          {:skill_atk, 1004} => 20,
          long_atk_rate: 25
        }
    }

    target = %{
      CombatTestHelper.create_mob_combatant(
        unit_id: 2001,
        position: {109, 100},
        race: :dragon,
        def: 100
      )
      | equip_modifiers: %{{:subrace, :human} => 10}
    }

    caster_state = %TestUnit{combatant: attacker, hp: 100}
    target_state = %TestUnit{combatant: target, hp: 10_000}

    stub(TargetResolver, :resolve, fn {:mob, 2001} ->
      {:ok, self(), target_state, :mob}
    end)

    stub(TargetResolver, :ensure_targetable, fn ^target_state, :mob -> :ok end)
    stub(AttackValidator, :validate, fn ^attacker, ^target, _opts -> :ok end)
    stub(Targeting, :validate_enemy, fn ^attacker, ^target -> :ok end)
    stub(StatusInterpreter, :before_weapon_hit, fn :mob, 2001, _attack_info -> :continue end)

    stub(ModifierCalculator, :get_all_modifiers, fn
      :player, 1001 -> %{atk_rate: 50}
      _, _ -> %{}
    end)

    expect(StatusInterpreter, :absorb_damage, fn :mob, 2001, 1_944, hit_info ->
      assert hit_info.is_short == false
      1_900
    end)

    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, packet ->
      assert packet.damage == 1_900
      :ok
    end)

    expect(MobSession, :apply_damage, fn _pid, 1_900, 1001 -> :ok end)

    assert {:ok, %{hit?: true, damage: 1_900, target_survives?: true}} =
             SkillAttack.execute_forced_no_card_attack(caster_state, {:mob, 2001},
               skill_id: 1004,
               skill_level: 1,
               base_damage: 1_000,
               skip_crit: true,
               report_hit: true,
               skip_range: true
             )
  end

  defp event_sequence(count) do
    for _ <- 1..count do
      assert_receive {:event, event}
      event
    end
  end

  test "forced no-card splash forces each hit but does not carry the Auto Guard exemption" do
    attacker = CombatTestHelper.create_player_combatant(unit_id: 1001, position: {100, 100})

    target =
      CombatTestHelper.create_mob_combatant(unit_id: 2001, position: {101, 100})
      |> Map.update!(:combat_stats, &Map.put(&1, :perfect_dodge, 1_000))

    caster_state = %TestUnit{combatant: attacker, hp: 100, x: 100, y: 100}
    target_state = %TestUnit{combatant: target, hp: 100, x: 101, y: 100}

    stub(SpatialIndex, :get_all_units_in_range, fn "test_map", 100, 100, 4 ->
      [{:mob, 2001}]
    end)

    stub(TargetResolver, :resolve, fn
      :mob, 2001 -> {:ok, self(), target_state, :mob}
    end)

    stub(TargetResolver, :resolve, fn
      {:mob, 2001} -> {:ok, self(), target_state, :mob}
    end)

    stub(Targeting, :validate_enemy, fn ^attacker, ^target -> :ok end)

    expect(StatusInterpreter, :before_weapon_hit, fn :mob, 2001, attack_info ->
      assert attack_info.attacker == {:player, 1001}
      assert attack_info.target == {:mob, 2001}
      refute Map.has_key?(attack_info, :ignores_auto_guard)
      :continue
    end)

    expect(DamageCalculator, :calculate_damage_ignoring_attacker_cards, fn
      ^attacker, ^target, opts ->
        assert opts[:skill_id] == 141
        {:ok, %{damage: 60, is_critical: false}}
    end)

    stub(StatusInterpreter, :absorb_damage, fn :mob, 2001, damage, _hit_info -> damage end)
    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)
    expect(MobSession, :apply_damage, fn _pid, 60, 1001 -> :ok end)

    assert [{:mob, 2001}] =
             SkillAttack.execute_forced_no_card_splash(caster_state, {100, 100}, 2,
               skill_id: 141,
               skill_level: 10,
               skill_ratio: 1_400,
               typed_results: true
             )
  end
end
