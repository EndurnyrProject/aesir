defmodule Aesir.ZoneServer.Mmo.Skills.Monk.MoChaincomboTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Combo
  alias Aesir.ZoneServer.Mmo.Skills.Monk.MoChaincombo
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SpiritSpheres
  alias Aesir.ZoneServer.Unit.Player.Stats

  setup :verify_on_exit!

  @target_id 2_000

  test "definition preserves Renewal cost, range, and base delay" do
    assert {:ok, definition} = Catalog.by_id(272)
    assert definition.name == :mo_chaincombo
    assert definition.target_type == :target_enemy
    assert definition.range == -2
    assert definition.sp_cost == [5, 6, 7, 8, 9]
    assert definition.after_cast_delay == [1_000, 1_000, 1_000, 1_000, 1_000]
  end

  test "only the live Quadruple window for the retained target validates" do
    caster = caster(:quadruple, @target_id)

    assert :ok = MoChaincombo.validate(caster, {:unit, @target_id}, 3, MoChaincombo.definition())

    wrong_target = %{
      caster
      | combo: Combo.open(caster.combo, :quadruple, {:mob, 3_000}, future())
    }

    wrong_stage = %{
      caster
      | combo: Combo.open(caster.combo, :thrust, {:mob, @target_id}, future())
    }

    expired = %{caster | combo: Combo.open(caster.combo, :quadruple, {:mob, @target_id}, 0)}

    for state <- [wrong_target, wrong_stage, expired] do
      assert {:error, :invalid_combo} =
               MoChaincombo.validate(state, {:unit, @target_id}, 3, MoChaincombo.definition())
    end
  end

  test "knuckle hit owns one 6-division skill result and opens the Thrust window" do
    caster = caster(:quadruple, @target_id, knuckle?: true)
    old_generation = caster.combo.generation
    stub(Combat, :resolve_target_position, fn @target_id -> {:ok, :mob, {10, 10, "prontera"}} end)

    expect(Combat, :execute_skill_attack, fn ^caster, @target_id, opts ->
      assert opts[:skill_id] == 272
      assert opts[:skill_level] == 3
      assert opts[:skill_ratio] == 800
      assert opts[:display_hit_count] == 6
      assert opts[:skip_crit]
      :ok
    end)

    assert {:ok, updated} =
             MoChaincombo.cast(caster, {:unit, @target_id}, 3, MoChaincombo.definition())

    assert updated.combo.stage == :thrust
    assert updated.combo.target == {:mob, @target_id}
    assert updated.combo.generation == old_generation + 1
    assert updated.combo.deadline > System.monotonic_time(:millisecond)
  end

  test "non-knuckle hit keeps the four-division Renewal ratio" do
    caster = caster(:quadruple, @target_id)
    stub(Combat, :resolve_target_position, fn @target_id -> {:ok, :mob, {10, 10, "prontera"}} end)

    expect(Combat, :execute_skill_attack, fn ^caster, @target_id, opts ->
      assert opts[:skill_ratio] == 400
      assert opts[:display_hit_count] == 4
      :ok
    end)

    assert {:ok, %{combo: %{stage: :thrust}}} =
             MoChaincombo.cast(caster, {:unit, @target_id}, 3, MoChaincombo.definition())
  end

  test "the Thrust window uses the delay value supplied by the interpreter" do
    caster = caster(:quadruple, @target_id)

    definition = %{
      MoChaincombo.definition()
      | after_cast_delay: [1_000, 1_000, 500, 1_000, 1_000]
    }

    stub(Combat, :resolve_target_position, fn @target_id -> {:ok, :mob, {10, 10, "prontera"}} end)
    stub(Combat, :execute_skill_attack, fn ^caster, @target_id, _opts -> :ok end)

    before = System.monotonic_time(:millisecond)
    assert {:ok, updated} = MoChaincombo.cast(caster, {:unit, @target_id}, 3, definition)

    assert updated.combo.deadline >= before + 500
    assert updated.combo.deadline < before + 550
  end

  test "a failed hit does not advance the combo" do
    caster = caster(:quadruple, @target_id)
    stub(Combat, :resolve_target_position, fn @target_id -> {:ok, :mob, {10, 10, "prontera"}} end)

    stub(Combat, :execute_skill_attack, fn ^caster, @target_id, _opts ->
      {:error, :dead_target}
    end)

    assert {:error, :dead_target} =
             MoChaincombo.cast(caster, {:unit, @target_id}, 3, MoChaincombo.definition())

    assert caster.combo.stage == :quadruple
  end

  test "an expired predecessor is rejected before the weapon hit" do
    caster = %{
      caster(:quadruple, @target_id)
      | combo: Combo.open(Combo.new(), :quadruple, {:mob, @target_id}, 0)
    }

    reject(&Combat.execute_skill_attack/3)

    assert {:error, :invalid_combo} =
             MoChaincombo.cast(caster, {:unit, @target_id}, 3, MoChaincombo.definition())
  end

  test "the chain requires learned Thrust and one held sphere" do
    caster = caster(:quadruple, @target_id)
    empty = %{caster | spirit_spheres: SpiritSpheres.new()}

    unlearned = %{
      caster.stats
      | progression: %{caster.stats.progression | learned_skills: %{272 => 5}}
    }

    assert :ok =
             MoChaincombo.validate(empty, {:unit, @target_id}, 3, MoChaincombo.definition())

    assert :ok =
             MoChaincombo.validate(
               %{caster | stats: unlearned},
               {:unit, @target_id},
               3,
               MoChaincombo.definition()
             )

    stub(Combat, :resolve_target_position, fn @target_id -> {:ok, :mob, {10, 10, "prontera"}} end)
    expect(Combat, :execute_skill_attack, fn ^empty, @target_id, _opts -> :ok end)

    assert {:ok, %{combo: %{stage: :idle}}} =
             MoChaincombo.cast(empty, {:unit, @target_id}, 3, MoChaincombo.definition())
  end

  test "a reused id with another unit type cannot complete the chain" do
    caster = caster(:quadruple, @target_id)

    stub(Combat, :resolve_target_position, fn @target_id ->
      {:ok, :player, {10, 10, "prontera"}}
    end)

    reject(&Combat.execute_skill_attack/3)

    assert {:error, :invalid_combo} =
             MoChaincombo.cast(caster, {:unit, @target_id}, 3, MoChaincombo.definition())
  end

  defp caster(stage, target_id, opts \\ []) do
    base =
      PlayerState.new(%Character{
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
      })

    inventory =
      if opts[:knuckle?],
        do: [%InventoryItem{nameid: 1801, amount: 1, equip: 2, identify: 1}],
        else: []

    stats = %{
      base.stats
      | equipment: Stats.equipment_from_inventory(inventory),
        progression: %{base.stats.progression | learned_skills: %{272 => 5, 273 => 5}}
    }

    combo = Combo.open(Combo.new(), stage, {:mob, target_id}, future())
    {spirit_spheres, _entry} = SpiritSpheres.summon(base.spirit_spheres, future(), 5)
    %{base | stats: stats, combo: combo, spirit_spheres: spirit_spheres}
  end

  defp future, do: System.monotonic_time(:millisecond) + 10_000
end
