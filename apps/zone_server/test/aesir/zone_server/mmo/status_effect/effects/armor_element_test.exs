defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.ArmorElementTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Mmo.Combat.BattleFlags
  alias Aesir.ZoneServer.Mmo.Combat.EquipmentBonuses
  alias Aesir.ZoneServer.Mmo.Combat.MagicDamageCalculator
  alias Aesir.ZoneServer.Mmo.Mechanics.PhysicalAttack
  alias Aesir.ZoneServer.Mmo.StatusEffect.Dispel
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Mmo.StatusEffect.Resistance
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.PlayerStateFixture
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Dsl
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Stats.CombatStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @id 32_100
  @moduletag :capture_log

  setup :set_mimic_private

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})

    player =
      PlayerStateFixture.build(%{
        character_id: @id,
        account_id: @id,
        stats: %{
          combat_stats: %CombatStats{},
          progression: %{base_level: 1, job_level: 1, job_id: 0}
        }
      })

    :ok = UnitRegistry.register_unit(:player, @id, PlayerState, player, self())
    ctx = Ctx.from_session(%{game_state: player, connection_pid: self()}, {:item, 12118})
    %{ctx: ctx}
  end

  test "signed potion values reach physical, magic and misc damage and different potions add", %{
    ctx: ctx
  } do
    started = Dsl.sc_start(ctx, :sc_armor_element_fire, 1_200_000, [-15, 0, 20, 0])
    assert started.game_state.stats.modifiers.status_effects.subele_fire == 20
    assert_damage(:fire, 800)
    assert_damage(:water, 1_150)
    assert_damage(:neutral, 1_000)

    Dsl.sc_start(ctx, :sc_armor_element_water, 1_200_000, [20, 0, 0, -15])
    Dsl.sc_start(ctx, :sc_armor_element_earth, 1_200_000, [0, 20, -15, 0])
    Dsl.sc_start(ctx, :sc_armor_element_wind, 1_200_000, [0, -15, 0, 20])

    assert ModifierCalculator.get_all_modifiers(:player, @id) == %{
             subele_water: 5,
             subele_earth: 5,
             subele_fire: 5,
             subele_wind: 5
           }

    for element <- [:water, :earth, :fire, :wind], do: assert_damage(element, 950)
    assert_damage(:neutral, 1_000)
  end

  test "refresh replaces even a greater val1, survives dispel and ends independently", %{ctx: ctx} do
    Dsl.sc_start(ctx, :sc_armor_element_fire, 60_000, [50, 1, 2, 3])
    old = StatusStorage.get_status(:player, @id, :sc_armor_element_fire)
    before = System.monotonic_time(:millisecond)
    Dsl.sc_start(ctx, :sc_armor_element_fire, 1_200_000, [-15, 0, 20, 0])
    after_apply = System.monotonic_time(:millisecond)
    refreshed = StatusStorage.get_status(:player, @id, :sc_armor_element_fire)

    assert %{val1: -15, val2: 0, val3: 20, val4: 0} = refreshed
    assert refreshed.generation != old.generation
    assert refreshed.expires_at >= before + 1_200_000
    assert refreshed.expires_at <= after_apply + 1_200_000
    refute Interpreter.expire_status_if_current(:player, @id, :sc_armor_element_fire, old)

    Dsl.sc_start(ctx, :sc_armor_element_water, 1_200_000, [20, 0, 0, -15])
    assert :ok = Dispel.dispel({:player, @id})
    assert StatusStorage.get_status(:player, @id, :sc_armor_element_fire) == refreshed
    assert StatusStorage.has_status?(:player, @id, :sc_armor_element_water)

    assert Interpreter.expire_status_if_current(:player, @id, :sc_armor_element_fire, refreshed)
    assert_damage(:fire, 1_000)
    assert_damage(:water, 800)
    assert_damage(:wind, 1_150)

    assert {:error, :ineligible_target} =
             Interpreter.apply_status(:mob, @id, :sc_armor_element_fire,
               val1: -15,
               val3: 20,
               duration: 1_200_000
             )
  end

  test "four-value starts retain chance, no-avoid flags and detached or failed context behavior",
       %{
         ctx: ctx
       } do
    stub(Resistance, :roll_rate, fn rate -> rate > 50 end)
    values = [-15, 0, 20, 0]
    assert Dsl.sc_start(ctx, :sc_armor_element_fire, 60_000, values, 50) == ctx
    refute StatusStorage.has_status?(:player, @id, :sc_armor_element_fire)

    Dsl.sc_start(ctx, :sc_armor_element_fire, 60_000, values, 51)

    assert %{val1: -15, val3: 20} =
             StatusStorage.get_status(:player, @id, :sc_armor_element_fire)

    Interpreter.remove_status(:player, @id, :sc_armor_element_fire)
    Dsl.sc_start(ctx, :sc_armor_element_fire, 60_000, values, 0, 1)
    assert StatusStorage.has_status?(:player, @id, :sc_armor_element_fire)

    failed = %{ctx | status: {:error, :stopped}}
    detached = %{ctx | game_state: nil, char_id: nil}
    assert Dsl.sc_start(failed, :sc_armor_element_water, 60_000, values) == failed
    assert Dsl.sc_start(detached, :sc_armor_element_water, 60_000, values) == detached
    refute StatusStorage.has_status?(:player, @id, :sc_armor_element_water)
  end

  defp assert_damage(element, expected) do
    attacker =
      CombatTestHelper.create_mob_combatant(unit_id: @id + 1)
      |> Map.put(:combat_stats, %{matk: 1_000, matk_min: 1_000, matk_max: 1_000})

    defender =
      CombatTestHelper.create_player_combatant(unit_id: @id)
      |> Map.put(:combat_stats, %{mdef: 0, soft_mdef: 0})

    assert {:ok, %{damage: ^expected}} =
             MagicDamageCalculator.calculate_magic_damage(attacker, defender, element: element)

    modifiers = ModifierCalculator.get_all_modifiers(:player, @id)

    physical =
      EquipmentBonuses.physical_defense_cardfix(defender, attacker, %{
        elements: [element],
        ignore_element?: false,
        status_modifiers: modifiers,
        attack_flag: BattleFlags.build(:weapon, :short, false),
        ranged?: false,
        range_rates?: true
      })

    misc =
      EquipmentBonuses.misc_defense_cardfix(defender, attacker, %{
        element: element,
        ignore_element?: false,
        status_modifiers: modifiers,
        attack_flag: BattleFlags.build(:misc, :short, true)
      })

    assert PhysicalAttack.defender_cardfix(1_000, physical) == expected
    assert PhysicalAttack.defender_cardfix(1_000, misc) == expected
  end
end
