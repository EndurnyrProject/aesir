defmodule Aesir.ZoneServer.Mmo.CombatMiscAttackTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.Net.SkillDamage
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.EquipComa
  alias Aesir.ZoneServer.Mmo.Combat.Knockback
  alias Aesir.ZoneServer.Mmo.Combat.MiscDamageCalculator
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.Stats.BaseStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  defmodule HpLessUnit do
    defstruct [:combatant, :x, :y]

    def to_combatant(%__MODULE__{combatant: combatant}), do: combatant
    def living?(%__MODULE__{}), do: true
  end

  setup :set_mimic_from_context
  setup :verify_on_exit!

  setup do
    Mimic.copy(EquipComa)
    Mimic.copy(Knockback)
    :ok
  end

  @caster_id 1000
  @target_id 2001
  @map_name "prontera"
  @center {150, 150}

  defp build_caster do
    stats = %Stats{
      base_stats: %BaseStats{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
      combat_stats: %{atk: 1, def: 1, hit: 1, flee: 1, perfect_dodge: 1, matk: 1},
      derived_stats: %{max_hp: 100, max_sp: 50, aspd: 150},
      progression: %PlayerProgression{base_level: 1, job_level: 1, learned_skills: %{}},
      equipment: %Equipment{}
    }

    %PlayerState{
      character_id: @caster_id,
      account_id: @caster_id,
      x: 150,
      y: 150,
      map_name: @map_name,
      stats: stats
    }
  end

  defp build_mob_state(unit_id, x, y) do
    mob_definition = %MobDefinition{
      id: 1002,
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
      attack_delay: 1000,
      attack_motion: 500,
      client_attack_motion: 500,
      damage_motion: 400,
      ai_type: 0,
      modes: [],
      drops: []
    }

    mob_spawn = %MobSpawn{
      mob: 1002,
      amount: 1,
      respawn_time: 5_000,
      spawn_area: %MobSpawn.SpawnArea{x: x, y: y, xs: 0, ys: 0}
    }

    %MobState{
      instance_id: unit_id,
      mob_id: 1002,
      mob_data: mob_definition,
      spawn_ref: mob_spawn,
      x: x,
      y: y,
      map_name: @map_name,
      hp: 100,
      max_hp: 100,
      sp: 50,
      max_sp: 50,
      spawned_at: System.system_time(:second),
      aggro_list: %{}
    }
  end

  defp stub_single_target_mob(x \\ 150, y \\ 150) do
    stub(UnitRegistry, :get_unit, fn
      :mob, @target_id -> {:ok, {MobState, build_mob_state(@target_id, x, y), self()}}
    end)

    stub(SpatialIndex, :get_unit_position, fn
      :mob, @target_id -> {:ok, {x, y, @map_name}}
    end)
  end

  describe "execute_misc_attack/3" do
    test "marks landed equipment-only misc blow after target-owner damage delivery" do
      caster = build_caster()
      caster = put_in(caster.stats.modifiers.equipment, %{{:add_skill_blow, 122} => 2})
      test_pid = self()
      stub_single_target_mob()

      stub(MiscDamageCalculator, :calculate_misc_damage, fn _attacker, _target, _opts ->
        {:ok, %{damage: 80, is_critical: false}}
      end)

      expect(EquipComa, :trigger?, fn attacker, target ->
        assert attacker.unit_type == :player
        assert target.unit_type == :mob
        true
      end)

      expect(StatusInterpreter, :absorb_damage, fn :mob, @target_id, 80, hit_info ->
        assert hit_info.coma?
        80
      end)

      stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, %SkillDamage{} = packet ->
        send(test_pid, {:packet, packet})
        :ok
      end)

      reject(&MobSession.apply_damage/3)

      expect(MobSession, :apply_coma, fn _pid, {:player, @caster_id} ->
        send(test_pid, :coma_delivered)
        :ok
      end)

      expect(Knockback, :skill, fn attacker, target, 122, result, options ->
        assert_received :coma_delivered
        assert attacker.unit_id == @caster_id
        assert attacker.equip_modifiers[{:add_skill_blow, 122}] == 2
        assert target.unit_id == @target_id
        assert result == %{hit?: true, target_survives?: true, coma?: true}

        assert options == [
                 base_distance: 3,
                 origin: {149, 150},
                 native_enabled: false,
                 native_target_types: [:player],
                 native_requires_survival: true
               ]

        send(test_pid, :knockback_requested)
        :ok
      end)

      assert :ok =
               Combat.execute_misc_attack(caster, @target_id,
                 skill_id: 122,
                 skill_level: 5,
                 base_damage: 250,
                 element: :fire,
                 base_distance: 3,
                 origin: {149, 150},
                 native_enabled: false,
                 native_target_types: [:player],
                 native_requires_survival: true
               )

      assert_received {:packet, %SkillDamage{damage: 80, skill_id: 122, level: 5}}
      assert_received :knockback_requested
    end

    test "zero misc damage never decides or delivers coma" do
      caster = build_caster()
      stub_single_target_mob()

      stub(MiscDamageCalculator, :calculate_misc_damage, fn _attacker, _target, _opts ->
        {:ok, %{damage: 0, is_critical: false}}
      end)

      reject(&EquipComa.trigger?/2)
      reject(&MobSession.apply_coma/2)

      expect(MobSession, :apply_damage, fn _pid, 0, @caster_id ->
        send(self(), :zero_damage_delivered)
        :ok
      end)

      expect(Knockback, :skill, fn attacker, target, 122, result, [] ->
        assert_received :zero_damage_delivered
        assert attacker.unit_id == @caster_id
        assert target.unit_id == @target_id
        assert result == %{hit?: true, target_survives?: true, coma?: false}
        :ok
      end)

      stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, %SkillDamage{} = packet ->
        assert packet.damage == 0
        :ok
      end)

      assert :ok =
               Combat.execute_misc_attack(caster, @target_id,
                 skill_id: 122,
                 skill_level: 5,
                 base_damage: 0
               )
    end

    test "HP-less misc targets return after delivery with conservative survival" do
      caster = build_caster()
      target = MobState.to_combatant(build_mob_state(@target_id, 150, 150))
      target_state = %HpLessUnit{combatant: target, x: 150, y: 150}
      test_pid = self()

      stub(UnitRegistry, :get_unit, fn :mob, @target_id ->
        {:ok, {HpLessUnit, target_state, self()}}
      end)

      stub(SpatialIndex, :get_unit_position, fn :mob, @target_id ->
        {:ok, {150, 150, @map_name}}
      end)

      stub(MiscDamageCalculator, :calculate_misc_damage, fn _attacker, ^target, _opts ->
        {:ok, %{damage: 80, is_critical: false}}
      end)

      expect(EquipComa, :trigger?, fn _attacker, ^target -> false end)
      stub(StatusInterpreter, :absorb_damage, fn :mob, @target_id, 80, _hit_info -> 80 end)
      stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)

      expect(MobSession, :apply_damage, fn _pid, 80, @caster_id ->
        send(test_pid, :damage_delivered)
        :ok
      end)

      expect(Knockback, :skill, fn _attacker, ^target, 122, result, [] ->
        assert_received :damage_delivered
        assert result == %{hit?: true, target_survives?: false, coma?: false}
        :ok
      end)

      assert :ok =
               Combat.execute_misc_attack(caster, @target_id,
                 skill_id: 122,
                 skill_level: 5,
                 base_damage: 250
               )
    end

    test "failed misc calculation never decides or delivers coma" do
      caster = build_caster()
      stub_single_target_mob()

      stub(MiscDamageCalculator, :calculate_misc_damage, fn _attacker, _target, _opts ->
        {:error, :failed}
      end)

      reject(&EquipComa.trigger?/2)
      reject(&Knockback.skill/5)
      reject(&MobSession.apply_coma/2)
      reject(&MobSession.apply_damage/3)
      reject(&Broadcast.to_in_range/5)

      assert {:error, :failed} =
               Combat.execute_misc_attack(caster, @target_id,
                 skill_id: 122,
                 skill_level: 5,
                 base_damage: 250
               )
    end

    test "a target rejected before misc calculation never decides coma" do
      caster = build_caster()
      stub_single_target_mob()

      stub(Aesir.ZoneServer.Mmo.Skill.Targeting, :validate_enemy, fn _attacker, _target ->
        {:error, :friendly_target}
      end)

      reject(&MiscDamageCalculator.calculate_misc_damage/3)
      reject(&EquipComa.trigger?/2)
      reject(&Knockback.skill/5)
      reject(&MobSession.apply_coma/2)
      reject(&MobSession.apply_damage/3)

      assert {:error, :friendly_target} =
               Combat.execute_misc_attack(caster, @target_id,
                 skill_id: 122,
                 skill_level: 5,
                 base_damage: 250
               )
    end

    test "full absorption consumes a misc coma roll without owner mutation" do
      caster = build_caster()
      stub_single_target_mob()

      stub(MiscDamageCalculator, :calculate_misc_damage, fn _attacker, _target, _opts ->
        {:ok, %{damage: 80, is_critical: false}}
      end)

      expect(EquipComa, :trigger?, fn _attacker, _target -> true end)

      expect(StatusInterpreter, :absorb_damage, fn :mob, @target_id, 80, hit_info ->
        assert hit_info.coma?
        0
      end)

      stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, %SkillDamage{} = packet ->
        assert packet.damage == 0
        :ok
      end)

      reject(&MobSession.apply_coma/2)
      reject(&MobSession.apply_damage/3)

      assert :ok =
               Combat.execute_misc_attack(caster, @target_id,
                 skill_id: 122,
                 skill_level: 5,
                 base_damage: 250
               )
    end

    test "a mob attacker follows ordinary misc owner delivery" do
      caster = build_mob_state(@caster_id, 150, 150)
      stub_single_target_mob()

      stub(Aesir.ZoneServer.Mmo.Skill.Targeting, :validate_enemy, fn attacker, target ->
        assert attacker.unit_type == :mob
        assert target.unit_type == :mob
        :ok
      end)

      stub(MiscDamageCalculator, :calculate_misc_damage, fn attacker, target, _opts ->
        assert attacker.unit_type == :mob
        assert target.unit_type == :mob
        {:ok, %{damage: 80, is_critical: false}}
      end)

      expect(StatusInterpreter, :absorb_damage, fn :mob, @target_id, 80, hit_info ->
        refute hit_info.coma?
        80
      end)

      stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)
      reject(&MobSession.apply_coma/2)
      expect(MobSession, :apply_damage, fn _pid, 80, @caster_id -> :ok end)

      assert :ok =
               Combat.execute_misc_attack(caster, @target_id,
                 skill_id: 122,
                 skill_level: 5,
                 base_damage: 250
               )
    end

    test "broadcasts a SkillDamage packet and applies the misc damage" do
      caster = build_caster()
      test_pid = self()
      stub_single_target_mob()

      stub(MiscDamageCalculator, :calculate_misc_damage, fn _a, _t, opts ->
        assert opts[:base_damage] == 250
        assert opts[:element] == :fire
        {:ok, %{damage: 80, is_critical: false}}
      end)

      stub(Broadcast, :to_in_range, fn @map_name, 150, 150, _range, %SkillDamage{} = packet ->
        send(test_pid, {:packet, packet})
        :ok
      end)

      stub(MobSession, :apply_damage, fn _pid, damage, @caster_id ->
        send(test_pid, {:damage, damage})
        :ok
      end)

      assert :ok =
               Combat.execute_misc_attack(caster, @target_id,
                 skill_id: 122,
                 skill_level: 5,
                 base_damage: 250,
                 element: :fire
               )

      assert_received {:packet, %SkillDamage{damage: 80, skill_id: 122, level: 5}}
      assert_received {:damage, 80}
    end
  end

  describe "execute_misc_splash/4" do
    test "hits every target in the splash for misc damage" do
      caster = build_caster()
      test_pid = self()

      stub(SpatialIndex, :get_all_units_in_range, fn @map_name, 150, 150, 2 ->
        [{:mob, 2001}, {:mob, 2002}]
      end)

      stub(UnitRegistry, :get_unit, fn
        :mob, 2001 -> {:ok, {MobState, build_mob_state(2001, 150, 150), self()}}
        :mob, 2002 -> {:ok, {MobState, build_mob_state(2002, 151, 150), self()}}
      end)

      stub(MiscDamageCalculator, :calculate_misc_damage, fn _a, _t, opts ->
        assert opts[:base_damage] == 200
        assert opts[:ignore_element]
        {:ok, %{damage: 40, is_critical: false}}
      end)

      stub(Broadcast, :to_in_range, fn _m, _x, _y, _r, %SkillDamage{} = packet ->
        send(test_pid, {:packet, packet})
        :ok
      end)

      stub(MobSession, :apply_damage, fn _pid, damage, @caster_id ->
        send(test_pid, {:damage, damage})
        :ok
      end)

      hits =
        Combat.execute_misc_splash(caster, @center, 1,
          skill_id: 122,
          skill_level: 5,
          base_damage: 200,
          element: :neutral,
          ignore_element: true
        )

      assert Enum.sort(hits) == [2001, 2002]
      assert_received {:packet, %SkillDamage{damage: 40, div: 1}}
      assert_received {:packet, %SkillDamage{damage: 40, div: 1}}
      assert_received {:damage, 40}
      assert_received {:damage, 40}
    end

    test "split damage divides one base across the selected living targets" do
      caster = build_caster()
      test_pid = self()

      stub(SpatialIndex, :get_all_units_in_range, fn @map_name, 150, 150, 2 ->
        [{:mob, 2001}, {:skill_unit, 0x4000_0001}, {:mob, 2002}]
      end)

      stub(UnitRegistry, :get_unit, fn
        :mob, 2001 -> {:ok, {MobState, build_mob_state(2001, 150, 150), self()}}
        :mob, 2002 -> {:ok, {MobState, build_mob_state(2002, 151, 150), self()}}
      end)

      stub(MiscDamageCalculator, :calculate_misc_damage, fn _a, _t, opts ->
        send(test_pid, {:calculated, opts})
        {:ok, %{damage: opts[:base_damage], is_critical: false}}
      end)

      stub(Broadcast, :to_in_range, fn _m, _x, _y, _r, %SkillDamage{} = packet ->
        send(test_pid, {:packet, packet})
        :ok
      end)

      stub(MobSession, :apply_damage, fn _pid, damage, @caster_id ->
        send(test_pid, {:damage, damage})
        :ok
      end)

      assert [2001, 2002] =
               Combat.execute_misc_splash(caster, @center, 1,
                 skill_id: 122,
                 skill_level: 5,
                 base_damage: 201,
                 element: :wind,
                 display_hit_count: 5,
                 split: true
               )

      assert_received {:calculated, [base_damage: 100, element: :wind]}
      assert_received {:calculated, [base_damage: 100, element: :wind]}
      assert_received {:packet, %SkillDamage{damage: 100, div: 5}}
      assert_received {:packet, %SkillDamage{damage: 100, div: 5}}
      assert_received {:damage, 100}
      assert_received {:damage, 100}
    end

    test "split damage returns cleanly when no living enemies are selected" do
      caster = build_caster()

      stub(SpatialIndex, :get_all_units_in_range, fn @map_name, 150, 150, 2 -> [] end)
      reject(&MiscDamageCalculator.calculate_misc_damage/3)

      assert [] =
               Combat.execute_misc_splash(caster, @center, 1,
                 skill_id: 122,
                 skill_level: 5,
                 base_damage: 201,
                 split: true
               )
    end

    test "display_hit_count changes only packet divisions" do
      caster = build_caster()
      test_pid = self()

      stub(SpatialIndex, :get_all_units_in_range, fn @map_name, 150, 150, 2 ->
        [{:mob, 2001}, {:mob, 2002}]
      end)

      stub(UnitRegistry, :get_unit, fn
        :mob, 2001 -> {:ok, {MobState, build_mob_state(2001, 150, 150), self()}}
        :mob, 2002 -> {:ok, {MobState, build_mob_state(2002, 151, 150), self()}}
      end)

      stub(MiscDamageCalculator, :calculate_misc_damage, fn _a, _t, opts ->
        send(test_pid, {:calculated, opts})
        {:ok, %{damage: 40, is_critical: false}}
      end)

      stub(Broadcast, :to_in_range, fn _m, _x, _y, _r, %SkillDamage{} = packet ->
        send(test_pid, {:packet, packet})
        :ok
      end)

      stub(MobSession, :apply_damage, fn _pid, damage, @caster_id ->
        send(test_pid, {:damage, damage})
        :ok
      end)

      hits =
        Combat.execute_misc_splash(caster, @center, 1,
          skill_id: 129,
          skill_level: 5,
          base_damage: 500,
          element: :neutral,
          display_hit_count: 5
        )

      assert Enum.sort(hits) == [2001, 2002]
      assert_received {:calculated, [base_damage: 500, element: :neutral]}
      assert_received {:calculated, [base_damage: 500, element: :neutral]}
      assert_received {:packet, %SkillDamage{damage: 40, div: 5}}
      assert_received {:packet, %SkillDamage{damage: 40, div: 5}}
      assert_received {:damage, 40}
      assert_received {:damage, 40}
    end

    test "rejects display hit counts that cannot be encoded as positive uint32 values" do
      caster = build_caster()

      for invalid <- [0, -1, 1.5, :many, 0x1_0000_0000] do
        assert_raise ArgumentError, ~r/invalid display hit count/, fn ->
          Combat.execute_misc_splash(caster, @center, 1,
            skill_id: 129,
            skill_level: 5,
            base_damage: 500,
            display_hit_count: invalid
          )
        end
      end
    end

    test "revalidates selected recipients and skips one that died before delivery" do
      caster = build_caster()
      test_pid = self()
      dead = %{build_mob_state(2001, 150, 150) | hp: 0, is_dead: true}
      living = build_mob_state(2002, 151, 150)

      stub(SpatialIndex, :get_all_units_in_range, fn @map_name, 150, 150, 2 ->
        [{:mob, 2001}, {:mob, 2002}]
      end)

      stub(UnitRegistry, :get_unit, fn
        :mob, 2001 -> {:ok, {MobState, dead, self()}}
        :mob, 2002 -> {:ok, {MobState, living, self()}}
      end)

      expect(MiscDamageCalculator, :calculate_misc_damage, fn _a, _t, _opts ->
        {:ok, %{damage: 40, is_critical: false}}
      end)

      stub(Broadcast, :to_in_range, fn _m, _x, _y, _r, %SkillDamage{} = packet ->
        send(test_pid, {:packet, packet})
        :ok
      end)

      expect(MobSession, :apply_damage, fn _pid, 40, @caster_id -> :ok end)

      assert [2002] =
               Combat.execute_misc_splash(caster, @center, 1,
                 skill_id: 129,
                 skill_level: 5,
                 base_damage: 500,
                 display_hit_count: 5
               )

      assert_received {:packet, %SkillDamage{target_id: 2002, div: 5}}
      refute_received {:packet, %SkillDamage{target_id: 2001}}
    end
  end
end
