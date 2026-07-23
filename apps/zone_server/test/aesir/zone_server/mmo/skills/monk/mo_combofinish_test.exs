defmodule Aesir.ZoneServer.Mmo.Skills.Monk.MoCombofinishTest do
  use ExUnit.Case, async: true

  import Mimic
  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Combo
  alias Aesir.ZoneServer.Mmo.Skills.Monk.MoCombofinish
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SpiritSpheres

  setup :verify_on_exit!
  setup :setup_ets_tables

  @target_id 2_000

  test "definition preserves Renewal cost and delay" do
    assert {:ok, definition} = Catalog.by_id(273)
    assert definition.name == :mo_combofinish
    assert definition.target_type == :target_enemy
    assert definition.range == -2
    assert definition.splash_radius == 0
    assert definition.sp_cost == [3, 4, 5, 6, 7]
    assert definition.after_cast_delay == [1_000, 1_000, 1_000, 1_000, 1_000]
  end

  test "a Thrust hit is a single Renewal strike and closes the chain" do
    caster = caster(:thrust)

    expect(Combat, :resolve_target_position, fn @target_id ->
      {:ok, :mob, {60, 50, "prontera"}}
    end)

    expect(Combat, :execute_skill_attack, fn ^caster, @target_id, opts ->
      assert opts[:skill_id] == 273
      assert opts[:skill_level] == 3
      assert opts[:skill_ratio] == 740
      assert opts[:hit_count] == 1
      assert opts[:skip_crit]
      :ok
    end)

    assert {:ok, updated} =
             MoCombofinish.cast(caster, {:unit, @target_id}, 3, MoCombofinish.definition())

    assert updated.combo.stage == :idle
    assert updated.combo.target == nil
  end

  test "a failed strike leaves the Thrust window open" do
    caster = caster(:thrust)
    stub(Combat, :resolve_target_position, fn @target_id -> {:ok, :mob, {60, 50, "prontera"}} end)

    stub(Combat, :execute_skill_attack, fn ^caster, @target_id, _opts ->
      {:error, :dead_target}
    end)

    assert {:error, :dead_target} =
             MoCombofinish.cast(caster, {:unit, @target_id}, 3, MoCombofinish.definition())

    assert caster.combo.stage == :thrust
  end

  test "a Thrust that satisfies the Asura follow-up opens the extremity window" do
    caster = asura_ready_caster()
    old_generation = caster.combo.generation

    stub(Combat, :resolve_target_position, fn @target_id -> {:ok, :mob, {60, 50, "prontera"}} end)
    stub(Combat, :execute_skill_attack, fn ^caster, @target_id, _opts -> :ok end)

    assert {:ok, updated} =
             MoCombofinish.cast(caster, {:unit, @target_id}, 3, MoCombofinish.definition())

    assert updated.combo.stage == :extremity
    assert updated.combo.target == {:mob, @target_id}
    assert updated.combo.generation == old_generation + 1
    assert updated.combo.deadline > System.monotonic_time(:millisecond)
  end

  test "a Thrust missing Fury closes the chain instead of opening the Asura window" do
    caster = asura_ready_caster(fury?: false)

    stub(Combat, :resolve_target_position, fn @target_id -> {:ok, :mob, {60, 50, "prontera"}} end)
    stub(Combat, :execute_skill_attack, fn ^caster, @target_id, _opts -> :ok end)

    assert {:ok, updated} =
             MoCombofinish.cast(caster, {:unit, @target_id}, 3, MoCombofinish.definition())

    assert updated.combo.stage == :idle
  end

  test "a Thrust below the sphere threshold closes the chain" do
    caster = asura_ready_caster(spheres: 3)

    stub(Combat, :resolve_target_position, fn @target_id -> {:ok, :mob, {60, 50, "prontera"}} end)
    stub(Combat, :execute_skill_attack, fn ^caster, @target_id, _opts -> :ok end)

    assert {:ok, updated} =
             MoCombofinish.cast(caster, {:unit, @target_id}, 3, MoCombofinish.definition())

    assert updated.combo.stage == :idle
  end

  defp asura_ready_caster(opts \\ []) do
    base = caster(:thrust)

    stats = %{
      base.stats
      | progression: %{base.stats.progression | learned_skills: %{273 => 5, 271 => 5}}
    }

    spheres =
      Enum.reduce(1..Keyword.get(opts, :spheres, 5), base.spirit_spheres, fn _, acc ->
        {updated, _entry} = SpiritSpheres.summon(acc, future(), 5)
        updated
      end)

    if Keyword.get(opts, :fury?, true) do
      :ok =
        StatusStorage.apply_status(:player, base.character_id, :sc_explosionspirits,
          duration: 180_000
        )
    end

    %{base | stats: stats, spirit_spheres: spheres}
  end

  defp caster(stage) do
    character = %Character{
      id: 1_000,
      account_id: 1_000,
      name: "Monk",
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
      base_level: 70,
      job_level: 40,
      class: 15
    }

    state = PlayerState.new(character)
    %{state | combo: Combo.open(Combo.new(), stage, {:mob, @target_id}, future())}
  end

  defp future, do: System.monotonic_time(:millisecond) + 10_000
end
