defmodule Aesir.ZoneServer.Unit.Player.ItemHealTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.ItemHeal
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.Stats.CurrentState
  alias Aesir.ZoneServer.Unit.Stats.DerivedStats

  @char_id 77_001
  @red_potion 501

  setup :setup_ets_tables

  describe "amounts/4 HP" do
    test "adds VIT, Increase HP Recovery, Potion Research and the flat rate, then compounds group, item and Increase Heal Rate" do
      game_state =
        build(
          vit: 10,
          learned: %{4 => 1, 227 => 2},
          equipment: %{
            :item_heal_rate => 10,
            {:add_item_group_heal, :bluebox} => 10,
            {:add_item_heal, @red_potion} => 10
          }
        )

      start(:sc_inchealrate, val1: 10)

      # 100 + 20 + 10 + 10 + 10 = 150; +10% group -> 165; +10% item -> 181; +10% -> 199
      assert ItemHeal.amounts(game_state, @red_potion, 100, 0) == {199, 0}
    end

    test "a lowered bonus never lowers the heal" do
      game_state = build(equipment: %{item_heal_rate: -50})

      assert ItemHeal.amounts(game_state, @red_potion, 100, 0) == {100, 0}
    end

    test "a negative amount is never amplified" do
      assert ItemHeal.amounts(build(vit: 50), @red_potion, -100, 0) == {-100, 0}
    end

    test "per-item and group rates only apply to the healing item" do
      game_state =
        build(
          equipment: %{
            {:add_item_group_heal, :ore} => 30,
            {:add_item_heal, 999} => 40
          }
        )

      assert ItemHeal.amounts(game_state, @red_potion, 100, 0) == {100, 0}
      assert ItemHeal.amounts(game_state, nil, 100, 0) == {100, 0}
    end
  end

  describe "amounts/4 SP" do
    test "adds INT, Increase SP Recovery, Potion Research and the SP rates, without Increase Heal Rate" do
      game_state =
        build(
          int: 10,
          learned: %{9 => 1, 227 => 2},
          equipment: %{
            :item_sp_heal_rate => 10,
            {:add_item_group_sp_heal, :bluebox} => 10,
            {:add_item_sp_heal, @red_potion} => 10
          }
        )

      start(:sc_inchealrate, val1: 50)

      assert ItemHeal.amounts(game_state, @red_potion, 0, 100) == {0, 181}
    end

    test "HP rates leave SP alone" do
      game_state = build(equipment: %{{:add_item_heal, @red_potion} => 40})

      assert ItemHeal.amounts(game_state, @red_potion, 0, 100) == {0, 100}
    end
  end

  describe "amounts/4 statuses" do
    test "No Recovery cancels both" do
      start(:sc_norecover_state, [])

      assert ItemHeal.amounts(build(vit: 10), @red_potion, 100, 50) == {0, 0}
    end

    @tag game_mode: :renewal
    test "renewal: Asura recovery cancels SP and Apple of Idun adds val3 / 100 HP" do
      start(:sc_extremityfist, [])
      start(:sc_appleidun, val1: 10, val2: 19, val3: 2_000)

      assert ItemHeal.amounts(build(), @red_potion, 100, 50) == {120, 0}
    end

    @tag game_mode: :pre_renewal
    test "pre-renewal: Asura recovery and Apple of Idun change nothing" do
      start(:sc_extremityfist, [])
      start(:sc_appleidun, val1: 10, val2: 19, val3: 2_000)

      assert ItemHeal.amounts(build(), @red_potion, 100, 50) == {100, 50}
    end
  end

  defp start(status, params),
    do: :ok = StatusStorage.apply_status(:player, @char_id, status, params)

  defp build(opts \\ []) do
    %PlayerState{
      character_id: @char_id,
      account_id: 1,
      stats: %Stats{
        base_stats: %{vit: Keyword.get(opts, :vit, 0), int: Keyword.get(opts, :int, 0)},
        current_state: %CurrentState{hp: 10, sp: 10},
        derived_stats: %DerivedStats{max_hp: 1_000, max_sp: 1_000, aspd: 150},
        modifiers: %{
          equipment: Keyword.get(opts, :equipment, %{}),
          status_effects: %{},
          job_bonuses: %{},
          passive: %{}
        },
        progression: %PlayerProgression{
          base_level: 1,
          job_level: 1,
          job_id: 0,
          learned_skills: Keyword.get(opts, :learned, %{})
        }
      }
    }
  end
end
