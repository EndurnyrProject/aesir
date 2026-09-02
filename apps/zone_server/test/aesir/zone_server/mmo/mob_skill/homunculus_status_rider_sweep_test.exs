defmodule Aesir.ZoneServer.Mmo.MobSkill.HomunculusStatusRiderSweepTest do
  use ExUnit.Case, async: false
  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.Skills.Acolyte.AlDecagi
  alias Aesir.ZoneServer.Mmo.Skills.Crusader.CrHolycross
  alias Aesir.ZoneServer.Mmo.Skills.Crusader.CrShieldcharge
  alias Aesir.ZoneServer.Mmo.Skills.Mage.MgFrostdiver
  alias Aesir.ZoneServer.Mmo.Skills.Swordsman.SmBash
  alias Aesir.ZoneServer.Mmo.Skills.Thief.TfPoison
  alias Aesir.ZoneServer.Mmo.Skills.Thief.TfSprinklesand
  alias Aesir.ZoneServer.Mmo.Skills.Thief.TfThrowstone
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.Stats.BaseStats
  alias Aesir.ZoneServer.Unit.Stats.CombatStats
  alias Aesir.ZoneServer.Unit.Stats.CurrentState
  alias Aesir.ZoneServer.Unit.Stats.DerivedStats

  setup :verify_on_exit!

  @target {:homunculus, 90_001}
  @riders [
    {TfPoison, 10, :sc_poison},
    {TfThrowstone, 1, :sc_stun},
    {TfSprinklesand, 1, :sc_blind},
    {AlDecagi, 48, :sc_decreaseagi},
    {SmBash, 6, nil},
    {MgFrostdiver, 10, :sc_freeze},
    {CrHolycross, 10, :sc_blind},
    {CrShieldcharge, 5, :sc_stun}
  ]

  test "confirmed mob hits apply each canonical typed rider with mob source identity" do
    stub_combat(true)
    capture_statuses()

    for {module, level, expected_status} <- @riders do
      flush_statuses()
      :rand.seed(:exsss, {123, 124, 125})
      assert_cast_dispatched(module.cast(mob(), {:unit, @target}, level, module.definition()))

      case expected_status do
        nil -> refute_received {:status, _, _, _}
        status -> assert_received {:status, :homunculus, ^status, :mob}
      end
    end
  end

  test "misses and failed delivery apply no Homunculus rider" do
    stub_combat(false)
    capture_statuses()

    for {module, level, _status} <- @riders do
      flush_statuses()
      :rand.seed(:exsss, {6, 7, 8})
      caster = if module == AlDecagi, do: decagi_miss_mob(), else: mob()
      level = if module == AlDecagi, do: 1, else: level
      _ = module.cast(caster, {:unit, @target}, level, module.definition())
      refute_received {:status, _, _, _}
    end
  end

  test "player casts retain player source identity and learned Fatal Blow" do
    stub_combat(true)
    capture_statuses()

    for {module, level, expected_status} <- @riders do
      flush_statuses()
      :rand.seed(:exsss, {123, 124, 125})
      assert_cast_dispatched(module.cast(player(), {:unit, @target}, level, module.definition()))

      expected_status = if module == SmBash, do: :sc_stun, else: expected_status
      assert_received {:status, :homunculus, ^expected_status, :player}
    end
  end

  test "all eight rider skills occur in the current imported mob rows" do
    path = Application.app_dir(:zone_server, "priv/db/re/mob_skills/mob_skills.yml")

    imported_ids =
      path
      |> YamlElixir.read_from_file!()
      |> Map.values()
      |> List.flatten()
      |> Enum.map(& &1["skill_id"])
      |> MapSet.new()

    ids = Enum.map(@riders, fn {module, _level, _status} -> module.definition().id end)
    assert MapSet.subset?(MapSet.new(ids), imported_ids)
  end

  defp stub_combat(connected?) do
    stub(Combat, :execute_skill_attack, fn _caster, _target, _opts ->
      {:ok, %{hit?: connected?}}
    end)

    stub(Combat, :execute_misc_attack, fn _caster, _target, _opts ->
      if connected?, do: :ok, else: {:error, :miss}
    end)

    stub(Combat, :execute_magic_attack, fn _caster, target, _opts ->
      if connected?, do: {:ok, target}, else: {:error, :miss}
    end)

    stub(Combat, :knockback, fn _type, _id, _x, _y, _distance -> :ok end)
  end

  defp capture_statuses do
    test_pid = self()

    stub(StatusInterpreter, :apply_status, fn type, _id, status, opts ->
      send(test_pid, {:status, type, status, opts[:source_type]})
      :ok
    end)
  end

  defp flush_statuses do
    receive do
      {:status, _, _, _} -> flush_statuses()
    after
      0 -> :ok
    end
  end

  defp assert_cast_dispatched({:ok, _caster}), do: :ok

  defp mob do
    %MobState{
      instance_id: 80_001,
      mob_id: 1002,
      mob_data: %MobDefinition{
        id: 1002,
        aegis_name: "RIDER_SWEEP",
        name: "Rider Sweep",
        level: 100,
        hp: 1_000,
        stats: %{str: 10, agi: 10, vit: 10, int: 100, dex: 10, luk: 10},
        atk: 100,
        matk: 100,
        def: 0,
        mdef: 0,
        attack_range: 1,
        walk_speed: 200,
        attack_delay: 1_000,
        attack_motion: 500,
        client_attack_motion: 500,
        damage_motion: 500,
        element: {:neutral, 1},
        race: :formless,
        size: :medium,
        modes: []
      },
      spawn_ref: nil,
      map_name: "rider_sweep",
      x: 50,
      y: 50,
      hp: 1_000,
      max_hp: 1_000,
      sp: 100,
      max_sp: 100,
      spawned_at: 0
    }
  end

  defp decagi_miss_mob do
    caster = mob()
    %{caster | mob_data: %{caster.mob_data | level: 1, stats: %{caster.mob_data.stats | int: 1}}}
  end

  defp player do
    stats = %Stats{
      base_stats: %BaseStats{str: 10, agi: 10, vit: 10, int: 100, dex: 10, luk: 10},
      derived_stats: %DerivedStats{max_hp: 1_000, max_sp: 100},
      combat_stats: %CombatStats{atk: 100, matk: 100, matk_min: 100, matk_max: 100},
      current_state: %CurrentState{hp: 1_000, sp: 100},
      equipment: %Equipment{},
      progression: %PlayerProgression{
        base_level: 1_000,
        job_level: 50,
        learned_skills: %{145 => 1}
      }
    }

    %PlayerState{character_id: 70_001, map_name: "rider_sweep", x: 50, y: 50, stats: stats}
  end
end
