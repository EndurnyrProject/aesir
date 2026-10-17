defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.EdpTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Mmo.Combat.BattleFlags
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.OnHitEffects
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.PlayerStateFixture
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Stats.CombatStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables
  setup :set_mimic_private

  setup do
    player =
      PlayerStateFixture.build(%{
        character_id: 1,
        map_name: "prontera",
        stats: %{combat_stats: %CombatStats{}, progression: %{learned_skills: %{2024 => 2}}}
      })

    UnitRegistry.register_unit(:player, 1, PlayerState, player, self())
    :ok
  end

  test "only a connected surviving normal weapon contact rolls Deadly Poison, including zero damage" do
    :ok = StatusStorage.apply_status(:mob, 1, :sc_edp, val1: 1, val2: 3)
    attacker = %{unit_type: :mob, unit_id: 1}
    defender = %{unit_type: :player, unit_id: 2}
    stages = %{hit_class: :hit, attack_effects?: true, counter_effects?: false, damage: 0}
    flag = BattleFlags.build(:weapon, :short, false)
    opts = [attack_flag: flag, roll: fn 300 -> true end]

    expect(Interpreter, :apply_status, fn :player, 2, :sc_dpoison, params ->
      assert params[:val1] == 1
      assert params[:success_rate] == 3
      assert params[:source_type] == :mob
      assert params[:caster_id] == 1
      assert params[:duration] == if(GameMode.mode() == :renewal, do: 20_000, else: 60_000)
      assert params[:resistance_roll].(300)
      :ok
    end)

    OnHitEffects.attack_stage(attacker, defender, stages, opts)

    reject(&Interpreter.apply_status/4)
    OnHitEffects.attack_stage(attacker, defender, %{stages | hit_class: :block}, opts)
    OnHitEffects.attack_stage(attacker, defender, %{stages | attack_effects?: false}, opts)
    OnHitEffects.attack_stage(attacker, defender, stages, Keyword.put(opts, :skill_id, 5))
  end

  @tag game_mode: :pre_renewal
  test "classic EDP boosts surviving mastery damage on a fled attack, only on the right hand" do
    attacker = CombatTestHelper.create_player_combatant(unit_id: 1)
    physical = Map.put(attacker.combat_stats.physical_attack, :star_atk, 7)
    attacker = put_in(attacker.combat_stats.physical_attack, physical)
    defender = CombatTestHelper.create_mob_combatant(element: :neutral, def: 0)
    :ok = StatusStorage.apply_status(:player, 1, :sc_edp, val1: 5, val2: 5, val3: 300)

    assert {:ok, %{damage: 28}} = DamageCalculator.calculate_fled_damage(attacker, defender, [])

    assert {:ok, %{damage: 7}} =
             DamageCalculator.calculate_fled_damage(attacker, defender, ignore_element: true)
  end

  @tag game_mode: :pre_renewal
  test "classic scalar EDP follows the elemental step and includes its truncated result" do
    attacker = CombatTestHelper.create_player_combatant(unit_id: 1, weapon_element: :water)
    defender = CombatTestHelper.create_mob_combatant(element: {:fire, 1}, def: 0, soft_def: 0)
    :ok = StatusStorage.apply_status(:player, 1, :sc_edp, val1: 5, val2: 5, val3: 300)

    assert {:ok, %{damage: 600}} =
             DamageCalculator.calculate_damage_ignoring_defense(attacker, defender,
               base_damage: 100
             )
  end

  test "EDP's secondary property gets the same research extension without altering other auras" do
    player =
      PlayerStateFixture.build(%{
        character_id: 1,
        map_name: "prontera",
        stats: %{combat_stats: %CombatStats{}, progression: %{learned_skills: %{2024 => 2}}}
      })

    UnitRegistry.register_unit(:player, 1, PlayerState, player, self())

    assert :ok =
             Interpreter.apply_status(:player, 1, :sc_sub_weaponproperty,
               val1: 5,
               val2: 25,
               val3: 378,
               duration: 40_000,
               caster_id: 1
             )

    entry = StatusStorage.get_status(:player, 1, :sc_sub_weaponproperty)
    assert entry.expires_at - entry.started_at == 100_000

    Interpreter.remove_status(:player, 1, :sc_sub_weaponproperty)

    assert :ok =
             Interpreter.apply_status(:player, 1, :sc_sub_weaponproperty,
               val1: 3,
               val2: 20,
               duration: 10_000,
               caster_id: 1
             )

    entry = StatusStorage.get_status(:player, 1, :sc_sub_weaponproperty)
    assert entry.expires_at - entry.started_at == 10_000
  end

  test "EDP derives its poison chance and extends only a fresh application" do
    player =
      PlayerStateFixture.build(%{
        character_id: 1,
        map_name: "prontera",
        stats: %{combat_stats: %CombatStats{}, progression: %{learned_skills: %{2024 => 2}}}
      })

    UnitRegistry.register_unit(:player, 1, PlayerState, player, self())

    assert :ok =
             Interpreter.apply_status(:player, 1, :sc_edp,
               val1: 5,
               duration: 40_000,
               caster_id: 1
             )

    entry = StatusStorage.get_status(:player, 1, :sc_edp)
    assert entry.val2 == 5
    assert entry.val3 == if(GameMode.mode() == :pre_renewal, do: 300, else: 0)
    assert entry.expires_at - entry.started_at == 100_000

    Interpreter.remove_status(:player, 1, :sc_edp)

    assert :ok =
             Interpreter.apply_status(:player, 1, :sc_edp,
               val1: 5,
               val2: 5,
               val3: entry.val3,
               duration: 35_000,
               loaded: true
             )

    restored = StatusStorage.get_status(:player, 1, :sc_edp)
    assert restored.expires_at - restored.started_at == 35_000
  end
end
