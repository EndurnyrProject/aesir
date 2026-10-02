defmodule Aesir.ZoneServer.Mmo.Skills.Paladin.PaPressureTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Paladin.PaPressure
  alias Aesir.ZoneServer.Mmo.StatusEffect.Helpers
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :verify_on_exit!

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})
    Mimic.copy(Helpers)
    :ok
  end

  @caster_id 47_001
  @target_id 47_002

  defp definition do
    {:ok, definition} = Catalog.by_name(:pa_pressure)
    definition
  end

  @tag game_mode: :renewal
  test "renewal definition: holy magic, 1 s cast + 0.4 s fixed, 1 s delay" do
    definition = definition()
    assert definition.id == 367
    assert definition.range == List.duplicate(9, 5)
    assert definition.sp_cost == [30, 35, 40, 45, 50]
    assert definition.element == :holy
    assert definition.damage_kind == :magic
    assert definition.cast_time == List.duplicate(1_000, 5)
    assert definition.fixed_cast_time == List.duplicate(400, 5)
    assert definition.after_cast_delay == List.duplicate(1_000, 5)
  end

  @tag game_mode: :pre_renewal
  test "classic definition: misc, element-less, 2-4 s cast and delay tables" do
    definition = definition()
    assert definition.element == :neutral
    assert definition.damage_kind == :misc
    assert definition.cast_time == [2_000, 2_500, 3_000, 3_500, 4_000]
    assert definition.fixed_cast_time == List.duplicate(0, 5)
    assert definition.after_cast_delay == [2_000, 2_500, 3_000, 3_500, 4_000]
  end

  @tag game_mode: :renewal
  test "renewal casts three displayed holy magic hits scaled by base level" do
    caster = player(99)

    expect(Combat, :execute_magic_attack, fn ^caster, @target_id, opts ->
      assert opts[:skill_id] == 367
      assert opts[:skill_level] == 3
      # (500 + 150 * 3) * 99 / 100
      assert opts[:skill_ratio] == 940
      assert opts[:element] == :holy
      assert opts[:hit_count] == 1
      assert opts[:display_hit_count] == 3
      assert opts[:skip_range] == true
      {:ok, {:mob, @target_id}}
    end)

    assert {:ok, ^caster} = PaPressure.cast(caster, {:unit, @target_id}, 3, definition())
  end

  @tag game_mode: :renewal
  test "a renewal mob caster scales by its own level" do
    caster = mob_caster(120)

    expect(Combat, :execute_magic_attack, fn ^caster, @target_id, opts ->
      assert opts[:skill_ratio] == div((500 + 150 * 2) * 120, 100)
      {:ok, {:player, @target_id}}
    end)

    assert {:ok, ^caster} = PaPressure.cast(caster, {:unit, @target_id}, 2, definition())
  end

  @tag game_mode: :pre_renewal
  test "classic deals fixed misc damage and drains a share of a player's max SP" do
    caster = player(99)
    target = combatant(:player, @target_id, max_sp: 400)
    stub(Combat, :resolve_combatant, fn @target_id -> {:ok, target} end)

    expect(Combat, :execute_misc_attack, fn ^caster, @target_id, opts ->
      assert opts[:skill_id] == 367
      assert opts[:skill_level] == 3
      assert opts[:base_damage] == 1_400
      assert opts[:ignore_element] == true
      :ok
    end)

    # 15 + 5 * 3 = 30 percent of 400
    expect(Helpers, :consume_sp, fn {:player, @target_id}, 120 -> :ok end)

    assert {:ok, ^caster} = PaPressure.cast(caster, {:unit, @target_id}, 3, definition())
  end

  @tag game_mode: :pre_renewal
  test "classic skips the SP drain on mobs" do
    caster = player(99)

    stub(Combat, :resolve_combatant, fn @target_id ->
      {:ok, combatant(:mob, @target_id, max_sp: 50)}
    end)

    stub(Combat, :execute_misc_attack, fn _caster, _target, _opts -> :ok end)
    reject(&Helpers.consume_sp/2)

    assert {:ok, ^caster} = PaPressure.cast(caster, {:unit, @target_id}, 1, definition())
  end

  @tag game_mode: :pre_renewal
  test "classic refuses a hiding target without attacking" do
    caster = player(99)

    stub(Combat, :resolve_combatant, fn @target_id ->
      {:ok, combatant(:player, @target_id, max_sp: 400)}
    end)

    :ok = StatusStorage.apply_status(:player, @target_id, :sc_hiding, val1: 1)
    reject(&Combat.execute_misc_attack/3)

    assert {:error, :target_hidden} =
             PaPressure.cast(caster, {:unit, @target_id}, 1, definition())
  end

  defp player(base_level) do
    PlayerState.new(%Character{
      id: @caster_id,
      account_id: @caster_id,
      name: "Paladin",
      last_map: "prontera",
      last_x: 50,
      last_y: 50,
      sex: "M",
      str: 1,
      agi: 1,
      vit: 1,
      int: 1,
      dex: 1,
      luk: 1,
      base_level: base_level,
      job_level: 50,
      class: 4015
    })
  end

  defp mob_caster(level) do
    mob_data =
      struct(MobDefinition, %{
        id: 1_002,
        aegis_name: "TEST_MOB",
        name: "Test Mob",
        level: level,
        hp: 1_000,
        stats: %{str: 40, agi: 30, vit: 50, int: 20, dex: 35, luk: 15},
        atk: 50,
        matk: 60,
        def: 25,
        mdef: 10,
        attack_range: 2
      })

    spawn = %MobSpawn{
      mob: 1_002,
      amount: 1,
      respawn_time: 5_000,
      spawn_area: %SpawnArea{x: 150, y: 150}
    }

    MobState.new(@caster_id, mob_data, spawn, "prontera", 150, 150)
  end

  defp combatant(type, id, max_sp: max_sp) do
    %Combatant{
      unit_type: type,
      unit_id: id,
      max_sp: max_sp,
      base_stats: %{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
      combat_stats: %{},
      progression: %{base_level: 1, job_level: 1},
      element: {:neutral, 1},
      race: :formless,
      size: :medium,
      weapon: %{type: :fist, element: :neutral, size: :medium},
      attack_range: 1,
      attack_delay_ms: 500,
      position: {150, 150},
      map_name: "prontera"
    }
  end
end
