defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.WeaponPerfectionTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.WeaponPerfection
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @player_id 10_006

  setup :set_mimic_from_context
  setup :verify_on_exit!
  setup :setup_ets_tables

  setup do
    Mimic.copy(UnitRegistry)

    stub(UnitRegistry, :get_unit_info, fn :player, @player_id ->
      {:ok,
       %{
         unit_id: @player_id,
         unit_type: :player,
         race: :human,
         element: :neutral,
         element_level: 1,
         boss_flag: false,
         size: :medium,
         stats: %{level: 1, base_level: 1, str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1}
       }}
    end)

    :ok
  end

  test "a dagger deals full damage to a large target while active and half after expiry" do
    assert %{ignore_size_penalty: true} = WeaponPerfection.modifiers(%{}, %{})

    assert %{calc_flags: [:atk], icon: :weaponperfect, require_weapon: []} =
             WeaponPerfection.metadata()

    assert :ok =
             Interpreter.apply_status(:player, @player_id, :sc_weaponperfection, duration: 60_000)

    assert {:ok, 1_200.0} =
             DamageCalculator.apply_modifier_pipeline(1_200, combatant(), large_target())

    entry = StatusStorage.get_status(:player, @player_id, :sc_weaponperfection)

    assert Interpreter.expire_status_if_current(:player, @player_id, :sc_weaponperfection, entry)

    assert {:ok, 600.0} =
             DamageCalculator.apply_modifier_pipeline(1_200, combatant(), large_target())
  end

  defp combatant do
    stats =
      %Stats{
        base_stats: %{str: 0, agi: 0, vit: 0, int: 0, dex: 0, luk: 0},
        progression: %{base_level: 0, job_level: 0, learned_skills: %{}},
        derived_stats: %{max_hp: 1, max_sp: 1},
        equipment: %Equipment{},
        modifiers: %{
          equipment: %{},
          status_effects: %{},
          statuses_active?: false,
          job_bonuses: %{}
        }
      }
      |> Stats.apply_status_effects(@player_id)
      |> Stats.calculate_combat_stats()

    %{
      CombatTestHelper.create_player_combatant(unit_id: @player_id, weapon_type: :dagger)
      | combat_stats: stats.combat_stats
    }
  end

  defp large_target, do: CombatTestHelper.create_mob_combatant(size: :large)
end
