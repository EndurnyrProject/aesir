defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.ParryingTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.AttackValidator
  alias Aesir.ZoneServer.Mmo.Combat.AutoAttack
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.MagicDamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Parrying
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpecialEffect
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_from_context
  setup :verify_on_exit!

  defmodule FakeCombatUnit do
    @moduledoc false
    defstruct [:combatant, :stats]
    def to_combatant(%__MODULE__{combatant: combatant}), do: combatant
  end

  test "a successful weapon roll blocks and plays the guard effect" do
    expect(SpecialEffect, :play, fn {:player, 3}, :guard, :area -> :ok end)
    :rand.seed(:exsss, {2, 3, 4})

    assert {:intercept, :blocked} =
             Parrying.before_weapon_hit({:player, 3}, %StatusEntry{val1: 1}, %{}, %{})
  end

  test "a failed roll does not intercept" do
    reject(&SpecialEffect.play/3)
    :rand.seed(:exsss, {10, 11, 12})
    assert :continue = Parrying.before_weapon_hit({:player, 3}, %StatusEntry{val1: 10}, %{}, %{})
  end

  test "level ten blocks a roll of exactly 50 percent" do
    expect(SpecialEffect, :play, fn {:player, 3}, :guard, :area -> :ok end)
    :rand.seed(:exsss, {14, 15, 16})

    assert {:intercept, :blocked} =
             Parrying.before_weapon_hit({:player, 3}, %StatusEntry{val1: 10}, %{}, %{})
  end

  test "a parried basic attack never reaches damage delivery" do
    Aesir.TestEtsSetup.setup_ets_tables(%{})

    player = parrying_player()

    :ok = UnitRegistry.register_player(player, self())
    :ok = StatusStorage.apply_status(:player, 3, :sc_parrying, val1: 10, duration: 60_000)
    attacker = CombatTestHelper.create_player_combatant(unit_id: 2, position: {150, 150})
    defender = CombatTestHelper.create_player_combatant(unit_id: 3, position: {150, 150})
    target_state = %FakeCombatUnit{combatant: defender}

    stub(TargetResolver, :resolve, fn 3 -> {:ok, self(), target_state, :player} end)
    stub(TargetResolver, :ensure_targetable, fn _target, :player -> :ok end)
    stub(AttackValidator, :validate, fn _attacker, _target, _opts -> :ok end)
    stub(Targeting, :validate_enemy, fn _attacker, _target -> :ok end)
    stub(SpecialEffect, :play, fn {:player, 3}, :guard, :area -> :ok end)
    reject(&DamageCalculator.calculate_damage/3)
    reject(&PlayerSession.apply_damage/3)

    :rand.seed(:exsss, {14, 15, 16})

    assert :intercepted =
             AutoAttack.execute_attack(
               player.stats,
               %FakeCombatUnit{combatant: attacker, stats: player.stats},
               3
             )

    assert StatusStorage.has_status?(:player, 3, :sc_parrying)
  end

  test "magic attacks never invoke the weapon-hit hook" do
    Aesir.TestEtsSetup.setup_ets_tables(%{})
    :ok = UnitRegistry.register_player(parrying_player(), self())
    :ok = StatusStorage.apply_status(:player, 3, :sc_parrying, val1: 10, duration: 60_000)
    attacker = CombatTestHelper.create_player_combatant(unit_id: 2, position: {150, 150})
    defender = CombatTestHelper.create_player_combatant(unit_id: 3, position: {150, 150})
    caster_state = %PlayerState{character_id: 2}
    target_state = %PlayerState{character_id: 3}

    stub(PlayerState, :to_combatant, fn
      %PlayerState{character_id: 2} -> attacker
      %PlayerState{character_id: 3} -> defender
    end)

    stub(TargetResolver, :resolve, fn 3 -> {:ok, self(), target_state, :player} end)
    stub(TargetResolver, :ensure_targetable, fn _state, :player -> :ok end)
    stub(AttackValidator, :validate, fn _attacker, _target, _opts -> :ok end)
    stub(Targeting, :validate_enemy, fn _attacker, _target -> :ok end)

    stub(MagicDamageCalculator, :calculate_magic_damage, fn _a, _t, _opts ->
      {:ok, %{damage: 30, is_critical: false}}
    end)

    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)
    stub(PlayerSession, :apply_damage, fn _pid, _damage, _attacker_id -> :ok end)
    reject(&Interpreter.before_weapon_hit/3)

    assert {:ok, {:player, 3}} =
             Combat.execute_magic_attack(caster_state, 3,
               skill_id: 14,
               skill_level: 10,
               skill_ratio: 100,
               element: :fire
             )
  end

  defp parrying_player do
    PlayerState.new(%Character{
      id: 3,
      account_id: 4,
      name: "Parrying LK",
      last_map: "prontera",
      last_x: 150,
      last_y: 150,
      sex: "M",
      str: 1,
      agi: 1,
      vit: 1,
      int: 1,
      dex: 1,
      luk: 1,
      base_level: 90,
      job_level: 50,
      class: 7
    })
  end

  test "ignore-auto-guard attacks are still parried" do
    expect(SpecialEffect, :play, fn {:player, 3}, :guard, :area -> :ok end)
    :rand.seed(:exsss, {2, 3, 4})

    assert {:intercept, :blocked} =
             Parrying.before_weapon_hit(
               {:player, 3},
               %StatusEntry{val1: 1},
               %{ignores_auto_guard: true},
               %{}
             )
  end
end
