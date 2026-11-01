defmodule Aesir.ZoneServer.Unit.Player.StatusSelectionTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.PlayerStateFixture
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Calculator
  alias Aesir.ZoneServer.Unit.Player.Stats.Modifiers
  alias Aesir.ZoneServer.Unit.Player.Stats.StatusSelection
  alias Aesir.ZoneServer.Unit.Stats.CombatStats
  alias Aesir.ZoneServer.Unit.Stats.CurrentState
  alias Aesir.ZoneServer.Unit.Stats.DerivedStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  defmodule TransientFlee do
    use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
      id: :sc_test_selection_flee,
      target_types: [:player],
      no_dispel: false,
      no_clear_buff: false

    @impl true
    def modifiers(_instance, _context), do: %{flee: 50}
  end

  setup :setup_ets_tables

  test "primary dependency closure follows each mode without making partial selections full" do
    classic = StatusSelection.affected_fields(["Agi", "Dex"], :pre_renewal)
    renewal = StatusSelection.affected_fields(["Agi", "Dex"], :renewal)

    assert classic.primary == MapSet.new([:agi, :dex])
    assert MapSet.subset?(MapSet.new([:flee, :hit, :atk, :physical_attack]), classic.combat)
    refute MapSet.member?(classic.combat, :soft_def)
    refute MapSet.member?(classic.combat, :matk)
    assert classic.derived == MapSet.new([:aspd])
    assert MapSet.member?(renewal.combat, :soft_def)
    assert MapSet.member?(renewal.combat, :soft_mdef)
    assert MapSet.member?(renewal.combat, :matk)
    refute classic.full?
    refute renewal.full?

    for mode <- [:renewal, :pre_renewal] do
      resources = StatusSelection.affected_fields(["Vit", "Int"], mode)
      assert resources.derived == MapSet.new([:max_hp, :max_sp])
      assert MapSet.subset?(MapSet.new([:soft_def, :soft_mdef, :matk]), resources.combat)
      assert StatusSelection.affected_fields(["All"], mode).full?
      assert StatusSelection.affected_fields(["Base"], mode).full?
    end

    traits = StatusSelection.affected_fields(["Pow", "Sta", "Wis", "Spl", "Con", "Crt"], :renewal)
    assert MapSet.subset?(MapSet.new([:patk, :smatk, :res, :mres, :hplus, :crate]), traits.combat)
  end

  test "empty and speed-only selections preserve published flee" do
    before = %Stats{
      combat_stats: %CombatStats{flee: 40, hit: 50},
      derived_stats: %DerivedStats{max_hp: 100, max_sp: 50, aspd: 150},
      current_state: %CurrentState{hp: 80, sp: 40},
      modifiers: %Modifiers{status_effects: %{str: 3}},
      generation: 7,
      recalculation_basis: 123
    }

    candidate = %{
      before
      | combat_stats: %CombatStats{flee: 90, hit: 100},
        derived_stats: %DerivedStats{max_hp: 10, max_sp: 10, aspd: 170},
        current_state: %CurrentState{hp: 10, sp: 10},
        modifiers: %Modifiers{status_effects: %{str: 9, flee: 50, intravision: 1}},
        generation: 8,
        recalculation_basis: 456
    }

    for flags <- [[], ["Speed"]] do
      selection = StatusSelection.affected_fields(flags, :pre_renewal)
      result = StatusSelection.project(before, candidate, selection)

      assert result.combat_stats == before.combat_stats
      assert result.derived_stats == before.derived_stats
      assert result.current_state == before.current_state
      assert result.generation == 7
      assert result.recalculation_basis == 123
      assert result.modifiers.status_effects == %{str: 3, flee: 50, intravision: 1}
    end
  end

  test "partial selection does not clamp an unrelated maximum" do
    before = %Stats{
      combat_stats: %CombatStats{atk: 10, physical_attack: %{status_atk: 10}, flee: 40},
      derived_stats: %DerivedStats{max_hp: 100, max_sp: 50},
      current_state: %CurrentState{hp: 80, sp: 40}
    }

    calculated = %{
      before
      | combat_stats: %CombatStats{atk: 20, physical_attack: %{status_atk: 20}, flee: 90},
        derived_stats: %DerivedStats{max_hp: 10, max_sp: 10},
        current_state: %CurrentState{hp: 10, sp: 10}
    }

    max_hp = StatusSelection.affected_fields(["MaxHp"], :pre_renewal)
    clamped = StatusSelection.project(before, calculated, max_hp)
    assert clamped.current_state == %CurrentState{hp: 10, sp: 40}
    assert clamped.derived_stats.max_hp == 10
    assert clamped.derived_stats.max_sp == 50
    assert clamped.combat_stats == before.combat_stats

    attack = StatusSelection.affected_fields(["Batk"], :pre_renewal)
    attack_only = StatusSelection.project(before, calculated, attack)
    assert attack_only.combat_stats.atk == 20
    assert attack_only.combat_stats.physical_attack == %{status_atk: 20}
    assert attack_only.combat_stats.flee == 40
    assert attack_only.current_state == before.current_state
  end

  test "all selection rebuilds equipment and clamps selected maxima" do
    character = %Character{
      id: 7_702,
      account_id: 7_702,
      name: "Selection",
      class: 0,
      base_level: 1,
      job_level: 1,
      str: 1,
      agi: 1,
      vit: 1,
      int: 1,
      dex: 1,
      luk: 1,
      hp: 40,
      sp: 11
    }

    stats = Stats.from_character(character)
    player = PlayerStateFixture.build(%{character_id: character.id, stats: stats})
    :ok = UnitRegistry.register_player(player, self())
    :ok = Registry.register_module(TransientFlee)
    :ok = StatusStorage.apply_status(:player, character.id, :sc_test_selection_flee)

    empty = Calculator.calculate_status_change(stats, character.id, :sc_intravision, :apply)
    assert empty.combat_stats.flee == stats.combat_stats.flee
    assert empty.generation == stats.generation
    assert empty.modifiers.status_effects.flee == 50

    full = Calculator.calculate_status_change(empty, character.id, :sc_intravision, :removed)
    assert full.combat_stats.flee == stats.combat_stats.flee + 50
    assert full.generation > empty.generation
    assert full.current_state.hp <= full.derived_stats.max_hp
    assert full.current_state.sp <= full.derived_stats.max_sp
  end
end
