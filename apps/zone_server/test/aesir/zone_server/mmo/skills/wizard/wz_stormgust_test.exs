defmodule Aesir.ZoneServer.Mmo.Skills.Wizard.WzStormgustTest do
  use ExUnit.Case, async: false
  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skills.Wizard.WzStormgust
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Mmo.Woe.Rules
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables
  setup :verify_on_exit!

  setup do
    Mimic.copy(Rules)
    :ok
  end

  @caster_id 1000
  @map_name "prontera"
  @center {150, 150}

  # Renewal WZ_STORMGUST ratio: 70 + 50 * level (skills/mage/stormgust.cpp:21).
  @level 10
  @expected_ratio 70 + 50 * @level

  defp group(state \\ %{}) do
    %Group{
      group_id: 1,
      skill_id: 89,
      skill_name: :wz_stormgust,
      level: @level,
      caster_id: @caster_id,
      caster_type: :player,
      map_name: @map_name,
      center: @center,
      cells: [],
      interval: 450,
      state: state
    }
  end

  defp stub_caster do
    stub(Combat, :resolve_combatant, fn @caster_id -> {:ok, %{unit_id: @caster_id}} end)
  end

  describe "on_place/1" do
    @tag game_mode: :renewal
    test "returns the 450ms interval, renewal duration, and empty state" do
      assert {:ok, placement} = WzStormgust.on_place(group())
      assert placement.interval == 450
      assert placement.duration == 4_500
      assert placement.state == %{}
    end

    @tag game_mode: :pre_renewal
    test "classic fields last 4.6 seconds" do
      assert {:ok, %{duration: 4_600}} = WzStormgust.on_place(group())
    end
  end

  describe "per-cell units" do
    test "a 9x9 field whose cells each reach one cell, sharing strikes with every Storm Gust" do
      assert {:ok, placement} = WzStormgust.on_place(group())
      assert length(placement.cells) == 81
      assert {146, 146} in placement.cells and {154, 154} in placement.cells
      assert %{unit_range: 1, no_overlap: true, path_check: true} = placement
    end

    @tag game_mode: :renewal
    test "a strike pushes away from the cell that struck" do
      test_pid = self()
      stub_caster()
      stub(StatusInterpreter, :apply_status, fn _type, _id, :sc_freeze, _params -> :ok end)

      stub_hit(fn opts ->
        send(test_pid, {:origin, opts[:origin], opts[:base_distance]})
        :ok
      end)

      assert {:ok, %Group{}} = WzStormgust.on_unit_hit(group(), {149, 151}, {:mob, 2001}, 0)
      assert_received {:origin, {149, 151}, 2}
    end

    test "strikes nobody while its caster is gone" do
      stub(Combat, :resolve_combatant, fn @caster_id -> {:error, :target_not_found} end)

      assert [] = WzStormgust.unit_targets(group(), {150, 150}, [{:mob, 2001}])
    end
  end

  describe "on_unit_hit/4" do
    @tag game_mode: :renewal
    test "hits each supplied mob once via the magic calculator and knocks it back" do
      test_pid = self()
      stub_caster()
      stub(StatusInterpreter, :apply_status, fn _type, _id, :sc_freeze, _params -> :ok end)

      stub(Combat, :apply_skill_unit_damage, fn caster,
                                                unit_type,
                                                target_id,
                                                89,
                                                @level,
                                                :water,
                                                @expected_ratio,
                                                opts ->
        assert caster.unit_id == @caster_id
        assert opts[:base_distance] == 2
        assert opts[:origin] == @center
        send(test_pid, {:hit, unit_type, target_id})
        :ok
      end)

      reject(&Combat.knockback/5)

      assert {:ok, %Group{}} = WzStormgust.on_unit_hit(group(), @center, {:mob, 2001}, 0)

      assert {:ok, %Group{}} = WzStormgust.on_unit_hit(group(), @center, {:mob, 2002}, 0)

      assert_received {:hit, :mob, 2001}
      assert_received {:hit, :mob, 2002}
      refute_received {:hit, :player, @caster_id}
    end

    test "keeps no targets when the caster cannot be resolved" do
      stub(Combat, :resolve_combatant, fn @caster_id -> {:error, :target_not_found} end)

      reject(&Combat.splash_targets/4)
      reject(&Combat.apply_skill_unit_damage/8)
      reject(&Combat.knockback/5)
      reject(&StatusInterpreter.apply_status/4)

      assert [] = WzStormgust.unit_targets(group(), @center, [{:mob, 2001}])
    end

    test "does not keep a dead mob among supplied candidates" do
      caster = CombatTestHelper.create_player_combatant(unit_id: @caster_id)

      definition =
        struct(MobDefinition,
          id: 1,
          level: 1,
          hp: 100,
          stats: %{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
          attack_range: 1,
          size: :medium,
          race: :brute,
          element: {:water, 1},
          walk_speed: 200,
          attack_delay: 1_000,
          attack_motion: 500,
          client_attack_motion: 500,
          damage_motion: 500
        )

      dead =
        struct(MobState,
          instance_id: 2001,
          mob_id: 1,
          mob_data: definition,
          map_name: @map_name,
          x: 150,
          y: 150,
          hp: 0,
          sp: 0,
          spawned_at: 0,
          is_dead: true
        )
        |> Aesir.TestMob.publish(max_hp: 100, max_sp: 0)

      UnitRegistry.register_unit(:mob, 2001, MobState, dead, self())
      stub(Combat, :resolve_combatant, fn @caster_id -> {:ok, caster} end)
      reject(&Combat.apply_skill_unit_damage/8)
      reject(&StatusInterpreter.apply_status/4)

      assert [] = WzStormgust.unit_targets(group(), @center, [{:mob, 2001}])
    end

    @tag game_mode: :renewal
    test "renewal rolls a 27 s freeze at 65 minus 5 per level percent on each damaging hit" do
      stub_caster()
      stub_target_resolution()
      stub_hit(fn opts -> opts[:additional_effect].(%{unit_id: @caster_id}, {:mob, 2001}) end)

      expect(StatusInterpreter, :apply_status, fn :mob, 2001, :sc_freeze, params ->
        assert params[:success_rate] == 15
        assert params[:duration] == 27_000
        assert params[:val1] == @level
        assert params[:caster_id] == @caster_id
        :ok
      end)

      assert {:ok, %Group{}} = WzStormgust.on_unit_hit(group(), @center, {:mob, 2001}, 0)
    end

    @tag game_mode: :renewal
    test "renewal rolls no freeze for a hit that dealt nothing" do
      stub_caster()
      stub_target_resolution()
      stub_hit(fn _opts -> :ok end)
      reject(&StatusInterpreter.apply_status/4)

      assert {:ok, %Group{}} = WzStormgust.on_unit_hit(group(), @center, {:mob, 2001}, 0)
    end

    @tag game_mode: :pre_renewal
    test "classic counts hits on the target itself and does not freeze before the third" do
      stub_caster()
      stub_target_resolution()
      stub_hit(&connect(&1, {:mob, 2001}))
      reject(&StatusInterpreter.apply_status/4)

      assert {:ok, %Group{}} = WzStormgust.on_unit_hit(group(), @center, {:mob, 2001}, 0)

      assert {:ok, %Group{}} =
               WzStormgust.on_unit_hit(%{group() | group_id: 2}, @center, {:mob, 2001}, 0)

      assert StatusStorage.storm_gust_counter(:mob, 2001) == 2
    end

    @tag game_mode: :pre_renewal
    test "classic tries a 150% 12 s freeze from the third counted hit and resets once it lands" do
      stub_caster()
      stub_target_resolution()
      stub_hit(&connect(&1, {:mob, 2001}))
      seed_counter(2)

      expect(StatusInterpreter, :apply_status, fn :mob, 2001, :sc_freeze, params ->
        assert params[:success_rate] == 150
        assert params[:duration] == 12_000
        :ok
      end)

      assert {:ok, %Group{}} = WzStormgust.on_unit_hit(group(), @center, {:mob, 2001}, 0)
      assert StatusStorage.storm_gust_counter(:mob, 2001) == 0
    end

    @tag game_mode: :pre_renewal
    test "classic keeps counting when the freeze does not land" do
      stub_caster()
      stub_target_resolution()
      stub_hit(&connect(&1, {:mob, 2001}))
      seed_counter(3)

      expect(StatusInterpreter, :apply_status, fn :mob, 2001, :sc_freeze, _params ->
        {:error, :immune}
      end)

      assert {:ok, %Group{}} = WzStormgust.on_unit_hit(group(), @center, {:mob, 2001}, 0)
      assert StatusStorage.storm_gust_counter(:mob, 2001) == 4
    end

    @tag game_mode: :pre_renewal
    test "classic resets a counter past 250 when the freeze does not land" do
      stub_caster()
      stub_target_resolution()
      stub_hit(&connect(&1, {:mob, 2001}))
      seed_counter(250)

      stub(StatusInterpreter, :apply_status, fn :mob, 2001, :sc_freeze, _params ->
        {:error, :immune}
      end)

      assert {:ok, %Group{}} = WzStormgust.on_unit_hit(group(), @center, {:mob, 2001}, 0)
      assert StatusStorage.storm_gust_counter(:mob, 2001) == 0
    end

    @tag game_mode: :pre_renewal
    test "classic clears the counter on a hit that dealt nothing, before any freeze" do
      stub_caster()
      stub_target_resolution()
      stub_hit(fn _opts -> {:ok, %{hit?: false}} end)
      seed_counter(5)
      reject(&StatusInterpreter.apply_status/4)

      assert {:ok, %Group{}} = WzStormgust.on_unit_hit(group(), @center, {:mob, 2001}, 0)
      assert StatusStorage.storm_gust_counter(:mob, 2001) == 0
    end

    @tag game_mode: :pre_renewal
    test "classic neither counts nor clears a target the siege rules refuse" do
      stub_caster()
      stub_target_resolution()
      seed_counter(2)

      stub(Rules, :validate_target, fn _caster, _target, %{skill_id: 89} ->
        {:error, :friendly}
      end)

      reject(&Combat.apply_skill_unit_damage/8)

      assert {:ok, %Group{}} = WzStormgust.on_unit_hit(group(), @center, {:mob, 2001}, 0)
      assert StatusStorage.storm_gust_counter(:mob, 2001) == 2
    end

    @tag game_mode: :pre_renewal
    test "classic clears the counter when the hit is refused" do
      stub_caster()
      stub_target_resolution()
      stub_hit(fn _opts -> {:error, :target_concealed} end)
      seed_counter(2)
      reject(&StatusInterpreter.apply_status/4)

      assert {:ok, %Group{}} = WzStormgust.on_unit_hit(group(), @center, {:mob, 2001}, 0)
      assert StatusStorage.storm_gust_counter(:mob, 2001) == 0
    end
  end

  defp stub_target_resolution do
    stub(Combat, :resolve_combatant, fn unit_type, unit_id ->
      {:ok, %{unit_type: unit_type, unit_id: unit_id, map_name: @map_name}}
    end)
  end

  defp stub_hit(fun) do
    stub(Combat, :apply_skill_unit_damage, fn _c, _ut, _tid, _sid, _lvl, _el, _ratio, opts ->
      fun.(opts)
    end)
  end

  # A damaging hit on a surviving target: its on-hit effect runs.
  defp connect(opts, target) do
    opts[:additional_effect].(%{unit_id: @caster_id}, target)
    {:ok, %{hit?: true}}
  end

  defp seed_counter(count) do
    for _ <- 1..count, do: StatusStorage.increment_storm_gust_counter(:mob, 2001)
  end

  test "carries the per-mode data" do
    assert WzStormgust.definition(:renewal).fixed_cast_time == List.duplicate(1500, 10)
    assert WzStormgust.definition(:pre_renewal).fixed_cast_time == []

    assert WzStormgust.definition(:pre_renewal).cast_time == [
             6000,
             7000,
             8000,
             9000,
             10_000,
             11_000,
             12_000,
             13_000,
             14_000,
             15_000
           ]

    assert WzStormgust.definition(:pre_renewal).after_cast_delay == List.duplicate(5000, 10)
    assert WzStormgust.definition(:pre_renewal).cooldown == []
  end

  @tag game_mode: :renewal
  test "renewal deals 70 plus 50 per level" do
    assert WzStormgust.skill_ratio(1) == 120
  end

  @tag game_mode: :pre_renewal
  test "classic deals 100 plus 40 per level" do
    assert WzStormgust.skill_ratio(1) == 140
  end
end
