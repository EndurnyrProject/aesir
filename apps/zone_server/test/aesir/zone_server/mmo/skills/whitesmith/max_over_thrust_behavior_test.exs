defmodule Aesir.ZoneServer.Mmo.Skills.Whitesmith.MaxOverThrustBehaviorTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.GameMode
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.TestMob
  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.EquipBreak
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.Skill.Caster.Player
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Whitesmith.WsOverthrustmax
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Resistance
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.PlayerStateFixture
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.Handlers.EquipmentHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.Stats.Calculator
  alias Aesir.ZoneServer.Unit.Player.StatusSync
  alias Aesir.ZoneServer.Unit.Stats.CombatStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_private
  setup :setup_ets_tables

  setup do
    stub(Resistance, :roll_success, fn _ -> true end)
    stub(Resistance, :roll_rate, fn _ -> true end)

    player =
      PlayerStateFixture.build(%{
        character_id: 101,
        account_id: 101,
        zeny: 10_000,
        inventory: %{},
        stats: %{
          combat_stats: %CombatStats{},
          progression: %{learned_skills: %{1_012 => 1, 105 => 1}}
        }
      })

    :ok = UnitRegistry.register_player(player, self())
    %{caster: player}
  end

  test "stronger_over_thrust_wins_in_both_application_orders" do
    for first <- [:sc_overthrust, :sc_maxoverthrust] do
      assert :ok = apply_status(first)

      if first == :sc_overthrust do
        assert :ok = apply_status(:sc_maxoverthrust)
      else
        assert {:error, _} = apply_status(:sc_overthrust)
      end

      assert StatusStorage.has_status?(:player, 101, :sc_maxoverthrust)
      refute StatusStorage.has_status?(:player, 101, :sc_overthrust)
      Interpreter.remove_status(:player, 101, :sc_maxoverthrust)
    end
  end

  test "maximum_over_thrust_adds_to_weapon_ratio" do
    mob = mob()
    :ok = UnitRegistry.register_unit(:mob, 201, MobState, mob, self())
    attacker = CombatTestHelper.create_mob_combatant(unit_id: 201)
    defender = CombatTestHelper.create_mob_combatant(unit_id: 202, def: 0, soft_def: 0)
    {:ok, definition} = Catalog.by_id(486)
    assert :ok = WsOverthrustmax.mob_cast(mob, {:unit, :mob, 201}, 5, definition, %{})

    assert %{val1: 5, val2: 100, source_type: :mob} =
             StatusStorage.get_status(:mob, 201, :sc_maxoverthrust)

    assert {:ok, boosted} =
             DamageCalculator.calculate_damage(attacker, defender,
               base_damage: 100,
               skill_ratio: 200,
               skip_crit: true
             )

    assert boosted.damage == if(GameMode.mode() == :renewal, do: 300, else: 299)

    assert {:ok, sacrifice} =
             DamageCalculator.calculate_damage(attacker, defender,
               skill_id: 368,
               base_damage: 100,
               skill_ratio: 200,
               skip_crit: true
             )

    Interpreter.remove_status(:mob, 201, :sc_maxoverthrust)

    assert {:ok, unbuffed} =
             DamageCalculator.calculate_damage(attacker, defender,
               skill_id: 368,
               base_damage: 100,
               skill_ratio: 200,
               skip_crit: true
             )

    assert sacrifice.damage == unbuffed.damage
  end

  test "paid_buff_uses_full_zeny_and_unextended_duration", %{caster: caster} do
    {:ok, definition} = Catalog.by_id(486)

    for {price, level} <- Enum.with_index([3_000, 3_500, 4_000, 4_500, 5_000], 1) do
      assert {:ok, prepared} = Player.cost(caster, WsOverthrustmax, :self, definition, level)
      {paid, _} = Player.commit_primary(caster, prepared)
      assert paid.zeny == 10_000 - price
      assert paid.stats.current_state.sp == 85
      before_ms = System.monotonic_time(:millisecond)
      assert {:ok, ^paid} = WsOverthrustmax.cast(paid, :self, level, definition)
      after_ms = System.monotonic_time(:millisecond)
      held = StatusStorage.get_status(:player, 101, :sc_maxoverthrust)
      assert held.expires_at >= before_ms + 180_000
      assert held.expires_at <= after_ms + 180_000
    end
  end

  test "weapon_unequip_ends_stronger_buff_only_in_renewal", %{caster: caster} do
    caster = %{
      caster
      | inventory: %{0 => %InventoryItem{nameid: 1_101, amount: 1, equip: 2, identify: 1}}
    }

    :ok = UnitRegistry.register_player(caster, self())
    assert :ok = apply_status(:sc_maxoverthrust)
    stub(InventoryOps, :apply_change, fn 101, _old, new, _change -> {:ok, new} end)
    stub(Calculator, :calculate_stats, fn stats, 101, _equipped -> stats end)
    stub(StatusSync, :send_stat_updates, fn _, _ -> :ok end)
    stub(StatusSync, :send_params, fn _, _ -> :ok end)

    assert {:noreply, state} =
             EquipmentHandler.handle_unequip(0, %{connection_pid: self(), game_state: caster})

    assert state.game_state.inventory[0].equip == 0

    assert StatusStorage.has_status?(:player, 101, :sc_maxoverthrust) ==
             (GameMode.mode() == :pre_renewal)
  end

  test "classic_self_break_reads_attacking_units_buff" do
    stub(Config, :natural_break_rate, fn -> 0 end)

    wearer =
      CombatTestHelper.create_player_combatant(unit_id: 101, weapon_type: :one_handed_sword)

    assert :ok = apply_status(:sc_maxoverthrust)
    result = EquipBreak.resolve(wearer, {:mob, 202}, rng: fn _ -> 10 end)
    assert result == if(GameMode.mode() == :pre_renewal, do: [{:self, :weapon}], else: [])

    refute {:self, :weapon} in EquipBreak.resolve(%{wearer | unit_id: 102}, {:mob, 202},
             rng: fn _ -> 1 end
           )
  end

  defp apply_status(status) do
    Interpreter.apply_status(:player, 101, status, val1: 5, caster_id: 101, duration: 180_000)
  end

  defp mob do
    spawn = %MobSpawn{
      mob: 1_002,
      amount: 1,
      respawn_time: 5_000,
      spawn_area: %SpawnArea{x: 10, y: 10}
    }

    MobState.new(201, TestMob.definition(), spawn, "prontera", 10, 10)
  end
end
