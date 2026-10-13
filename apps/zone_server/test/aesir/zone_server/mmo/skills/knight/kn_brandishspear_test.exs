defmodule Aesir.ZoneServer.Mmo.Skills.Knight.KnBrandishspearTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.Option
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Knight.KnBrandishspear
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.Stats.BaseStats

  setup :verify_on_exit!

  @target_id 5_000
  @one_handed_spear 1_402
  @riding_bit Option.id(:riding)
  # This mob is never registered in UnitRegistry, so any status row another
  # async test leaves behind under the same {:mob, id} key makes
  # `MobState.to_combatant/1` build a context for it and raise. Keep the
  # instance id out of the low range those tests reach for.
  @mob_caster_id 570_057

  describe "catalog registration" do
    test "definition carries the Renewal splash/target/sp values" do
      definition = definition()
      assert definition.max_level == 10
      assert definition.target_type == :target_enemy
      assert definition.damage_type == :no_damage
      assert definition.splash_radius == 2
      assert definition.range == 2
      assert definition.knockback == 2
      assert definition.require_weapon == [:one_handed_spear, :two_handed_spear]
      assert KnBrandishspear.definition(:renewal).sp_cost == List.duplicate(24, 10)
      assert KnBrandishspear.definition(:renewal).hit_count == -3
      assert KnBrandishspear.definition(:renewal).fixed_cast_time == List.duplicate(350, 10)
      assert KnBrandishspear.definition(:renewal).after_cast_delay == List.duplicate(500, 10)
      assert KnBrandishspear.definition(:renewal).cooldown == List.duplicate(1000, 10)
      assert KnBrandishspear.definition(:pre_renewal).sp_cost == List.duplicate(12, 10)
      assert KnBrandishspear.definition(:pre_renewal).hit_count == 1
      assert KnBrandishspear.definition(:pre_renewal).cast_time == List.duplicate(700, 10)
      assert KnBrandishspear.definition(:pre_renewal).fixed_cast_time == []
      assert KnBrandishspear.definition(:pre_renewal).cooldown == []
    end
  end

  describe "skill_ratio/3" do
    @tag game_mode: :pre_renewal
    test "classic is 100 + 20 per level plus the row's bonus" do
      assert KnBrandishspear.skill_ratio(1, 10) == 120
      assert KnBrandishspear.skill_ratio(3, 10) == 160
      assert Enum.map(0..1, &KnBrandishspear.skill_ratio(5, 10, &1)) == [300, 200]
      assert Enum.map(0..3, &KnBrandishspear.skill_ratio(10, 100, &1)) == [562, 525, 450, 300]
    end

    @tag game_mode: :renewal
    test "is 400 + 100 per level + 3 per point of STR on every row" do
      assert KnBrandishspear.skill_ratio(1, 10) == 530
      assert KnBrandishspear.skill_ratio(5, 60) == 1_080
      assert KnBrandishspear.skill_ratio(10, 100, 3) == 1_700
    end
  end

  describe "validate/4" do
    test "a mounted spear-wielding player passes" do
      caster = build_player(spear(), riding?: true)

      assert :ok = KnBrandishspear.validate(caster, {:unit, @target_id}, 1, definition())
    end

    test "an unmounted spear-wielding player is rejected" do
      caster = build_player(spear(), riding?: false)

      assert {:error, :requires_riding} =
               KnBrandishspear.validate(caster, {:unit, @target_id}, 1, definition())
    end

    test "a mounted player without a spear is rejected" do
      caster = build_player(fist(), riding?: true)

      assert {:error, :requires_spear} =
               KnBrandishspear.validate(caster, {:unit, @target_id}, 1, definition())
    end

    test "a mob caster bypasses both the spear and riding gates" do
      caster = build_mob(@mob_caster_id, 10, 10)

      assert :ok = KnBrandishspear.validate(caster, {:unit, @target_id}, 1, definition())
    end
  end

  describe "cast/4" do
    setup do
      stub(Combat, :resolve_combatant, fn @target_id ->
        {:ok, %{unit_type: :mob, unit_id: @target_id, position: {15, 25}}}
      end)

      stub(StatusStorage, :get_status, fn :player, 1_000, :sc_stripweapon -> nil end)
      stub(StatusInterpreter, :apply_status, fn :player, 1_000, :sc_stripweapon, _opts -> :ok end)
      :ok
    end

    @tag game_mode: :renewal
    test "renewal sweeps the five-row lane once, long range, with mob-native and equipment blow" do
      caster = build_player(spear(), riding?: true, str: 60, x: 10, y: 20)
      caster = put_in(caster.stats.modifiers.equipment, %{{:add_skill_blow, 57} => 3})
      level = 5

      expect(Combat, :execute_line_attack, fn ^caster, @target_id, opts ->
        assert caster.stats.modifiers.equipment[{:add_skill_blow, 57}] == 3
        assert opts[:skill_id] == 57
        assert opts[:skill_level] == level
        assert opts[:skill_ratio] == 1_080
        assert opts[:hit_divisions] == -3
        assert opts[:skip_crit] == true
        assert {opts[:offset], opts[:length], opts[:width]} == {0, 5, 2}
        assert opts[:base_distance] == 2
        assert opts[:origin] == {10, 20}
        assert opts[:native_target_types] == [:mob]
        assert opts[:delivery] == :direct
        [101, 102]
      end)

      reject(&Combat.knockback/5)

      assert {:ok, ^caster} =
               KnBrandishspear.cast(caster, {:unit, @target_id}, level, definition())
    end

    @tag game_mode: :pre_renewal
    test "classic sweeps one row per band, farthest first, short range" do
      caster = build_player(spear(), riding?: true)
      test_pid = self()

      stub(Combat, :execute_line_attack, fn ^caster, @target_id, opts ->
        assert opts[:width] == 2
        assert opts[:delivery] == :splash
        send(test_pid, {:sweep, opts[:offset], opts[:length], opts[:skill_ratio]})
        []
      end)

      assert {:ok, ^caster} = KnBrandishspear.cast(caster, {:unit, @target_id}, 10, definition())

      assert sweeps() == [{4, 1, 300}, {3, 1, 450}, {2, 1, 525}, {0, 2, 562}]

      assert {:ok, ^caster} = KnBrandishspear.cast(caster, {:unit, @target_id}, 5, definition())
      assert sweeps() == [{2, 1, 200}, {0, 2, 300}]

      assert {:ok, ^caster} = KnBrandishspear.cast(caster, {:unit, @target_id}, 3, definition())
      assert sweeps() == [{0, 2, 160}]
    end

    @tag game_mode: :pre_renewal
    test "a classic monster's every row takes the nearest rows' bonus" do
      caster = build_mob(@mob_caster_id, 10, 20)
      test_pid = self()

      stub(Combat, :execute_line_attack, fn ^caster, @target_id, opts ->
        send(test_pid, {:sweep, opts[:offset], opts[:length], opts[:skill_ratio]})
        []
      end)

      reject(&StatusInterpreter.apply_status/4)

      assert {:ok, ^caster} = KnBrandishspear.cast(caster, {:unit, @target_id}, 10, definition())
      assert sweeps() == [{4, 1, 562}, {3, 1, 562}, {2, 1, 562}, {0, 2, 562}]
    end

    @tag game_mode: :renewal
    test "casts from a mob caster using its STR in the ratio" do
      caster = build_mob(@mob_caster_id, 10, 20)
      level = 3

      expect(Combat, :execute_line_attack, fn ^caster, @target_id, opts ->
        assert opts[:skill_ratio] == KnBrandishspear.skill_ratio(level, 10)
        []
      end)

      reject(&Combat.knockback/5)

      assert {:ok, ^caster} =
               KnBrandishspear.cast(caster, {:unit, @target_id}, level, definition())
    end

    test "propagates a target resolution error and deals no damage" do
      caster = build_player(spear(), riding?: true)

      reject(&Combat.execute_line_attack/3)
      reject(&Combat.knockback/5)

      stub(Combat, :resolve_combatant, fn @target_id -> {:error, :target_not_found} end)

      assert {:error, :target_not_found} =
               KnBrandishspear.cast(caster, {:unit, @target_id}, 1, definition())
    end
  end

  describe "weapon change bar" do
    setup do
      stub(Combat, :resolve_combatant, fn @target_id ->
        {:ok, %{unit_type: :mob, unit_id: @target_id, position: {15, 25}}}
      end)

      stub(Combat, :execute_line_attack, fn _caster, @target_id, _opts -> [] end)
      :ok
    end

    test "a player's cast bars weapon changes for a second" do
      caster = build_player(spear(), riding?: true)
      stub(StatusStorage, :get_status, fn :player, 1_000, :sc_stripweapon -> nil end)

      expect(StatusInterpreter, :apply_status, 2, fn :player, 1_000, :sc_stripweapon, opts ->
        assert opts[:duration] == 1_000
        :ok
      end)

      for origin <- [:normal, :item] do
        assert {:ok, ^caster} =
                 KnBrandishspear.cast_with_origin(
                   caster,
                   {:unit, @target_id},
                   1,
                   definition(),
                   origin
                 )
      end
    end

    test "a longer bar is kept, and automatic casts bar nothing" do
      caster = build_player(spear(), riding?: true)
      later = System.monotonic_time(:millisecond) + 60_000

      stub(StatusStorage, :get_status, fn :player, 1_000, :sc_stripweapon ->
        %StatusEntry{type: :sc_stripweapon, expires_at: later}
      end)

      reject(&StatusInterpreter.apply_status/4)

      assert {:ok, ^caster} = KnBrandishspear.cast(caster, {:unit, @target_id}, 1, definition())

      stub(StatusStorage, :get_status, fn :player, 1_000, :sc_stripweapon -> nil end)

      assert {:ok, ^caster} =
               KnBrandishspear.cast_with_origin(
                 caster,
                 {:unit, @target_id},
                 1,
                 definition(),
                 :auto
               )
    end
  end

  defp sweeps do
    receive do
      {:sweep, offset, length, ratio} -> [{offset, length, ratio} | sweeps()]
    after
      0 -> []
    end
  end

  defp definition do
    {:ok, definition} = Catalog.by_name(:kn_brandishspear)
    definition
  end

  defp fist, do: %Equipment{}
  defp spear, do: %Equipment{right_hand: @one_handed_spear}

  defp build_player(equipment, opts) do
    x = Keyword.get(opts, :x, 10)
    y = Keyword.get(opts, :y, 20)
    str = Keyword.get(opts, :str, 1)
    riding? = Keyword.get(opts, :riding?, false)
    option = if riding?, do: @riding_bit, else: 0

    stats = %Stats{
      base_stats: %BaseStats{str: str, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
      combat_stats: %{atk: 1, def: 1, hit: 1, flee: 1, perfect_dodge: 1, matk: 1},
      derived_stats: %{max_hp: 100, max_sp: 50, aspd: 150},
      progression: %PlayerProgression{base_level: 70, job_level: 50, learned_skills: %{}},
      equipment: equipment
    }

    %PlayerState{
      character_id: 1_000,
      account_id: 1_000,
      x: x,
      y: y,
      map_name: "prontera",
      option: option,
      stats: stats
    }
  end

  defp build_mob(id, x, y) do
    mob_definition = %MobDefinition{
      id: 1_002,
      aegis_name: "TEST_MOB",
      name: "TestMob",
      level: 1,
      hp: 100,
      sp: 50,
      base_exp: 10,
      job_exp: 5,
      atk: 10,
      matk: 0,
      def: 5,
      mdef: 3,
      stats: %{str: 10, agi: 10, vit: 10, int: 5, dex: 10, luk: 5},
      attack_range: 1,
      skill_range: 10,
      chase_range: 12,
      element: {:neutral, 1},
      race: :formless,
      size: :medium,
      walk_speed: 200,
      attack_delay: 1_000,
      attack_motion: 500,
      client_attack_motion: 500,
      damage_motion: 400,
      ai_type: 0,
      modes: [],
      drops: []
    }

    spawn = %MobSpawn{
      mob: 1_002,
      amount: 1,
      respawn_time: 5_000,
      spawn_area: %MobSpawn.SpawnArea{x: x, y: y, xs: 0, ys: 0}
    }

    %MobState{
      instance_id: id,
      mob_id: 1_002,
      mob_data: mob_definition,
      spawn_ref: spawn,
      x: x,
      y: y,
      map_name: "prontera",
      hp: 100,
      max_hp: 100,
      sp: 50,
      max_sp: 50,
      spawned_at: System.system_time(:second),
      aggro_list: %{}
    }
  end
end
