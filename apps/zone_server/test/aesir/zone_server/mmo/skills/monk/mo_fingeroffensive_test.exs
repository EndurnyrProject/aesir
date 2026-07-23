defmodule Aesir.ZoneServer.Mmo.Skills.Monk.MoFingeroffensiveTest do
  use ExUnit.Case, async: true
  import Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Monk.MoFingeroffensive
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!
  setup :setup_ets_tables

  @caster_id 1_000
  @target_id 2_000

  test "declares Throw Spirit Sphere's verified Renewal costs, range, and timing" do
    assert {:ok, definition} = Catalog.by_id(267)
    assert definition.name == :mo_fingeroffensive
    assert definition.target_type == :target_enemy
    assert definition.damage_type == :damage
    assert definition.range == 9
    assert definition.max_level == 5
    assert definition.hit_count == 5
    assert definition.sp_cost == [12, 16, 20, 24, 28]
    assert definition.sphere_cost == List.duplicate(1, 5)
    assert definition.cast_time == List.duplicate(500, 5)
    assert definition.fixed_cast_time == List.duplicate(500, 5)
    assert definition.after_cast_delay == List.duplicate(500, 5)
    assert definition.cooldown == List.duplicate(1_000, 5)
  end

  test "an unrooted hit against an unrooted target uses the base Renewal ratio across five hits" do
    caster = caster()
    stub(Combat, :resolve_target_position, fn @target_id -> {:ok, :mob, {10, 10, "prontera"}} end)

    expect(Combat, :execute_skill_attack, fn ^caster, @target_id, opts ->
      assert opts[:skill_id] == 267
      assert opts[:skill_level] == 1
      assert opts[:skill_ratio] == 800
      assert opts[:hit_count] == 5
      assert opts[:skip_crit]
      assert opts[:skip_range]
      :ok
    end)

    assert {:ok, updated} =
             MoFingeroffensive.cast(
               caster,
               {:unit, @target_id},
               1,
               MoFingeroffensive.definition()
             )

    refute PlayerState.walk_delayed?(updated, System.monotonic_time(:millisecond))
  end

  test "a hit against a target rooted to an unrelated third party still gains the Root bonus" do
    caster = caster()
    stub(Combat, :resolve_target_position, fn @target_id -> {:ok, :mob, {10, 10, "prontera"}} end)

    place_blade_stop(:mob, @target_id, %{
      peer: {:player, 9_000},
      link_id: make_ref(),
      root_level: 5
    })

    expect(Combat, :execute_skill_attack, fn ^caster, @target_id, opts ->
      assert opts[:skill_ratio] == 1_800
      :ok
    end)

    assert {:ok, _updated} =
             MoFingeroffensive.cast(
               caster,
               {:unit, @target_id},
               3,
               MoFingeroffensive.definition()
             )

    refute StatusStorage.has_status?(:player, @caster_id, :sc_bladestop)
    assert StatusStorage.has_status?(:mob, @target_id, :sc_bladestop)
  end

  test "a rooted caster at the Throw minimum gains the bonus against the linked target and closes the pair" do
    caster = caster()
    stub_entity_info()
    stub(Combat, :resolve_target_position, fn @target_id -> {:ok, :mob, {10, 10, "prontera"}} end)
    link_pair(@caster_id, {:mob, @target_id}, 2)

    expect(Combat, :execute_skill_attack, fn ^caster, @target_id, opts ->
      assert opts[:skill_ratio] == 1_200
      :ok
    end)

    assert {:ok, _updated} =
             MoFingeroffensive.cast(
               caster,
               {:unit, @target_id},
               1,
               MoFingeroffensive.definition()
             )

    refute StatusStorage.has_status?(:player, @caster_id, :sc_bladestop)
    refute StatusStorage.has_status?(:mob, @target_id, :sc_bladestop)
  end

  test "a rooted caster's successful hit closes their own pair even against an unrelated target" do
    caster = caster()
    stub_entity_info()
    stub(Combat, :resolve_target_position, fn @target_id -> {:ok, :mob, {10, 10, "prontera"}} end)
    link_pair(@caster_id, {:mob, 3_000}, 2)

    expect(Combat, :execute_skill_attack, fn ^caster, @target_id, opts ->
      assert opts[:skill_ratio] == 800
      :ok
    end)

    assert {:ok, _updated} =
             MoFingeroffensive.cast(
               caster,
               {:unit, @target_id},
               1,
               MoFingeroffensive.definition()
             )

    refute StatusStorage.has_status?(:player, @caster_id, :sc_bladestop)
    refute StatusStorage.has_status?(:mob, 3_000, :sc_bladestop)
  end

  test "a rooted caster below the Throw minimum is rejected with no attack and no cost" do
    caster = caster()
    stub(Combat, :resolve_target_position, fn @target_id -> {:ok, :mob, {10, 10, "prontera"}} end)
    link_pair(@caster_id, {:mob, @target_id}, 1)

    reject(&Combat.execute_skill_attack/3)

    assert {:error, :insufficient_root_level} =
             MoFingeroffensive.cast(
               caster,
               {:unit, @target_id},
               1,
               MoFingeroffensive.definition()
             )

    assert StatusStorage.has_status?(:player, @caster_id, :sc_bladestop)
  end

  test "a successful hit above level one locks the caster's own walk speed" do
    caster = caster()
    stub(Combat, :resolve_target_position, fn @target_id -> {:ok, :mob, {10, 10, "prontera"}} end)
    stub(Combat, :execute_skill_attack, fn ^caster, @target_id, _opts -> :ok end)

    now = System.monotonic_time(:millisecond)

    assert {:ok, updated} =
             MoFingeroffensive.cast(
               caster,
               {:unit, @target_id},
               3,
               MoFingeroffensive.definition()
             )

    assert PlayerState.walk_delayed?(updated, now)
  end

  test "a failed attack charges nothing and leaves an eligible Root pair open" do
    caster = caster()
    stub(Combat, :resolve_target_position, fn @target_id -> {:ok, :mob, {10, 10, "prontera"}} end)
    link_pair(@caster_id, {:mob, @target_id}, 5)

    stub(Combat, :execute_skill_attack, fn ^caster, @target_id, _opts ->
      {:error, :dead_target}
    end)

    assert {:error, :dead_target} =
             MoFingeroffensive.cast(
               caster,
               {:unit, @target_id},
               3,
               MoFingeroffensive.definition()
             )

    assert StatusStorage.has_status?(:player, @caster_id, :sc_bladestop)
  end

  test "a non-unit target fails cleanly" do
    reject(&Combat.execute_skill_attack/3)

    assert {:error, :invalid_target} =
             MoFingeroffensive.cast(caster(), :self, 1, MoFingeroffensive.definition())
  end

  defp caster do
    PlayerState.new(%Character{
      id: @caster_id,
      account_id: @caster_id,
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
  end

  defp place_blade_stop(unit_type, unit_id, state) do
    :ok = StatusStorage.apply_status(unit_type, unit_id, :sc_bladestop, state: state)
  end

  defp link_pair(monk_id, {caught_type, caught_id} = caught, monk_level) do
    link_id = make_ref()

    place_blade_stop(:player, monk_id, %{peer: caught, link_id: link_id, root_level: monk_level})

    place_blade_stop(caught_type, caught_id, %{
      peer: {:player, monk_id},
      link_id: link_id,
      root_level: 0
    })

    link_id
  end

  defp stub_entity_info do
    Mimic.copy(UnitRegistry)

    stub(UnitRegistry, :get_unit_info, fn _type, id ->
      {:ok, %{unit_id: id, race: :human, element: :neutral, boss_flag: false, stats: %{}}}
    end)
  end
end
