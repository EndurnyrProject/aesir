defmodule Aesir.ZoneServer.Mmo.Combat.DamageApplicationTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.Combat.DamageApplication
  alias Aesir.ZoneServer.Mmo.Combat.HandedAttack
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager, as: SkillUnitManager
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.PlayerStateFixture
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.Stats.CombatStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  defmodule HalfDamage do
    use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
      id: :sc_test_weapon_swing_half,
      no_dispel: false,
      properties: [:buff]

    @impl true
    def absorb_damage(_target, instance, hit_info, _context) do
      send(instance.state.test_pid, {:absorbed, hit_info})
      {:ok, div(hit_info.damage, 2), instance}
    end
  end

  defmodule FullAbsorb do
    use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
      id: :sc_test_weapon_swing_full,
      no_dispel: false,
      properties: [:buff]

    @impl true
    def absorb_damage(_target, instance, _hit_info, _context) do
      send(instance.state.test_pid, :fully_absorbed)
      {:ok, 0, instance}
    end
  end

  defmodule AfterDamage do
    use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
      id: :sc_test_weapon_swing_after_damage,
      no_dispel: false,
      properties: [:buff]

    @impl true
    def after_damage_taken(_target, instance, hit_info, _context) do
      send(instance.state.test_pid, {:after_damage_taken, hit_info})
      :ok
    end
  end

  setup :set_mimic_from_context
  setup :verify_on_exit!
  setup :setup_ets_tables

  test "reduces skill magic damage using the player target's equipment" do
    target_id = 29
    register_player_with_magic_reduction(target_id, 40)

    assert {60, %{pre_delivery_prepared?: true}} =
             DamageApplication.prepare_unit_damage(
               :player,
               target_id,
               100,
               %{dmg_type: :magic, skill_id: 19},
               20
             )
  end

  test "does not reduce magic damage without a skill id" do
    target_id = 30
    register_player_with_magic_reduction(target_id, 40)

    assert {100, %{pre_delivery_prepared?: true}} =
             DamageApplication.prepare_unit_damage(
               :player,
               target_id,
               100,
               %{dmg_type: :magic, skill_id: nil},
               20
             )
  end

  test "does not reduce physical skill damage" do
    target_id = 31
    register_player_with_magic_reduction(target_id, 40)

    assert {100, %{pre_delivery_prepared?: true}} =
             DamageApplication.prepare_unit_damage(
               :player,
               target_id,
               100,
               %{dmg_type: :physical, skill_id: 19},
               20
             )
  end

  test "settles aggregate absorption proportionally and delivers once" do
    target_id = 10
    target_pid = spawn(fn -> Process.sleep(:infinity) end)
    test_pid = self()
    stub_unit_info(target_id)
    Registry.register_module(HalfDamage)

    :ok =
      Interpreter.apply_status(:player, target_id, :sc_test_weapon_swing_half,
        state: %{test_pid: self()}
      )

    expect(PlayerSession, :apply_damage, fn ^target_pid, 75, {:player, 20} ->
      send(test_pid, :delivered)
      :ok
    end)

    {settled, delivery} =
      DamageApplication.apply_weapon_swing(
        :player,
        target_pid,
        target_id,
        swing(100, 50),
        melee_hit(),
        20
      )

    assert delivery == :ok
    assert settled.primary.damage == 50
    assert settled.secondary.damage == 25
    assert settled.primary.damage + settled.secondary.damage == 75
    assert_received :delivered

    assert_received {:absorbed,
                     %{
                       damage: 150,
                       components: [
                         {:primary, 100, :neutral},
                         {:secondary, 50, :neutral}
                       ]
                     }}
  end

  test "full absorption zeroes both components and makes one zero-damage delivery" do
    target_id = 12
    target_pid = spawn(fn -> Process.sleep(:infinity) end)
    stub_unit_info(target_id)
    Registry.register_module(FullAbsorb)

    :ok =
      Interpreter.apply_status(:player, target_id, :sc_test_weapon_swing_full,
        state: %{test_pid: self()}
      )

    expect(PlayerSession, :apply_damage, fn ^target_pid, 0, {:player, 20} -> :ok end)

    {settled, :ok} =
      DamageApplication.apply_weapon_swing(
        :player,
        target_pid,
        target_id,
        swing(100, 50),
        melee_hit(),
        20
      )

    assert settled.raw_total == 150
    assert settled.primary.damage == 0
    assert settled.secondary.damage == 0
    assert_received :fully_absorbed
    refute_received :fully_absorbed
  end

  test "delivers and dispatches victim post-damage once for the aggregate" do
    target_id = 14
    target_pid = spawn(fn -> Process.sleep(:infinity) end)
    stub_unit_info(target_id)
    Registry.register_module(AfterDamage)

    :ok =
      Interpreter.apply_status(:player, target_id, :sc_test_weapon_swing_after_damage,
        state: %{test_pid: self()}
      )

    expect(PlayerSession, :apply_damage, fn ^target_pid, 150, {:player, 20} -> :ok end)

    {_settled, :ok} =
      DamageApplication.apply_weapon_swing(
        :player,
        target_pid,
        target_id,
        swing(100, 50),
        melee_hit(),
        20
      )

    assert_received {:after_damage_taken, %{damage: 150}}
    refute_received {:after_damage_taken, _hit_info}
  end

  test "dispatches post-damage for positive ranged magic with a typed mob attacker" do
    # The mob instance id equals the victim character id: the delivery must
    # carry the exact {:mob, 20} ref, proving no char/mob id-space collision.
    target_id = 20
    target_pid = spawn(fn -> Process.sleep(:infinity) end)
    stub_unit_info(target_id)
    Registry.register_module(AfterDamage)

    :ok =
      Interpreter.apply_status(:player, target_id, :sc_test_weapon_swing_after_damage,
        state: %{test_pid: self()}
      )

    expect(PlayerSession, :apply_damage, fn ^target_pid, 40, {:mob, 20} -> :ok end)

    assert :ok =
             DamageApplication.apply_unit_damage(
               :player,
               target_pid,
               target_id,
               40,
               %{dmg_type: :magic, is_short: false, element: :fire},
               {:mob, 20}
             )

    assert_received {:after_damage_taken,
                     %{
                       damage: 40,
                       attacker: {:mob, 20},
                       dmg_type: :magic,
                       is_short: false
                     }}
  end

  test "delivers the skill id and level to a player victim" do
    target_id = 19
    target_pid = spawn(fn -> Process.sleep(:infinity) end)
    stub_unit_info(target_id)

    expect(PlayerSession, :apply_damage, fn ^target_pid, 40, {:player, 20} -> :ok end)
    expect(PlayerSession, :record_skill_hit, fn ^target_pid, 21, 5 -> :ok end)

    assert :ok =
             DamageApplication.apply_unit_damage(
               :player,
               target_pid,
               target_id,
               40,
               %{skill_id: 21, skill_level: 5},
               20
             )
  end

  test "positive coma delivery preserves skill identity and post-damage hooks once" do
    target_id = 23
    target_pid = spawn(fn -> Process.sleep(:infinity) end)
    stub_unit_info(target_id)
    Registry.register_module(AfterDamage)

    :ok =
      Interpreter.apply_status(:player, target_id, :sc_test_weapon_swing_after_damage,
        state: %{test_pid: self()}
      )

    reject(&PlayerSession.apply_damage/3)
    expect(PlayerSession, :apply_coma, fn ^target_pid, {:player, 20} -> :ok end)
    expect(PlayerSession, :record_skill_hit, fn ^target_pid, 21, 5 -> :ok end)

    assert :ok =
             DamageApplication.apply_unit_damage(
               :player,
               target_pid,
               target_id,
               40,
               %{coma?: true, skill_id: 21, skill_level: 5},
               20
             )

    assert_received {:after_damage_taken, %{damage: 40, attacker: {:player, 20}}}
    refute_received {:after_damage_taken, _hit_info}
  end

  test "positive mob coma delivery preserves typed source without stale kill classification" do
    target_pid = spawn(fn -> Process.sleep(:infinity) end)

    reject(&MobSession.note_hit_type/3)
    reject(&MobSession.apply_damage/3)
    expect(MobSession, :apply_coma, fn ^target_pid, {:mob, 20} -> :ok end)

    assert :ok =
             DamageApplication.apply_unit_damage(
               :mob,
               target_pid,
               24,
               40,
               %{coma?: true, dmg_type: :physical, is_short: true},
               {:mob, 20}
             )
  end

  test "same-owner Homunculus coma is returned as a local effect" do
    assert {:local_effects, [effect]} =
             DamageApplication.apply_unit_damage(
               :homunculus,
               self(),
               25,
               40,
               %{coma?: true},
               {:mob, 20}
             )

    assert effect == {:homunculus, {:apply_coma, 25, {:mob, 20}}}
  end

  test "zero prepared coma damage performs no owner delivery or post-damage hook" do
    target_id = 26
    target_pid = spawn(fn -> Process.sleep(:infinity) end)
    stub_unit_info(target_id)
    Registry.register_module(AfterDamage)

    :ok =
      Interpreter.apply_status(:player, target_id, :sc_test_weapon_swing_after_damage,
        state: %{test_pid: self()}
      )

    reject(&PlayerSession.apply_coma/2)
    reject(&PlayerSession.apply_damage/3)
    reject(&PlayerSession.record_skill_hit/3)

    assert :ok =
             DamageApplication.apply_unit_damage(
               :player,
               target_pid,
               target_id,
               0,
               %{coma?: true, pre_delivery_prepared?: true, skill_id: 21, skill_level: 5},
               20
             )

    refute_received {:after_damage_taken, _hit_info}
  end

  test "Devotion redirection carries coma to the actual owner" do
    devotee_id = 27
    crusader_id = 28
    devotee_pid = spawn(fn -> Process.sleep(:infinity) end)
    crusader_pid = spawn(fn -> Process.sleep(:infinity) end)

    crusader = %PlayerState{
      character_id: crusader_id,
      action_state: :idle,
      stats: %{current_state: %{hp: 100}}
    }

    UnitRegistry.register_unit(:player, crusader_id, PlayerState, crusader, crusader_pid)
    SpatialIndex.add_player(devotee_id, 50, 50, "prontera")
    SpatialIndex.add_player(crusader_id, 51, 50, "prontera")

    :ok =
      StatusStorage.apply_status(:player, devotee_id, :sc_devotion,
        state: %{peer: {:player, crusader_id}, link_id: make_ref(), range: 7}
      )

    reject(&PlayerSession.apply_damage/3)
    expect(PlayerSession, :apply_coma, fn ^crusader_pid, {:player, 20} -> :ok end)

    assert {0, prepared} =
             DamageApplication.prepare_unit_damage(
               :player,
               devotee_id,
               40,
               %{coma?: true},
               20
             )

    assert :ok =
             DamageApplication.apply_unit_damage(
               :player,
               devotee_pid,
               devotee_id,
               0,
               prepared,
               20
             )
  end

  test "fully absorbed zero damage does not dispatch post-damage" do
    target_id = 19
    target_pid = spawn(fn -> Process.sleep(:infinity) end)
    stub_unit_info(target_id)
    Registry.register_module(FullAbsorb)
    Registry.register_module(AfterDamage)

    :ok =
      Interpreter.apply_status(:player, target_id, :sc_test_weapon_swing_full,
        state: %{test_pid: self()}
      )

    :ok =
      Interpreter.apply_status(:player, target_id, :sc_test_weapon_swing_after_damage,
        state: %{test_pid: self()}
      )

    expect(PlayerSession, :apply_damage, fn ^target_pid, 0, {:mob, 20} -> :ok end)

    {_settled, :ok} =
      DamageApplication.apply_weapon_swing(
        :player,
        target_pid,
        target_id,
        swing(100, 50),
        melee_hit(),
        {:mob, 20}
      )

    refute_received {:after_damage_taken, _hit_info}
  end

  test "one aggregate delivery produces one HP and death transition" do
    target_id = 15
    test_pid = self()
    target_pid = spawn_link(fn -> death_session_loop(test_pid, struct(MobState, %{hp: 100})) end)

    {_settled, :ok} =
      DamageApplication.apply_weapon_swing(
        :mob,
        target_pid,
        target_id,
        swing(80, 40),
        melee_hit(),
        20
      )

    assert_receive {:transition, 0, :dead}
    refute_receive {:transition, _, _}
  end

  test "preserves the one-hit delivery error contract" do
    manager_pid = spawn(fn -> Process.sleep(:infinity) end)
    Mimic.copy(SkillUnitManager)

    expect(SkillUnitManager, :damage_targetable_cell, fn ^manager_pid, 16, 150, {:player, 20} ->
      {:error, :not_targetable}
    end)

    {settled, delivery} =
      DamageApplication.apply_weapon_swing(
        :skill_unit,
        manager_pid,
        16,
        swing(100, 50),
        melee_hit(),
        20
      )

    assert settled.raw_total == 150
    assert delivery == {:error, :not_targetable}
  end

  test "a zero-damage miss performs no absorption or delivery" do
    target_id = 13
    target_pid = spawn(fn -> Process.sleep(:infinity) end)
    stub_unit_info(target_id)
    Registry.register_module(FullAbsorb)

    :ok =
      Interpreter.apply_status(:player, target_id, :sc_test_weapon_swing_full,
        state: %{test_pid: self()}
      )

    reject(&PlayerSession.apply_damage/3)
    miss = %{swing(0, nil) | outcome: :miss}

    assert {^miss, :ok} =
             DamageApplication.apply_weapon_swing(
               :player,
               target_pid,
               target_id,
               miss,
               melee_hit(),
               20
             )

    refute_received :fully_absorbed
  end

  test "settles a primary-only swing without secondary division" do
    target_id = 17
    target_pid = spawn(fn -> Process.sleep(:infinity) end)
    stub_unit_info(target_id)
    Registry.register_module(HalfDamage)

    :ok =
      Interpreter.apply_status(:player, target_id, :sc_test_weapon_swing_half,
        state: %{test_pid: self()}
      )

    expect(PlayerSession, :apply_damage, fn ^target_pid, 50, {:player, 20} -> :ok end)

    {settled, :ok} =
      DamageApplication.apply_weapon_swing(
        :player,
        target_pid,
        target_id,
        swing(100, nil),
        melee_hit(),
        20
      )

    assert settled.primary.damage == 50
    assert settled.secondary == nil
    assert_received {:absorbed, %{components: [{:primary, 100, :neutral}]}}
  end

  test "assigns the proportional division remainder to primary" do
    target_id = 11
    target_pid = spawn(fn -> Process.sleep(:infinity) end)
    stub_unit_info(target_id)
    Registry.register_module(HalfDamage)

    :ok =
      Interpreter.apply_status(:player, target_id, :sc_test_weapon_swing_half,
        state: %{test_pid: self()}
      )

    expect(PlayerSession, :apply_damage, fn ^target_pid, 2, {:player, 20} -> :ok end)

    {settled, :ok} =
      DamageApplication.apply_weapon_swing(
        :player,
        target_pid,
        target_id,
        swing(3, 2),
        melee_hit(),
        20
      )

    assert settled.primary.damage == 2
    assert settled.secondary.damage == 0
    assert settled.raw_total == 5
  end

  test "broadcasts SP restoration to the player's topic" do
    :ok = Phoenix.PubSub.subscribe(Aesir.PubSub, "player:42")

    assert :ok = DamageApplication.apply_sp_heal(:player, 42, 7)
    assert_receive {:combat, {:restore_sp, 7}}
  end

  defp death_session_loop(test_pid, mob) do
    receive do
      {:"$gen_cast", {:combat, {:apply_damage, damage, _attacker_id}}} ->
        {mob, transition} = MobState.apply_damage(mob, damage)
        send(test_pid, {:transition, mob.hp, transition})
        death_session_loop(test_pid, mob)
    end
  end

  defp swing(primary, secondary) do
    secondary_result =
      if is_nil(secondary), do: nil, else: %{damage: secondary, is_critical: false}

    %HandedAttack{
      primary: %{damage: primary, is_critical: false},
      secondary: secondary_result,
      raw_total: primary + (secondary || 0),
      display_divisions: 1,
      outcome: :hit,
      primary_element: :neutral
    }
  end

  defp melee_hit do
    %{
      dmg_type: :physical,
      is_short: true,
      element: :neutral,
      skill_id: nil,
      skill_level: nil,
      from_caster?: true
    }
  end

  defp register_player_with_magic_reduction(target_id, percent) do
    player =
      PlayerStateFixture.build(%{
        character_id: target_id,
        account_id: target_id,
        stats: %{
          combat_stats: %CombatStats{},
          modifiers: %{equipment: %{no_magic_damage: percent}}
        }
      })

    UnitRegistry.register_player(player, self())
  end

  defp stub_unit_info(target_id) do
    stub(UnitRegistry, :get_unit_info, fn :player, ^target_id ->
      {:ok,
       %{
         unit_id: target_id,
         unit_type: :player,
         race: :human,
         element: :neutral,
         element_level: 1,
         boss_flag: false,
         size: :medium,
         stats: %{
           max_hp: 1_000,
           max_sp: 100,
           hp: 1_000,
           sp: 100,
           level: 50,
           base_level: 50,
           str: 10,
           agi: 10,
           vit: 10,
           int: 10,
           dex: 10,
           luk: 10,
           mdef: 5
         }
       }}
    end)
  end
end
