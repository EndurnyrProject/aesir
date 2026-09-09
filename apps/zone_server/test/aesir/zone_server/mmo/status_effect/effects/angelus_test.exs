defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.AngelusTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Angelus
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats
  alias Aesir.ZoneServer.Unit.Player.Stats.Modifiers
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.Stats.BaseStats
  alias Aesir.ZoneServer.Unit.Stats.CombatStats
  alias Aesir.ZoneServer.Unit.Stats.CurrentState
  alias Aesir.ZoneServer.Unit.Stats.DerivedStats

  # Level 10 Angelus: val2 = 5 * level = 50 percent.
  @instance %{val1: 10, val2: 50}

  # VIT 60 split across every layer, so a formula reading only the allocated
  # points would see 40 and produce 10 instead of 15.
  defp context do
    stats = %PlayerStats{
      base_stats: %BaseStats{str: 1, agi: 1, vit: 40, int: 1, dex: 1, luk: 1},
      derived_stats: %DerivedStats{max_hp: 100, max_sp: 50, aspd: 150},
      combat_stats: %CombatStats{},
      current_state: %CurrentState{hp: 100, sp: 50},
      progression: %PlayerProgression{base_level: 50, job_level: 20},
      modifiers: %Modifiers{
        job_bonuses: %{vit: 5},
        equipment: %{vit: 10},
        status_effects: %{vit: 5},
        passive: %{}
      }
    }

    %{target: PlayerStats.to_formula_map(stats)}
  end

  describe "modifiers/2" do
    test "the context carries the calculated VIT, not the allocated points" do
      target = context().target

      assert target.vit == 40
      assert target.total_stats.vit == 60
    end

    @tag game_mode: :renewal
    test "renewal adds soft defense off half the recipient's VIT and flat max HP" do
      # 60 / 2 * 50 / 100 = 15 soft defense; 50 * 10 = 500 max HP.
      assert Angelus.modifiers(@instance, context()) == %{vit_bonus: 15, max_hp: 500}
    end

    @tag game_mode: :pre_renewal
    test "pre-renewal raises existing soft defense by a percentage and adds no max HP" do
      assert Angelus.modifiers(@instance, context()) == %{def2_rate: 50}
    end
  end
end
