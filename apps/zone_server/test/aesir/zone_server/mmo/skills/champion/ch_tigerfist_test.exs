defmodule Aesir.ZoneServer.Mmo.Skills.Champion.ChTigerfistTest do
  use ExUnit.Case, async: false

  import Mimic
  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.Skills.Champion.ChTigerfist
  alias Aesir.ZoneServer.Mmo.Skills.Champion.Formulas
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Combo
  alias Aesir.ZoneServer.Mmo.StatusEffect.Resistance
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SpiritSpheres
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_private
  setup :verify_on_exit!
  setup :setup_ets_tables

  @target_id 38_001

  setup do
    register_mob(@target_id, agi: 40)
    stub(Combat, :resolve_target_position, fn @target_id -> {:ok, :mob, {60, 50, "prontera"}} end)
    :ok
  end

  test "follows Raging Thrust, whatever unit its window last hit" do
    assert :ok = validate(caster(:extremity))
    assert {:error, :invalid_combo} = validate(caster(:tiger_fist))

    other = %{
      caster(:extremity)
      | combo: Combo.open(Combo.new(), :extremity, {:mob, 1}, future())
    }

    assert :ok = validate(other)
  end

  @tag game_mode: :renewal
  test "renewal refuses Glacier Fist after Chain Crush" do
    assert {:error, :invalid_combo} = validate(caster(:chain_crush))
  end

  @tag game_mode: :pre_renewal
  test "pre-renewal allows Glacier Fist after Chain Crush" do
    assert :ok = validate(caster(:chain_crush))
  end

  test "a landed hit that wins the roll immobilises the target for the AGI-scaled time" do
    caster = caster(:extremity)
    test_pid = self()

    stub(Resistance, :roll_success, fn rate ->
      send(test_pid, {:roll, rate})
      true
    end)

    expect_attack(caster, true)

    before = System.monotonic_time(:millisecond)
    assert {:ok, _updated} = cast(caster, 5)
    assert_received {:roll, 60}

    duration = Formulas.glacier_ankle_duration(5, 40, false, 99)
    entry = StatusStorage.get_status(:mob, @target_id, :sc_ankle)
    assert entry.expires_at >= before + duration
    assert entry.expires_at <= System.monotonic_time(:millisecond) + duration
  end

  test "a miss never immobilises" do
    caster = caster(:extremity)
    stub(Resistance, :roll_success, fn _ -> true end)
    expect_attack(caster, false)

    assert {:ok, _updated} = cast(caster, 5)
    refute StatusStorage.get_status(:mob, @target_id, :sc_ankle)
  end

  test "opens the Chain Crush window when two spheres remain after its own" do
    stub(Resistance, :roll_success, fn _ -> false end)

    ready = caster(:extremity, spheres: 2)
    expect_attack(ready, true)
    assert {:ok, %{combo: %{stage: :tiger_fist, target: {:mob, @target_id}}}} = cast(ready, 1)

    short = caster(:extremity, spheres: 1)
    expect_attack(short, true)
    assert {:ok, %{combo: %{stage: :idle}}} = cast(short, 1)
  end

  defp expect_attack(caster, hit?) do
    expect(Combat, :execute_skill_attack, fn ^caster, @target_id, opts ->
      assert opts[:skill_id] == 371
      assert opts[:skill_ratio] == Formulas.glacier_ratio(opts[:skill_level], 99)
      assert opts[:report_hit]
      assert opts[:skip_crit]
      {:ok, %{hit?: hit?, damage: 10, target_survives?: true, coma?: false}}
    end)
  end

  defp validate(caster) do
    case ChTigerfist.begin_attempt(caster, {:unit, @target_id}, 1, ChTigerfist.definition()) do
      {:ok, _caster} -> :ok
      error -> error
    end
  end

  defp cast(caster, level),
    do: ChTigerfist.cast(caster, {:unit, @target_id}, level, ChTigerfist.definition())

  defp caster(stage, opts \\ []) do
    character = %Character{
      id: 38_000,
      account_id: 38_000,
      name: "Champion",
      last_map: "prontera",
      last_x: 50,
      last_y: 50,
      sex: "M",
      str: 40,
      agi: 1,
      vit: 1,
      int: 1,
      dex: 1,
      luk: 1,
      base_level: 99,
      job_level: 50,
      class: 4016
    }

    state = PlayerState.new(character)
    learned = %{371 => 5, 372 => 10}
    stats = %{state.stats | progression: %{state.stats.progression | learned_skills: learned}}

    spheres =
      Enum.reduce(1..Keyword.get(opts, :spheres, 5)//1, SpiritSpheres.new(), fn _, acc ->
        acc |> SpiritSpheres.summon(future(), 5) |> elem(0)
      end)

    %{
      state
      | stats: stats,
        spirit_spheres: spheres,
        combo: Combo.open(Combo.new(), stage, {:mob, @target_id}, future())
    }
  end

  defp future, do: System.monotonic_time(:millisecond) + 10_000

  defp register_mob(id, opts) do
    mob_data = %MobDefinition{
      id: 1002,
      aegis_name: "PORING",
      name: "Poring",
      level: 1,
      hp: 50,
      sp: 0,
      stats: %{str: 1, agi: Keyword.fetch!(opts, :agi), vit: 1, int: 1, dex: 1, luk: 1},
      atk: 7,
      matk: 0,
      def: 0,
      mdef: 0,
      attack_range: 1,
      skill_range: 10,
      chase_range: 12,
      walk_speed: 400,
      attack_delay: 1_872,
      attack_motion: 672,
      client_attack_motion: 672,
      damage_motion: 480,
      element: {:water, 1},
      race: :plant,
      size: :medium,
      class: Aesir.ZoneServer.Mmo.MobManagement.MobMode.class([]),
      modes: []
    }

    spawn_ref = %MobSpawn{
      mob: 1002,
      amount: 1,
      respawn_time: 5_000,
      spawn_area: %SpawnArea{x: 60, y: 50}
    }

    state = MobState.new(id, mob_data, spawn_ref, "prontera", 60, 50)
    UnitRegistry.register_unit(:mob, id, MobState, state, self())
  end
end
