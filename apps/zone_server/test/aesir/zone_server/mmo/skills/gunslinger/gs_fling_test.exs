defmodule Aesir.ZoneServer.Mmo.Skills.Gunslinger.GsFlingTest do
  use ExUnit.Case, async: true
  import Mimic
  import Aesir.ZoneServer.Factory

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.MiscDamageCalculator
  alias Aesir.ZoneServer.Mmo.Skill.Caster.Player, as: PlayerCaster
  alias Aesir.ZoneServer.Mmo.Skills.Gunslinger.GsFling
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.PlayerStateFixture
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.SpiritSpheres

  setup :verify_on_exit!

  test "three coins allow the cast, are recorded and clamp the cost" do
    caster = caster(coins(3))
    cost = GsFling.dynamic_cost(caster, {:unit, 2000}, 1, GsFling.definition())

    assert cost.spheres == 3
    assert cost.spheres_old == 3

    assert GsFling.dynamic_cost(caster(coins(7)), {:unit, 2000}, 1, GsFling.definition()).spheres ==
             5
  end

  test "a three-coin cast settles those three coins and its ten SP" do
    caster = caster(coins(3))
    definition = GsFling.definition()
    cost = GsFling.dynamic_cost(caster, {:unit, 2000}, 1, definition)

    assert {:ok, prepared} =
             PlayerCaster.prepare_begin_cost(caster, GsFling, definition, cost, 0, 1)

    {paid, remaining} = PlayerCaster.commit_primary(caster, prepared)
    paid = PlayerCaster.commit(paid, remaining)

    assert SpiritSpheres.count(paid.spirit_spheres) == 0
    assert paid.stats.current_state.sp == 90
  end

  test "the damage is the job level whatever the target's DEF, element and flee" do
    definition = GsFling.definition()
    attacker = build(:player_combatant, job_level: 42)

    armored = build(:mob_combatant, def: 500, soft_def: 500, element: :water)
    evasive = build(:mob_combatant, agi: 200)
    evasive = %{evasive | combat_stats: %{evasive.combat_stats | flee: 5_000}}

    opts = [skill_id: definition.id, attack_flag: 0x20, base_damage: 42]

    assert {:ok, %{damage: 42}} =
             MiscDamageCalculator.calculate_misc_damage(attacker, armored, opts)

    assert {:ok, %{damage: 42}} =
             MiscDamageCalculator.calculate_misc_damage(attacker, evasive, opts)
  end

  test "an empty hand refuses with the coins reason" do
    caster = caster(SpiritSpheres.new())
    cost = GsFling.dynamic_cost(caster, {:unit, 2000}, 1, GsFling.definition())

    assert {:error, {:coins, 5}} =
             PlayerCaster.prepare_begin_cost(caster, GsFling, GsFling.definition(), cost, 0, 1)
  end

  test "a landed hit deals job level as unmissable misc damage and flings the recorded coins" do
    caster = %{caster(SpiritSpheres.new()) | spirit_spheres_old: 3}

    expect(Combat, :execute_misc_attack, fn ^caster, {:mob, 2000}, opts ->
      assert opts[:base_damage] == 42
      assert opts[:report_hit]
      {:ok, %{hit?: true}}
    end)

    expect(StatusInterpreter, :apply_status, fn :mob, 2000, :sc_fling, params ->
      assert params[:val1] == 3
      assert params[:duration] == 30_000
      assert params[:source_type] == :player
      :ok
    end)

    assert {:ok, ^caster} = GsFling.cast(caster, {:unit, {:mob, 2000}}, 1, GsFling.definition())
  end

  test "a monster throws five coins for its base level" do
    mob = %MobState{
      instance_id: 9,
      mob_id: 1002,
      mob_data: %{level: 33},
      level: 33,
      spawn_ref: nil,
      x: 0,
      y: 0,
      map_name: "prontera",
      hp: 10,
      sp: 0,
      spawned_at: 0
    }

    expect(Combat, :execute_misc_attack, fn ^mob, {:player, 4000}, opts ->
      assert opts[:base_damage] == 33
      {:ok, %{hit?: true}}
    end)

    expect(StatusInterpreter, :apply_status, fn :player, 4000, :sc_fling, params ->
      assert params[:val1] == 5
      assert params[:source_type] == :mob
      :ok
    end)

    assert {:ok, ^mob} = GsFling.cast(mob, {:unit, {:player, 4000}}, 1, GsFling.definition())
  end

  test "a missed hit starts no status" do
    stub(Combat, :execute_misc_attack, fn _caster, _target, _opts -> {:ok, %{hit?: false}} end)
    reject(&StatusInterpreter.apply_status/4)

    caster = caster(coins(1))
    assert {:ok, ^caster} = GsFling.cast(caster, {:unit, {:mob, 2000}}, 1, GsFling.definition())
  end

  defp coins(n) do
    now = System.monotonic_time(:millisecond)

    Enum.reduce(1..n//1, SpiritSpheres.new(), fn i, spheres ->
      spheres |> SpiritSpheres.summon(now + 60_000 + i, 10) |> elem(0)
    end)
  end

  defp caster(spheres) do
    PlayerStateFixture.build(%{
      character_id: 4000,
      x: 10,
      y: 10,
      map_name: "prontera",
      skill_cooldowns: %{},
      act_delay_until: 0,
      spirit_spheres: spheres,
      stats: %{
        current_state: %{hp: 100, sp: 100},
        progression: %{job_id: 24, job_level: 42, learned_skills: %{501 => 1}}
      }
    })
  end
end
