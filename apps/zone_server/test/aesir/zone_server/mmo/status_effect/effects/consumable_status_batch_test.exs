defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.ConsumableStatusBatchTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.JobManagement
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Acaraje
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.ArmorResist
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.ElementalChange
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.IncreaseMaxHp
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.IncreaseMaxSp
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Vitata500
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.PlayerStateFixture
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Calculator
  alias Aesir.ZoneServer.Unit.Stats.CombatStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_private

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})

    player =
      PlayerStateFixture.build(%{
        character_id: 88_102,
        account_id: 88_102,
        stats: %{
          combat_stats: %CombatStats{},
          base_stats: %{vit: 0, luk: 0},
          modifiers: %{equipment: %{{:res_eff, :sc_stun} => 1_000}}
        }
      })

    :ok = UnitRegistry.register_unit(:player, 88_102, PlayerState, player, self())
    :ok
  end

  test "same-millisecond scripted-status refresh still restarts periodic recovery" do
    stub(Interpreter, :get_all_modifiers, fn :player, 88_102 -> %{} end)
    stats = Stats.from_character(%Character{class: 0})
    base = Calculator.calculate_stats(stats, 88_102, [])

    :ok = StatusStorage.apply_status(:player, 88_102, :sc_s_lifepotion, val1: -5, val2: 5)
    StatusStorage.update_status(:player, 88_102, :sc_s_lifepotion, &%{&1 | started_at: 123})
    applied = Calculator.calculate_stats(base, 88_102, [])

    :ok = StatusStorage.apply_status(:player, 88_102, :sc_s_lifepotion, val1: -5, val2: 5)
    StatusStorage.update_status(:player, 88_102, :sc_s_lifepotion, &%{&1 | started_at: 123})
    refreshed = Calculator.calculate_stats(applied, 88_102, [])

    assert refreshed.generation == applied.generation + 1
  end

  test "armor scrolls keep level one, skill applications roll, and restores keep initialized values" do
    fixed = %StatusEntry{val1: 1, val2: 6, val3: 1}

    assert {:ok, %{val1: 1, val2: 6, val3: 0}} =
             ElementalChange.on_apply({:player, 88_102}, fixed, %{})

    skill = %StatusEntry{val1: 1, val2: 1, val3: 0}
    assert {:ok, rolled} = ElementalChange.on_apply({:mob, 1}, skill, %{})
    assert rolled.val1 in 1..4
    assert rolled.val2 == 1
    assert {:ok, ^skill} = ElementalChange.on_apply({:mob, 1}, skill, %{loaded: true})
  end

  test "scripted maximum bonuses share the equipment stage before ordinary status rates" do
    entry = %StatusEntry{val1: 5, val2: 10}

    modifiers =
      [
        %{max_hp_rate: 50, max_sp_rate: 50},
        IncreaseMaxHp.modifiers(entry, %{}),
        IncreaseMaxSp.modifiers(entry, %{}),
        Vitata500.modifiers(entry, %{})
      ]
      |> Enum.reduce(%{}, &ModifierCalculator.merge_modifiers(&2, &1))

    stub(Interpreter, :get_all_modifiers, fn :player, 88_102 -> modifiers end)
    stats = Stats.from_character(%Character{class: 0, base_level: 99})
    calculated = Calculator.calculate_stats(stats, 88_102, [])
    {:ok, table} = JobManagement.get_base_stats_for_level(:novice, 99)
    hp_before_status = table.hp * 1.01 * 1.05
    sp_before_status = table.sp * 1.01 * 1.10

    assert calculated.derived_stats.max_hp ==
             trunc(hp_before_status + trunc(hp_before_status * 0.5))

    assert calculated.derived_stats.max_sp ==
             trunc(sp_before_status + trunc(sp_before_status * 0.5))
  end

  test "maxima and recovery remain separate, while Vitata bonuses are fixed" do
    entry = %StatusEntry{val1: 5, val2: 10}
    assert IncreaseMaxHp.modifiers(entry, %{}) == %{max_hp_equip_rate: 5, hp_regen: 10}
    assert IncreaseMaxSp.modifiers(entry, %{}) == %{max_sp_equip_rate: 5, sp_regen: 10}
    assert Vitata500.modifiers(entry, %{}) == %{max_sp_equip_rate: 5, sp_regen: 20}
    assert Acaraje.modifiers(entry, %{}) == %{aspd_rate: 5, hit: 10}

    assert ArmorResist.modifiers(%StatusEntry{val1: 10, val2: 20, val3: 30, val4: 40}, %{}) ==
             %{subele_water: 10, subele_earth: 20, subele_fire: 30, subele_wind: 40}
  end

  test "Mega Resist adds raw per-ten-thousand resistance to equipment at the real apply seam" do
    assert :ok =
             Interpreter.apply_status(:player, 88_102, :sc_commonsc_resist,
               val1: 10,
               duration: 3_600_000
             )

    assert :ok =
             Interpreter.apply_status(:player, 88_102, :sc_stun,
               duration: 10_000,
               success_rate: 100,
               no_tick_def: true,
               resistance_roll: fn rate ->
                 send(self(), {:defended_rate, rate})
                 true
               end
             )

    assert_received {:defended_rate, 8_990}
  end
end
