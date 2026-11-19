defmodule Aesir.ZoneServer.Mmo.Combat.StatusAttackStagesTest do
  @moduledoc """
  Where status ATK (`:batk`) and status weapon ATK (`:watk`) enter a player's
  attack: its status ATK before its rate and its weapon roll (the classic
  maximum, the renewal centre) per hand. A non-player's base is checked from its
  arranged combat stats.

  Every weapon roll is pinned to its maximum (`max_weapon_damage`). The player
  weapon is 100 ATK, +10 refine, level 3, with primary stat 55 and DEX 30, so
  its bounds without status weapon ATK are 122..152 in renewal and 42..99 in
  classic.
  """

  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup
  import Aesir.ZoneServer.Factory

  alias Aesir.ZoneServer.Mmo.Combat.DamageInputs
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats.Calculator
  alias Aesir.ZoneServer.Unit.Stats.CombatStats

  setup :set_mimic_from_context
  setup :verify_on_exit!
  setup :setup_ets_tables

  describe "a classic player's weapon roll" do
    @describetag game_mode: :pre_renewal

    test "status weapon ATK raises the right hand's roll maximum" do
      stub_modifiers(%{watk: 20})

      assert weapon_atk(attacker(weapon(:right_hand, 100, 3)), :primary) == 120
    end

    test "a level-4 weapon adds the level-4 status weapon ATK on top" do
      stub_modifiers(%{watk: 20, level4_watk: 100})

      assert weapon_atk(attacker(weapon(:right_hand, 100, 4)), :primary) == 220
      assert weapon_atk(attacker(weapon(:right_hand, 100, 3)), :primary) == 120
    end

    test "the left hand takes it only when its weapon has ATK" do
      stub_modifiers(%{watk: 20})
      right = weapon(:right_hand, 100, 3)

      assert weapon_atk(attacker(right, weapon(:left_hand, 50, 3)), :secondary) == 70
      assert weapon_atk(attacker(right, weapon(:left_hand, 0, 3)), :secondary) == 0
    end

    test "a bare hand rolls it as its maximum from an unscaled DEX minimum" do
      stub_modifiers(%{watk: 25, level4_watk: 100})
      pinned = attacker(nil)
      unpinned = %{pinned | combat_stats: %{pinned.combat_stats | max_weapon_damage: false}}

      assert weapon_atk(pinned, :primary) == 25
      # DEX 30 is capped to the maximum, so the roll has one value.
      assert weapon_atk(unpinned, :primary) == 25

      low_dex = put_in(unpinned.combat_stats.physical_attack.dex, 10)
      assert weapon_atk(low_dex, :primary) in 10..24
    end

    test "a bare hand's bAtk joins the status weapon ATK as its maximum" do
      stub_modifiers(%{watk: 25})

      assert weapon_atk(bare_atk(attacker(nil), 10), :primary) == 35
    end
  end

  describe "a renewal player's weapon roll" do
    @describetag game_mode: :renewal

    test "status weapon ATK shifts the right hand's centre without widening the variance" do
      stub_modifiers(%{watk: 20})
      attacker = attacker(weapon(:right_hand, 100, 3))

      assert weapon_atk(attacker, :primary) == 172

      assert weapon_atk(
               %{attacker | combat_stats: %{attacker.combat_stats | max_weapon_damage: false}},
               :primary
             ) in 142..172
    end

    test "a second weapon takes none while the right hand holds one" do
      stub_modifiers(%{watk: 20})
      attacker = attacker(weapon(:right_hand, 100, 3), weapon(:left_hand, 100, 3))

      assert weapon_atk(attacker, :primary) == 172
      assert weapon_atk(attacker, :secondary) == 152
    end

    test "a lone left-hand weapon takes it" do
      stub_modifiers(%{watk: 20})

      assert weapon_atk(attacker(nil, weapon(:left_hand, 100, 3)), :primary) == 172
    end

    test "the classic level-4 key is not read, and a bare hand reads nothing" do
      stub_modifiers(%{watk: 25, level4_watk: 100})

      # A level-4 weapon's own variance plus the plain status weapon ATK:
      # 110 + 25 + 100 * 55 / 200 + 5 * 100 * 4 / 100, never the level-4 key.
      assert weapon_atk(attacker(weapon(:right_hand, 100, 4)), :primary) == 182
      assert weapon_atk(attacker(nil), :primary) == 0
    end

    test "a bare hand's bAtk is its weapon ATK, unrolled, with the status weapon ATK" do
      stub_modifiers(%{watk: 25})
      bare = bare_atk(attacker(nil), 10)
      unpinned = %{bare | combat_stats: %{bare.combat_stats | max_weapon_damage: false}}

      assert weapon_atk(bare, :primary) == 35
      assert weapon_atk(unpinned, :primary) == 35
    end

    test "a bare right hand's bAtk keeps the status weapon ATK off a lone left weapon" do
      stub_modifiers(%{watk: 20})

      assert weapon_atk(bare_atk(attacker(nil, weapon(:left_hand, 100, 3)), 10), :primary) ==
               152
    end
  end

  describe "a non-player's base" do
    @tag game_mode: :pre_renewal
    test "a classic critical adds status ATK to the roll maximum without scaling" do
      mob = build(:mob_combatant, combat_stats: %CombatStats{atk: 7, atk_min: 60, atk_max: 80})

      assert DamageInputs.non_player_base_attack(mob, critical: true) == {:ok, 87}
    end
  end

  describe "Mental Charge on a non-player" do
    defp charged do
      :ok = StatusStorage.apply_status(:homunculus, 77, :sc_change, val2: 0, val3: 0)

      build(:mob_combatant,
        unit_type: :homunculus,
        unit_id: 77,
        combat_stats: %CombatStats{
          atk: 30,
          atk_min: 40,
          atk_max: 60,
          matk_min: 100,
          matk_max: 150
        }
      )
    end

    @tag game_mode: :pre_renewal
    test "classic takes the maximum MATK as the base of every attack" do
      assert DamageInputs.non_player_base_attack(charged()) == {:ok, 150}
      assert DamageInputs.non_player_base_attack(charged(), skill_id: 5) == {:ok, 150}
    end

    @tag game_mode: :renewal
    test "renewal rolls a normal attack from MATK without status ATK, a skill from ATK" do
      assert DamageInputs.non_player_base_attack(charged(), critical: true) == {:ok, 210}

      assert DamageInputs.non_player_base_attack(charged(), critical: true, skill_id: 5) ==
               {:ok, 126}
    end
  end

  describe "a player's status ATK" do
    test "flat status ATK joins before the status ATK rate" do
      stats = player_stats()
      base = Calculator.calculate_combat_stats(stats).combat_stats.physical_attack.status_atk

      raised =
        stats
        |> with_status_modifiers(%{batk: 30, batk_rate: 20})
        |> Calculator.calculate_combat_stats()

      assert raised.combat_stats.physical_attack.status_atk ==
               base + 30 + div((base + 30) * 20, 100)
    end
  end

  defp weapon_atk(attacker, path),
    do: DamageInputs.player_attack_parts(attacker, [], path, false).weapon_atk

  defp stub_modifiers(modifiers) do
    stub(ModifierCalculator, :get_battle_modifiers, fn _type, _id -> modifiers end)
  end

  defp attacker(right, left \\ nil) do
    attacker =
      build(:player_combatant, str: 55, dex: 30, weapon_type: :dagger)

    %{
      attacker
      | right_hand: right,
        left_hand: left,
        combat_stats: Map.put(attacker.combat_stats, :max_weapon_damage, true)
    }
  end

  defp bare_atk(attacker, atk),
    do: put_in(attacker.combat_stats.physical_attack[:bare_right_atk], atk)

  defp weapon(slot, base_atk, weapon_level) do
    build(:weapon_hand,
      base_atk: base_atk,
      weapon_level: weapon_level,
      refine_atk: 10,
      slot: slot
    )
  end

  defp player_stats do
    PlayerState.new(
      Aesir.Factory.build(:character,
        id: 44,
        account_id: 44,
        name: "Batk holder",
        class: 7,
        base_level: 70,
        job_level: 50,
        sex: "M",
        last_map: "prontera",
        last_x: 100,
        last_y: 100,
        str: 60,
        agi: 10,
        vit: 10,
        int: 10,
        dex: 30,
        luk: 20
      )
    ).stats
  end

  defp with_status_modifiers(stats, modifiers),
    do: %{stats | modifiers: %{stats.modifiers | status_effects: modifiers}}
end
