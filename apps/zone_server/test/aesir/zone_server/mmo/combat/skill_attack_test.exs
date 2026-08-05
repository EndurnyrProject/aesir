defmodule Aesir.ZoneServer.Mmo.Combat.SkillAttackTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Mmo.Combat.AttackValidator
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.SkillAttack
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.SpatialIndex

  defmodule TestUnit do
    defstruct [:combatant, :hp, :x, :y]

    def to_combatant(%__MODULE__{combatant: combatant}), do: combatant
    def living?(%__MODULE__{hp: hp}), do: hp > 0
  end

  setup :set_mimic_from_context
  setup :verify_on_exit!
  setup :setup_ets_tables

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
    target_state = %TestUnit{combatant: target, hp: 100}
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

    assert {:ok, %{hit?: true, damage: 35, target_survives?: true}} =
             SkillAttack.execute_forced_no_card_attack(caster_state, {:mob, 2001},
               skill_id: 1004,
               skill_level: 1,
               skill_ratio: 500,
               bonus_atk: 30,
               report_hit: true,
               skip_range: true
             )

    assert_received :delivered
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
