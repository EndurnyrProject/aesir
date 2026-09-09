defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.BlessingTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Blessing
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats
  alias Aesir.ZoneServer.Unit.Player.Stats.Modifiers
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.Stats.BaseStats
  alias Aesir.ZoneServer.Unit.Stats.CombatStats
  alias Aesir.ZoneServer.Unit.Stats.CurrentState
  alias Aesir.ZoneServer.Unit.Stats.DerivedStats

  defp entry(val1, val2),
    do: %StatusEntry{type: :sc_blessing, val1: val1, val2: val2, state: %{}}

  # STR 60, INT 40 and DEX 50 each split across the allocated points and the job
  # and equipment bonuses, so a formula reading only the allocated points would
  # halve 40/25/30 instead.
  defp context do
    stats = %PlayerStats{
      base_stats: %BaseStats{str: 40, agi: 1, vit: 1, int: 25, dex: 30, luk: 1},
      derived_stats: %DerivedStats{max_hp: 100, max_sp: 50, aspd: 150},
      combat_stats: %CombatStats{},
      current_state: %CurrentState{hp: 100, sp: 50},
      progression: %PlayerProgression{base_level: 50, job_level: 20},
      modifiers: %Modifiers{
        job_bonuses: %{str: 10, int: 5, dex: 10},
        equipment: %{str: 10, int: 10, dex: 10},
        status_effects: %{},
        passive: %{}
      }
    }

    %{target: PlayerStats.to_formula_map(stats)}
  end

  describe "modifiers/2 - normal blessing (val2 > 0)" do
    @tag game_mode: :renewal
    test "grants HIT equal to val1 * 2" do
      assert %{hit: 20} = Blessing.modifiers(entry(10, 10), context())
    end

    @tag game_mode: :renewal
    test "grants STR, INT, DEX each equal to val2" do
      assert %{str: 7, int: 7, dex: 7, hit: 20} = Blessing.modifiers(entry(10, 7), context())
    end

    @tag game_mode: :renewal
    test "HIT scales with val1, not val2" do
      assert %{hit: 10} = Blessing.modifiers(entry(5, 10), context())
    end

    @tag game_mode: :pre_renewal
    test "grants the same stats but no HIT in pre-renewal" do
      assert %{str: 7, int: 7, dex: 7, hit: 0} = Blessing.modifiers(entry(10, 7), context())
    end
  end

  describe "modifiers/2 - undead/demon (val2 = 0)" do
    test "halves the calculated STR, INT and DEX, not the allocated points" do
      target = context().target

      assert target.str == 40
      assert target.unbuffed_stats == %{str: 60, agi: 1, vit: 1, int: 40, dex: 50, luk: 1}

      mods = Blessing.modifiers(entry(10, 0), context())

      assert mods.str == -30
      assert mods.int == -20
      assert mods.dex == -25
    end

    @tag game_mode: :renewal
    test "still grants the full HIT bonus, which the hostile branch never halves" do
      assert Blessing.modifiers(entry(10, 0), context()).hit == 20
    end

    @tag game_mode: :pre_renewal
    test "grants no HIT at all in pre-renewal" do
      assert Blessing.modifiers(entry(10, 0), context()).hit == 0
    end
  end
end
