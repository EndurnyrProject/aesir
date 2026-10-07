defmodule Aesir.ZoneServer.Mmo.Skills.Monk.MoBalkyoungTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.Knockback
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skills.Monk.MoBalkyoung
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment
  alias Aesir.ZoneServer.Unit.Player.Stats.Modifiers
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.Stats.BaseStats

  setup :verify_on_exit!

  setup do
    Mimic.copy(TargetResolver)
    :ok
  end

  @primary_target_id 42
  @splash_target_id 43

  defp caster do
    %PlayerState{
      character_id: 1,
      account_id: 1,
      x: 100,
      y: 100,
      map_name: "prontera",
      stats: %Stats{
        base_stats: %BaseStats{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
        combat_stats: %{atk: 1, def: 1, hit: 1, flee: 1, perfect_dodge: 1, matk: 1},
        derived_stats: %{max_hp: 100, max_sp: 50, aspd: 150},
        progression: %PlayerProgression{base_level: 70, job_level: 50, learned_skills: %{}},
        equipment: %Equipment{},
        modifiers: %Modifiers{}
      }
    }
  end

  @tag game_mode: :renewal
  test "defines the fixed Renewal cost, damage, area, and delay profile" do
    definition = MoBalkyoung.definition()

    assert definition.id == 1_016
    assert definition.target_type == :target_enemy
    assert definition.range == -1
    assert definition.hp_cost == [200]
    assert definition.sp_cost == [40]
    assert definition.splash_radius == 1
    assert definition.knockback == 5
    assert definition.after_cast_delay == [2_000]
    assert definition.duration == [4_500]
  end

  describe "cast/4" do
    setup do
      stub(Combat, :resolve_combatant, fn @primary_target_id ->
        {:ok, %{unit_type: :mob, unit_id: @primary_target_id, position: {101, 100}}}
      end)

      :ok
    end

    test "strikes only the primary target, without any knockback, then pushes and stuns the others" do
      caster = caster()
      test_pid = self()

      expect(Combat, :execute_skill_attack, fn ^caster, @primary_target_id, opts ->
        assert opts[:skill_id] == 1_016
        assert opts[:skill_level] == 1
        assert opts[:skill_ratio] == mode_value(800, 300)
        assert opts[:skip_crit]
        assert opts[:equipment_blow] == false
        refute Keyword.has_key?(opts, :base_distance)
        assert opts[:report_hit]
        {:ok, %{hit?: true, damage: 120, target_survives?: true, coma?: false}}
      end)

      stub(Combat, :splash_targets, fn "prontera", {101, 100}, 1, %{unit_id: 1} ->
        [{:mob, @primary_target_id}, {:mob, @splash_target_id}]
      end)

      stub(TargetResolver, :resolve, fn {:mob, target_id} ->
        {:ok, self(), %{id: target_id}, :mob}
      end)

      expect(Knockback, :knockback, fn :mob, @splash_target_id, 100, 100, 5, opts ->
        assert opts[:source_boss?] == false
        send(test_pid, :pushed)
        :ok
      end)

      expect(StatusInterpreter, :apply_status, fn :mob, @splash_target_id, :sc_stun, opts ->
        assert opts[:duration] == mode_value(4_500, 5_000)
        assert opts[:caster_id] == 1
        send(test_pid, :stunned)
        :ok
      end)

      :rand.seed(:exsss, {1, 2, 3})

      assert {:ok, ^caster} =
               MoBalkyoung.cast(caster, {:unit, @primary_target_id}, 1, definition())

      assert_received :pushed
      assert_received :stunned
    end

    test "a primary strike that deals no damage leaves the neighbours alone" do
      caster = caster()

      stub(Combat, :execute_skill_attack, fn _caster, _target, _opts ->
        {:ok, %{hit?: false, damage: 0, target_survives?: true, coma?: false}}
      end)

      reject(&Combat.splash_targets/4)
      reject(&Knockback.knockback/6)
      reject(&StatusInterpreter.apply_status/4)

      assert {:ok, ^caster} =
               MoBalkyoung.cast(caster, {:unit, @primary_target_id}, 1, definition())
    end

    test "a failed 70 percent roll pushes a neighbour without stunning it" do
      caster = caster()
      stub_damaging_strike()

      stub(Combat, :splash_targets, fn _map, _center, _radius, _caster ->
        [{:mob, @splash_target_id}]
      end)

      stub(TargetResolver, :resolve, fn {:mob, @splash_target_id} ->
        {:ok, self(), %{id: @splash_target_id}, :mob}
      end)

      expect(Knockback, :knockback, fn :mob, @splash_target_id, 100, 100, 5, _opts -> :ok end)
      reject(&StatusInterpreter.apply_status/4)

      :rand.seed(:exsss, {6, 7, 8})

      assert {:ok, ^caster} =
               MoBalkyoung.cast(caster, {:unit, @primary_target_id}, 1, definition())
    end

    test "preserves the typed player neighbour when unit ids collide" do
      caster = caster()
      stub_damaging_strike()

      stub(Combat, :splash_targets, fn _map, _center, _radius, _caster ->
        [{:player, @splash_target_id}]
      end)

      expect(TargetResolver, :resolve, fn {:player, @splash_target_id} ->
        {:ok, self(), %{id: @splash_target_id}, :player}
      end)

      expect(Knockback, :knockback, fn :player, @splash_target_id, 100, 100, 5, _opts -> :ok end)

      expect(StatusInterpreter, :apply_status, fn :player, @splash_target_id, :sc_stun, _opts ->
        :ok
      end)

      :rand.seed(:exsss, {1, 2, 3})

      assert {:ok, ^caster} =
               MoBalkyoung.cast(caster, {:unit, @primary_target_id}, 1, definition())
    end

    test "does not stun a neighbour that no longer resolves" do
      caster = caster()
      stub_damaging_strike()

      stub(Combat, :splash_targets, fn _map, _center, _radius, _caster ->
        [{:mob, @splash_target_id}]
      end)

      expect(TargetResolver, :resolve, fn {:mob, @splash_target_id} ->
        {:error, :target_not_found}
      end)

      stub(Knockback, :knockback, fn _type, _id, _x, _y, _distance, _opts -> :ok end)
      reject(&StatusInterpreter.apply_status/4)

      assert {:ok, ^caster} =
               MoBalkyoung.cast(caster, {:unit, @primary_target_id}, 1, definition())
    end
  end

  defp stub_damaging_strike do
    stub(Combat, :execute_skill_attack, fn _caster, _target, _opts ->
      {:ok, %{hit?: true, damage: 120, target_survives?: true, coma?: false}}
    end)
  end

  test "returns target resolution errors without applying splash effects" do
    caster = caster()

    stub(Combat, :resolve_combatant, fn @primary_target_id -> {:error, :target_not_found} end)
    reject(&Combat.execute_skill_attack/3)
    reject(&Knockback.knockback/6)
    reject(&StatusInterpreter.apply_status/4)

    assert {:error, :target_not_found} =
             MoBalkyoung.cast(caster, {:unit, @primary_target_id}, 1, definition())
  end

  defp definition do
    %Definition{
      id: 1_016,
      name: :mo_balkyoung,
      display_name: "Ki Explosion",
      max_level: 1,
      target_type: :target_enemy,
      damage_type: :damage,
      range: -1,
      hp_cost: [200],
      sp_cost: [40],
      splash_radius: 1,
      knockback: 5,
      after_cast_delay: [2_000],
      duration: [4_500]
    }
  end

  @tag game_mode: :pre_renewal
  test "classic carries the source's data" do
    {:ok, definition} = Catalog.by_id(1016)
    assert definition.hp_cost == [10]
    assert definition.sp_cost == [20]
    assert definition.duration == [5_000]
  end

  defp mode_value(renewal, pre_renewal),
    do: %{renewal: renewal, pre_renewal: pre_renewal}[GameMode.mode()]
end
