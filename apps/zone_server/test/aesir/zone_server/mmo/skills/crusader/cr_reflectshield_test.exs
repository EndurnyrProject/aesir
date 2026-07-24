defmodule Aesir.ZoneServer.Mmo.Skills.Crusader.CrReflectshieldTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.Combat.DamageApplication
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Crusader.CrReflectshield
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_from_context
  setup :verify_on_exit!

  @victim_id 4100
  @attacker_id 4200
  @shield_id 2101
  @sword_id 1101

  defp caster(equipment \\ %Equipment{}),
    do: %PlayerState{character_id: @victim_id, stats: %{equipment: equipment}}

  defp mob_caster do
    mob_data = %MobDefinition{
      id: 1004,
      aegis_name: "test_crusader",
      name: "Test Crusader",
      level: 50,
      hp: 1000,
      stats: %{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
      matk: 0,
      attack_range: 1,
      size: :medium,
      race: :formless,
      element: {:neutral, 1},
      walk_speed: 200,
      attack_delay: 1000,
      attack_motion: 500,
      client_attack_motion: 400,
      damage_motion: 300
    }

    spawn_ref = %MobSpawn{
      mob: 1004,
      amount: 1,
      respawn_time: 5000,
      spawn_area: %SpawnArea{x: 100, y: 100}
    }

    MobState.new(9003, mob_data, spawn_ref, "prontera", 100, 100)
  end

  defp stub_unit_info(char_id, unit_type \\ :player), do: stub_unit_infos([{unit_type, char_id}])

  defp stub_unit_infos(ids) do
    stub(UnitRegistry, :get_unit_info, fn unit_type, char_id ->
      if {unit_type, char_id} in ids do
        {:ok,
         %{
           unit_id: char_id,
           unit_type: unit_type,
           race: :formless,
           element: :neutral,
           element_level: 1,
           boss_flag: false,
           size: :medium,
           stats: %{
             max_hp: 100,
             max_sp: 50,
             hp: 100,
             sp: 50,
             level: 1,
             base_level: 1,
             str: 1,
             agi: 1,
             vit: 1,
             int: 1,
             dex: 1,
             luk: 1,
             mdef: 0
           }
         }}
      else
        {:error, :not_found}
      end
    end)
  end

  describe "catalog registration" do
    test "by_id(252) resolves cr_reflectshield" do
      assert {:ok, definition} = Catalog.by_id(252)
      assert definition.name == :cr_reflectshield
      assert definition.display_name == "Reflect Shield"
      assert definition.max_level == 10
      assert definition.target_type == :self
    end

    test "by_name/1 resolves the atom" do
      assert {:ok, %{id: 252}} = Catalog.by_name(:cr_reflectshield)
    end

    test "active_module_for/1 resolves the module" do
      assert {:ok, CrReflectshield} = Catalog.active_module_for(:cr_reflectshield)
    end

    test "sp_cost matches the per-level table" do
      {:ok, definition} = Catalog.by_name(:cr_reflectshield)
      assert definition.sp_cost == [35, 40, 45, 50, 55, 60, 65, 70, 75, 80]
    end
  end

  describe "validate/4 (player shield gate)" do
    test "rejects a cast without a shield equipped" do
      assert {:error, :requires_shield} = CrReflectshield.validate(caster(), :self, 1, %{})
    end

    test "rejects a cast with only a weapon equipped" do
      assert {:error, :requires_shield} =
               CrReflectshield.validate(
                 caster(%Equipment{right_hand: @sword_id}),
                 :self,
                 1,
                 %{}
               )
    end

    test "allows a cast with a shield equipped" do
      assert :ok =
               CrReflectshield.validate(
                 caster(%Equipment{left_hand: @shield_id}),
                 :self,
                 1,
                 %{}
               )
    end
  end

  describe "validate/4 (mob caster exemption)" do
    test "always allows a mob caster regardless of shield" do
      assert :ok = CrReflectshield.validate(mob_caster(), :self, 1, %{})
    end
  end

  describe "cast/4 (toggle)" do
    setup :setup_ets_tables

    test "first cast applies sc_reflectshield carrying the level in val1" do
      stub_unit_info(@victim_id)
      caster = caster(%Equipment{left_hand: @shield_id})

      assert {:ok, ^caster} = CrReflectshield.cast(caster, :self, 3, %{})
      assert StatusStorage.has_status?(:player, @victim_id, :sc_reflectshield)
      assert %{val1: 3} = StatusStorage.get_status(:player, @victim_id, :sc_reflectshield)
    end

    test "re-casting toggles the status back off" do
      stub_unit_info(@victim_id)
      caster = caster(%Equipment{left_hand: @shield_id})

      assert {:ok, ^caster} = CrReflectshield.cast(caster, :self, 3, %{})
      assert StatusStorage.has_status?(:player, @victim_id, :sc_reflectshield)

      assert {:ok, ^caster} = CrReflectshield.cast(caster, :self, 3, %{})
      refute StatusStorage.has_status?(:player, @victim_id, :sc_reflectshield)
    end

    test "a mistargeted {:unit, id} row still toggles the caster, not the given id" do
      stub_unit_info(@victim_id)
      caster = caster(%Equipment{left_hand: @shield_id})

      assert {:ok, ^caster} = CrReflectshield.cast(caster, {:unit, 999_999}, 3, %{})
      assert StatusStorage.has_status?(:player, @victim_id, :sc_reflectshield)
    end

    test "a mob caster toggles through :mob, not :player" do
      mob = mob_caster()
      stub_unit_info(9003, :mob)

      assert {:ok, ^mob} = CrReflectshield.cast(mob, :self, 5, %{})
      assert StatusStorage.has_status?(:mob, 9003, :sc_reflectshield)
    end
  end

  describe "sc_reflectshield reflect hook (through DamageApplication)" do
    setup :setup_ets_tables

    defp spawn_session(label) do
      test_pid = self()
      spawn_link(fn -> session_loop(test_pid, label) end)
    end

    defp session_loop(test_pid, label) do
      receive do
        {:"$gen_cast", {:unit, {:apply_damage, damage, attacker_id}}} ->
          send(test_pid, {label, damage, attacker_id})
          session_loop(test_pid, label)

        _other ->
          session_loop(test_pid, label)
      end
    end

    defp arm_reflect(level) do
      stub_unit_info(@victim_id)
      :ok = StatusInterpreter.apply_status(:player, @victim_id, :sc_reflectshield, val1: level)
    end

    defp melee_hit, do: %{dmg_type: :physical, is_short: true, element: :neutral}

    test "lv1 reflects 13% of the delivered damage back to the attacker" do
      victim = spawn_session(:victim)
      attacker = spawn_session(:attacker)
      arm_reflect(1)
      stub(TargetResolver, :resolve, fn @attacker_id -> {:ok, attacker, %{}, :player} end)

      DamageApplication.apply_unit_damage(
        :player,
        victim,
        @victim_id,
        100,
        melee_hit(),
        @attacker_id
      )

      assert_receive {:victim, 100, @attacker_id}
      assert_receive {:attacker, 13, nil}
    end

    test "lv10 reflects 40% of the delivered damage back to the attacker" do
      victim = spawn_session(:victim)
      attacker = spawn_session(:attacker)
      arm_reflect(10)
      stub(TargetResolver, :resolve, fn @attacker_id -> {:ok, attacker, %{}, :player} end)

      DamageApplication.apply_unit_damage(
        :player,
        victim,
        @victim_id,
        100,
        melee_hit(),
        @attacker_id
      )

      assert_receive {:victim, 100, @attacker_id}
      assert_receive {:attacker, 40, nil}
    end

    test "a ranged weapon hit reflects nothing" do
      victim = spawn_session(:victim)
      attacker = spawn_session(:attacker)
      arm_reflect(5)
      stub(TargetResolver, :resolve, fn @attacker_id -> {:ok, attacker, %{}, :player} end)

      DamageApplication.apply_unit_damage(
        :player,
        victim,
        @victim_id,
        100,
        %{dmg_type: :physical, is_short: false, element: :neutral},
        @attacker_id
      )

      assert_receive {:victim, 100, @attacker_id}
      refute_receive {:attacker, _, _}
    end

    test "a magic hit reflects nothing" do
      victim = spawn_session(:victim)
      attacker = spawn_session(:attacker)
      arm_reflect(5)
      stub(TargetResolver, :resolve, fn @attacker_id -> {:ok, attacker, %{}, :player} end)

      DamageApplication.apply_unit_damage(
        :player,
        victim,
        @victim_id,
        100,
        %{dmg_type: :magic, is_short: true, element: :neutral},
        @attacker_id
      )

      assert_receive {:victim, 100, @attacker_id}
      refute_receive {:attacker, _, _}
    end

    test "reflected damage is not itself reflected when both sides carry the status" do
      victim = spawn_session(:victim)
      attacker = spawn_session(:attacker)
      stub_unit_infos([{:player, @victim_id}, {:player, @attacker_id}])
      :ok = StatusInterpreter.apply_status(:player, @victim_id, :sc_reflectshield, val1: 5)
      :ok = StatusInterpreter.apply_status(:player, @attacker_id, :sc_reflectshield, val1: 5)

      stub(TargetResolver, :resolve, fn
        @attacker_id -> {:ok, attacker, %{}, :player}
        @victim_id -> {:ok, victim, %{}, :player}
      end)

      DamageApplication.apply_unit_damage(
        :player,
        victim,
        @victim_id,
        100,
        melee_hit(),
        @attacker_id
      )

      assert_receive {:victim, 100, @attacker_id}
      assert_receive {:attacker, 25, nil}
      refute_receive {:victim, _, _}
    end
  end
end
