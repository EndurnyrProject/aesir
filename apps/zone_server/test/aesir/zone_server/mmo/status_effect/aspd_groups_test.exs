defmodule Aesir.ZoneServer.Mmo.StatusEffect.AspdGroupsTest do
  use ExUnit.Case, async: true

  import Aesir.ZoneServer.Factory
  import Mimic

  alias Aesir.Commons.GameMode
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.JobManagement
  alias Aesir.ZoneServer.Mmo.Mechanics.MobFormulas.PreRenewal
  alias Aesir.ZoneServer.Mmo.Mechanics.MobFormulas.Renewal
  alias Aesir.ZoneServer.Mmo.MobManagement
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Adrenaline
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.AssassinCross
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Berserk
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Fleet
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.SpearQuicken
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.TwoHandQuicken
  alias Aesir.ZoneServer.Mmo.StatusEffect.MobParameters
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Calculator
  alias Aesir.ZoneServer.Unit.Player.Stats.EquipmentFold
  alias Aesir.ZoneServer.Unit.Player.Stats.Modifiers
  alias Aesir.ZoneServer.Unit.Stats.BaseStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_private

  setup do
    stub(JobManagement, :get_base_aspd, fn :swordman, :fist -> {:ok, 100} end)
    :ok
  end

  test "aspd_group_no_sum_test: renewal quicken and Madness take the strongest value before potions" do
    stub(GameMode, :mode, fn -> :renewal end)

    modifiers =
      [
        TwoHandQuicken.modifiers(%StatusEntry{val1: 1, val2: 7}, %{}),
        Adrenaline.modifiers(%StatusEntry{val1: 1}, %{}),
        Berserk.modifiers(%StatusEntry{}, %{}),
        %{aspd_rate_strongest: 20},
        %{aspd: 2}
      ]
      |> Enum.reduce(%{}, &ModifierCalculator.merge_modifiers(&2, &1))

    assert Calculator.calculate_aspd(stats(modifiers)) == 124
  end

  test "aspd_assncross_add_test: renewal song adds only above the quicken group before the strongest floor" do
    stub(GameMode, :mode, fn -> :renewal end)
    quicken = TwoHandQuicken.modifiers(%StatusEntry{val1: 1, val2: 7}, %{})
    song = AssassinCross.modifiers(%StatusEntry{val2: 10}, %{})
    both = ModifierCalculator.merge_modifiers(quicken, song)

    assert Calculator.calculate_aspd(stats(song)) == 118
    assert Calculator.calculate_aspd(stats(both)) == 122
    assert Calculator.calculate_aspd(stats(Map.put(both, :aspd_rate_strongest, 15))) == 122
    assert Calculator.calculate_aspd(stats(Map.put(both, :aspd_rate_strongest, 20))) == 123

    weaker_song = AssassinCross.modifiers(%StatusEntry{val2: 7}, %{})

    assert Calculator.calculate_aspd(
             stats(ModifierCalculator.merge_modifiers(quicken, weaker_song))
           ) == 117
  end

  test "aspd_pre_re_best_test: classic quickens use one maximum and Berserk wins over Madness" do
    stub(GameMode, :mode, fn -> :pre_renewal end)

    modifiers =
      merge([
        Adrenaline.modifiers(%StatusEntry{val2: 0}, %{}),
        SpearQuicken.modifiers(%StatusEntry{val1: 5}, %{}),
        Fleet.modifiers(%StatusEntry{val2: 300}, %{})
      ])

    stub(JobManagement, :get_base_aspd, fn :swordman, :fist -> {:ok, 1_000} end)
    assert Calculator.calculate_aspd(stats(modifiers)) == 158
    assert modifiers.aspd_rate_max == 30

    modifiers =
      merge([modifiers, Berserk.modifiers(%StatusEntry{}, %{}), %{aspd_rate_strongest: 20}])

    assert modifiers.aspd_rate_strongest == 30
    assert Calculator.calculate_aspd(stats(modifiers)) == 176
  end

  test "assncross_weapon_gate_test: classic excludes bows and all guns only for players" do
    for mode <- [:renewal, :pre_renewal] do
      stub(GameMode, :mode, fn -> mode end)

      for weapon <- [:bow, :revolver, :rifle, :gatling, :shotgun, :grenade, :dagger] do
        modifiers =
          AssassinCross.modifiers(%StatusEntry{val2: 10}, %{
            unit_type: :player,
            target: %{weapon_type: weapon}
          })

        expected = if mode == :pre_renewal and weapon != :dagger, do: 0, else: 10

        assert Map.get(modifiers, if(mode == :renewal, do: :aspd_assncross, else: :aspd_rate_max)) ==
                 expected
      end

      key = if mode == :renewal, do: :aspd_assncross, else: :aspd_rate_max

      for unit_type <- [:player, :mob], target <- [%{}, %{weapon_type: nil}] do
        assert AssassinCross.modifiers(%StatusEntry{val2: 10}, %{
                 unit_type: unit_type,
                 target: target
               }) ==
                 %{key => 10}
      end
    end
  end

  test "mob_quicken_group_test: mob rate maximum and Madness remain in per-mille units" do
    {:ok, form} = MobManagement.get_mob_by_id(1002)
    state = build(:mob_state, mob_data: %{form | attack_motion: 800, attack_delay: 1_000})

    held = [
      %StatusEntry{type: :sc_twohandquicken, val2: 300},
      %StatusEntry{type: :sc_adrenaline, val3: 200}
    ]

    madness = %StatusEntry{type: :sc_madnesscancel}

    fever =
      MobParameters.initialize(%StatusEntry{type: :sc_gatlingfever, val1: 10}, :renewal, %{})

    assert {fever.val2, fever.val3, fever.val4} == {200, 120, 50}

    for formulas <- [Renewal, PreRenewal] do
      assert formulas.recalculate(state, held, ["Aspd"]).aspd_rate == 700
      assert formulas.recalculate(state, [fever], ["Aspd"]).aspd_rate == 800
      assert formulas.recalculate(state, [fever | held], ["Aspd"]).aspd_rate == 700
      assert formulas.recalculate(state, [madness | held], ["Aspd"]).aspd_rate == 500

      assert formulas.recalculate(state, [%StatusEntry{type: :sc_berserk}, madness | held], [
               "Aspd"
             ]).aspd_rate == 400
    end

    state = %{state | base: %{state.base | batk: 10}, calculated: %{state.calculated | batk: 10}}
    assert PreRenewal.recalculate(state, [madness, fever], ["Batk"]).batk == 230
    assert Renewal.recalculate(state, [madness, fever], ["Batk"]).batk == 10
  end

  test "renewal Quagmire suppresses only the fixed quicken group" do
    stub(GameMode, :mode, fn -> :renewal end)

    stub(StatusStorage, :get_unit_statuses, fn :player, 1 ->
      [
        %StatusEntry{type: :sc_fleet, val2: 300, val3: 0, started_at: 0},
        %StatusEntry{type: :sc_quagmire, val2: 5, started_at: 0}
      ]
    end)

    stub(UnitRegistry, :get_unit_info, fn :player, 1 -> {:ok, %{stats: %{}}} end)
    assert Map.get(ModifierCalculator.get_all_modifiers(:player, 1), :aspd_fixed_max, 0) == 0
  end

  test "held Quagmire lowers ASPD through AGI and DEX without a direct speed modifier" do
    stub(StatusStorage, :get_unit_statuses, fn :player, 1 ->
      [%StatusEntry{type: :sc_quagmire, val2: 25, started_at: 0}]
    end)

    stub(UnitRegistry, :get_unit_info, fn :player, 1 -> {:ok, %{stats: %{}}} end)
    baseline = %{stats(%{}) | base_stats: %BaseStats{agi: 100, dex: 50}}

    for {mode, delay, expected} <- [
          {:renewal, 100, {114, 109}},
          {:pre_renewal, 1_000, {145, 133}}
        ] do
      stub(GameMode, :mode, fn -> mode end)
      stub(JobManagement, :get_base_aspd, fn :swordman, :fist -> {:ok, delay} end)
      modifiers = ModifierCalculator.get_all_modifiers(:player, 1)

      refute Map.has_key?(modifiers, :aspd)
      refute Map.has_key?(modifiers, :aspd_rate)
      assert %{agi: -25, dex: -25, movement_speed: 50} = modifiers

      affected = %{baseline | modifiers: %Modifiers{status_effects: modifiers}}

      assert {Calculator.calculate_aspd(baseline), Calculator.calculate_aspd(affected)} ==
               expected
    end
  end

  test "Assassin Cross weapon swaps use folded equipment before the registry is committed" do
    stub(StatusStorage, :get_unit_statuses, fn :player, 1 ->
      [%StatusEntry{type: :sc_assncross, val2: 10, started_at: 0}]
    end)

    stub(StatusStorage, :count_unit_statuses, fn :player, 1 -> 1 end)
    stub(JobManagement, :get_base_aspd, fn :swordman, _weapon -> {:ok, 1_000} end)

    baseline = %{
      stats(%{})
      | base_stats: %BaseStats{
          str: 1,
          agi: 100,
          vit: 1,
          int: 1,
          dex: 0,
          luk: 1,
          pow: 0,
          sta: 0,
          wis: 0,
          spl: 0,
          con: 0,
          crt: 0
        }
    }

    for mode <- [:pre_renewal, :renewal],
        {old_id, old_weapon, new_id, new_weapon} <- [
          {1201, :dagger, 13_100, :revolver},
          {13_100, :revolver, 1201, :dagger}
        ] do
      stub(GameMode, :mode, fn -> mode end)
      previous = %InventoryItem{id: 1, nameid: old_id, amount: 1, equip: 2, identify: 1}
      replacement = %InventoryItem{id: 2, nameid: new_id, amount: 1, equip: 2, identify: 1}
      committed = EquipmentFold.apply_equipment_modifiers(baseline, [previous])
      holder = %PlayerState{character_id: 1, stats: committed}

      stub(UnitRegistry, :get_unit, fn :player, 1 -> {:ok, {PlayerState, holder, self()}} end)

      stub(UnitRegistry, :get_unit_info, fn :player, 1 ->
        {:ok, %{stats: %{weapon_type: old_weapon}}}
      end)

      folded = EquipmentFold.apply_equipment_modifiers(committed, [replacement])
      assert folded.right_hand.subtype == new_weapon
      calculated = Calculator.apply_status_effects(folded, 1)

      expected = if mode == :pre_renewal and new_weapon == :revolver, do: 0, else: 10
      key = if mode == :pre_renewal, do: :aspd_rate_max, else: :aspd_assncross
      assert calculated.modifiers.status_effects == %{key => expected}

      if mode == :pre_renewal do
        expected_aspd = if new_weapon == :revolver, do: 140, else: 146
        assert Calculator.calculate_aspd(calculated) == expected_aspd
      end
    end
  end

  defp merge(modifiers),
    do: Enum.reduce(modifiers, %{}, &ModifierCalculator.merge_modifiers(&2, &1))

  defp stats(modifiers) do
    %Stats{
      base_stats: %BaseStats{agi: 100, dex: 0},
      progression: %Stats.PlayerProgression{base_level: 1, job_level: 1, job_id: 1},
      equipment: %Stats.Equipment{},
      modifiers: %Modifiers{status_effects: modifiers}
    }
  end
end
