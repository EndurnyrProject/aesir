defmodule Aesir.ZoneServer.Mmo.CombatMagicDamageTest do
  use ExUnit.Case, async: true
  import Mimic

  @moduletag :capture_log

  alias Aesir.Net.SkillDamage
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.EquipComa
  alias Aesir.ZoneServer.Mmo.Combat.Knockback
  alias Aesir.ZoneServer.Mmo.Combat.MagicDamageCalculator
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.Stats.BaseStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  setup do
    Mimic.copy(EquipComa)
    Mimic.copy(Knockback)
    :ok
  end

  @caster_id 1000
  @target_id 2001
  @map_name "prontera"
  @skill_id 28
  @skill_level 5

  defp build_caster do
    stats = %Stats{
      current_state: %{hp: 100},
      base_stats: %BaseStats{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
      combat_stats: %{atk: 1, def: 1, hit: 1, flee: 1, perfect_dodge: 1, matk: 100},
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
      action_state: :idle,
      stats: stats
    }
  end

  defp build_mob_state(unit_id, x, y, element) do
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
      element: element,
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

  defp stub_mob_target(x, y, element) do
    stub(UnitRegistry, :get_unit, fn
      :mob, @target_id -> {:ok, {MobState, build_mob_state(@target_id, x, y, element), self()}}
    end)

    stub(SpatialIndex, :get_unit_position, fn
      :mob, @target_id -> {:ok, {x, y, @map_name}}
    end)
  end

  describe "execute_magic_damage/4" do
    test "direct magic damage applies equipment blow once after final delivery" do
      caster =
        put_in(build_caster().stats.modifiers.equipment, %{{:add_skill_blow, @skill_id} => 2})

      stub_mob_target(150, 150, {:neutral, 1})

      expect(EquipComa, :trigger?, fn _attacker, _target -> false end)

      expect(StatusInterpreter, :absorb_damage, fn :mob, @target_id, 50, hit_info ->
        assert hit_info.dmg_type == :magic
        50
      end)

      stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)
      expect(MobSession, :apply_damage, fn _pid, 50, @caster_id -> :ok end)

      expect(Knockback, :skill, fn attacker, target, @skill_id, result, [] ->
        assert attacker.equip_modifiers[{:add_skill_blow, @skill_id}] == 2
        assert target.unit_id == @target_id
        assert result == %{hit?: true, target_survives?: true, coma?: false}
        :ok
      end)

      assert :ok =
               Combat.execute_magic_damage(caster, @target_id, 50,
                 skill_id: @skill_id,
                 skill_level: @skill_level
               )
    end

    test "applies the element modifier and broadcasts a SkillDamage packet (holy vs undead)" do
      caster = build_caster()
      test_pid = self()
      stub_mob_target(150, 150, {:undead, 1})

      expect(EquipComa, :trigger?, fn _attacker, _target -> false end)

      expect(StatusInterpreter, :absorb_damage, fn :mob, @target_id, 125, hit_info ->
        refute hit_info.coma?
        125
      end)

      stub(Broadcast, :to_in_range, fn @map_name, 150, 150, _range, packet ->
        send(test_pid, {:packet, packet})
        :ok
      end)

      stub(MobSession, :apply_damage, fn _pid, damage, @caster_id ->
        send(test_pid, {:damage, damage})
        :ok
      end)

      assert :ok =
               Combat.execute_magic_damage(caster, @target_id, 100,
                 skill_id: @skill_id,
                 skill_level: @skill_level,
                 element: :holy
               )

      assert_received {:packet,
                       %SkillDamage{damage: 125, div: 1, skill_id: @skill_id, level: @skill_level}}

      assert_received {:damage, 125}
    end

    test "passes the amount through unchanged for matching element (neutral vs neutral)" do
      caster = build_caster()
      test_pid = self()
      stub_mob_target(150, 150, {:neutral, 1})

      stub(Broadcast, :to_in_range, fn _m, _x, _y, _r, _p -> :ok end)

      stub(MobSession, :apply_damage, fn _pid, damage, @caster_id ->
        send(test_pid, {:damage, damage})
        :ok
      end)

      assert :ok =
               Combat.execute_magic_damage(caster, @target_id, 200,
                 skill_id: @skill_id,
                 skill_level: @skill_level,
                 element: :neutral
               )

      assert_received {:damage, 200}
    end

    test "defaults to :neutral element when :element opt is absent" do
      caster = build_caster()
      test_pid = self()
      stub_mob_target(150, 150, {:neutral, 1})

      stub(Broadcast, :to_in_range, fn _m, _x, _y, _r, _p -> :ok end)

      stub(MobSession, :apply_damage, fn _pid, damage, _caster ->
        send(test_pid, {:damage, damage})
        :ok
      end)

      assert :ok =
               Combat.execute_magic_damage(caster, @target_id, 50,
                 skill_id: @skill_id,
                 skill_level: @skill_level
               )

      assert_received {:damage, 50}
    end

    test "final 1-point direct magic participates in coma" do
      caster = build_caster()
      stub_mob_target(150, 150, {:poison, 1})

      expect(EquipComa, :trigger?, fn _attacker, _target -> true end)

      expect(StatusInterpreter, :absorb_damage, fn :mob, @target_id, 1, hit_info ->
        assert hit_info.coma?
        1
      end)

      stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, %SkillDamage{} = packet ->
        assert packet.damage == 1
        :ok
      end)

      reject(&MobSession.apply_damage/3)
      expect(MobSession, :apply_coma, fn _pid, {:player, @caster_id} -> :ok end)

      assert :ok =
               Combat.execute_magic_damage(caster, @target_id, 100,
                 skill_id: @skill_id,
                 skill_level: @skill_level,
                 element: :poison
               )
    end

    test "full absorption consumes direct coma decision without owner mutation" do
      caster = build_caster()
      stub_mob_target(150, 150, {:neutral, 1})

      expect(EquipComa, :trigger?, fn _attacker, _target -> true end)

      expect(StatusInterpreter, :absorb_damage, fn :mob, @target_id, 100, hit_info ->
        assert hit_info.coma?
        0
      end)

      stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, %SkillDamage{} = packet ->
        assert packet.damage == 0
        :ok
      end)

      reject(&MobSession.apply_damage/3)
      reject(&MobSession.apply_coma/2)

      assert :ok =
               Combat.execute_magic_damage(caster, @target_id, 100,
                 skill_id: @skill_id,
                 skill_level: @skill_level,
                 element: :neutral
               )
    end

    test "returns {:error, :target_out_of_range} for a target beyond caster attack range" do
      caster = build_caster()
      stub_mob_target(170, 170, {:neutral, 1})

      reject(&EquipComa.trigger?/2)
      reject(&MobSession.apply_coma/2)

      assert {:error, :target_out_of_range} =
               Combat.execute_magic_damage(caster, @target_id, 100,
                 skill_id: @skill_id,
                 skill_level: @skill_level,
                 element: :holy
               )
    end

    test "rejects magic damage against another player until PvP exists" do
      caster = build_caster()
      target_player = spawn(fn -> Process.sleep(:infinity) end)

      on_exit(fn -> Process.exit(target_player, :kill) end)

      target_state = %{build_caster() | character_id: @target_id, x: 150, y: 150}

      stub(UnitRegistry, :get_unit, fn
        :mob, @target_id -> {:error, :not_found}
        :player, @target_id -> {:ok, {PlayerState, target_state, target_player}}
      end)

      stub(UnitRegistry, :get_player_pid, fn @target_id -> {:ok, target_player} end)

      reject(&Broadcast.to_in_range/5)
      reject(&PlayerSession.apply_damage/3)

      assert {:error, :invalid_target} =
               Combat.execute_magic_damage(caster, @target_id, 100,
                 skill_id: @skill_id,
                 skill_level: @skill_level,
                 element: :holy
               )
    end

    test "allows a mob caster to damage a player target (mob skills are not PvP)" do
      mob_caster = build_mob_state(@caster_id, 150, 150, {:neutral, 1})
      target_player = spawn(fn -> Process.sleep(:infinity) end)
      test_pid = self()

      target_state = %{build_caster() | character_id: @target_id, x: 150, y: 150}

      stub(UnitRegistry, :get_unit, fn
        :mob, @target_id -> {:error, :not_found}
        :player, @target_id -> {:ok, {PlayerState, target_state, target_player}}
      end)

      stub(UnitRegistry, :get_player_pid, fn @target_id -> {:ok, target_player} end)

      stub(Broadcast, :to_in_range, fn _m, _x, _y, _r, _p -> :ok end)

      stub(StatusInterpreter, :absorb_damage, fn :player, @target_id, damage, _hit_info ->
        damage
      end)

      stub(PlayerSession, :apply_damage, fn ^target_player, damage, {:mob, @caster_id} ->
        send(test_pid, {:damage, damage})
        :ok
      end)

      assert :ok =
               Combat.execute_magic_damage(mob_caster, @target_id, 100,
                 skill_id: @skill_id,
                 skill_level: @skill_level,
                 element: :fire
               )

      assert_received {:damage, 100}
    end
  end

  # The `hit_info` handed to `absorb_damage/4`. `from_caster?` mirrors rAthena's
  # `src == dsrc` — the damage came from the caster, not from a placed skill
  # unit — and is what keeps Magic Rod from swallowing ground ticks while still
  # catching a direct cast's splash. Asserted at the boundary rather than trusted.
  describe "absorb_damage hit_info contract" do
    defp stub_player_target(target_player, test_pid) do
      target_state = %{build_caster() | character_id: @target_id, x: 150, y: 150}

      stub(UnitRegistry, :get_unit, fn
        :mob, @target_id -> {:error, :not_found}
        :player, @target_id -> {:ok, {PlayerState, target_state, target_player}}
      end)

      stub(UnitRegistry, :get_player_pid, fn @target_id -> {:ok, target_player} end)

      stub(Broadcast, :to_in_range, fn _m, _x, _y, _r, _p -> :ok end)
      stub(PlayerSession, :apply_damage, fn ^target_player, _damage, _attacker -> :ok end)

      stub(StatusInterpreter, :absorb_damage, fn :player, @target_id, damage, hit_info ->
        send(test_pid, {:hit_info, hit_info})
        damage
      end)
    end

    test "a direct single-target cast carries skill_id, level and from_caster?: true" do
      target_player = spawn(fn -> Process.sleep(:infinity) end)
      on_exit(fn -> Process.exit(target_player, :kill) end)
      stub_player_target(target_player, self())

      assert :ok =
               Combat.execute_magic_damage(
                 build_mob_state(@caster_id, 150, 150, {:neutral, 1}),
                 @target_id,
                 100,
                 skill_id: @skill_id,
                 skill_level: @skill_level,
                 element: :fire
               )

      assert_received {:hit_info, hit_info}

      assert %{
               dmg_type: :magic,
               from_caster?: true,
               skill_id: @skill_id,
               skill_level: @skill_level,
               element: :fire
             } = hit_info
    end

    # rAthena absorbs a direct cast's splash too: only `dsrc` being a placed unit
    # breaks the equality. Fireball splash therefore reaches Magic Rod.
    test "a direct cast's splash is still flagged from_caster?: true (Fireball)" do
      target_player = spawn(fn -> Process.sleep(:infinity) end)
      on_exit(fn -> Process.exit(target_player, :kill) end)
      stub_player_target(target_player, self())

      stub(SpatialIndex, :get_all_units_in_range, fn @map_name, 150, 150, 4 ->
        [{:player, @target_id}]
      end)

      stub(MagicDamageCalculator, :calculate_magic_damage, fn _attacker, _target, _opts ->
        {:ok, %{damage: 100, is_critical: false}}
      end)

      assert [{:player, @target_id}] =
               Combat.execute_magic_splash(
                 build_mob_state(@caster_id, 150, 150, {:neutral, 1}),
                 {150, 150},
                 2,
                 skill_id: 17,
                 skill_level: 10,
                 element: :fire
               )

      assert_received {:hit_info, hit_info}
      assert %{dmg_type: :magic, from_caster?: true, skill_id: 17, skill_level: 10} = hit_info
    end

    test "ground skill-unit and status damage is never flagged from_caster?" do
      target_player = spawn(fn -> Process.sleep(:infinity) end)
      on_exit(fn -> Process.exit(target_player, :kill) end)
      stub_player_target(target_player, self())

      assert :ok = Combat.deal_damage(@target_id, 100, :water, :skill_unit)

      assert_received {:hit_info, hit_info}
      assert %{dmg_type: :magic, from_caster?: false, skill_id: nil} = hit_info
    end
  end
end
