defmodule Aesir.ZoneServer.Mmo.Combat.DamageApplicationTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.Combat.DamageApplication
  alias Aesir.ZoneServer.Mmo.Combat.HandedAttack
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager, as: SkillUnitManager
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
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

    expect(PlayerSession, :apply_damage, fn ^target_pid, 75, 20 ->
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

    expect(PlayerSession, :apply_damage, fn ^target_pid, 0, 20 -> :ok end)

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

    expect(PlayerSession, :apply_damage, fn ^target_pid, 150, 20 -> :ok end)

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

    expect(PlayerSession, :apply_damage, fn ^target_pid, 50, 20 -> :ok end)

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

    expect(PlayerSession, :apply_damage, fn ^target_pid, 2, 20 -> :ok end)

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
