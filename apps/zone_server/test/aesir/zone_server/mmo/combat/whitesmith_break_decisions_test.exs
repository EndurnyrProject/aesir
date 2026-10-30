defmodule Aesir.ZoneServer.Mmo.Combat.WhitesmithBreakDecisionsTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Mmo.Combat.EquipBreak
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment
  alias Aesir.ZoneServer.Unit.Player.Stats.Modifiers
  alias Aesir.ZoneServer.Unit.Player.WeaponHand

  setup :set_mimic_private
  setup :setup_ets_tables

  setup do
    stub(Config, :natural_break_rate, fn -> 0 end)
    :ok
  end

  test "summon_and_master_status_ownership_stays_separate" do
    wearer = wearer(%{break_weapon_rate: 50, break_armor_rate: 50, unbreakable: 100})
    context = %{attacker: {:mob, 201}, source: {:player, 101}, wearer: wearer}

    for {original?, master?} <- [{true, false}, {false, true}, {true, true}, {false, false}] do
      StatusStorage.clear_unit_statuses(:mob, 201)
      StatusStorage.clear_unit_statuses(:player, 101)
      if original?, do: meltdown(:mob, 201)
      if master?, do: meltdown(:player, 101)

      expected_player = if original?, do: [{:target, :weapon}, {:target, :armor}], else: []
      assert EquipBreak.resolve_hit(context, target(), rng: fn _ -> 101 end) == expected_player

      expected_mob = if original? and master?, do: strips(), else: []

      assert EquipBreak.resolve_hit(context, {:unit, :mob, 202}, rng: fn _ -> 101 end) ==
               expected_mob
    end

    meltdown(:mob, 201)
    :ok = StatusStorage.apply_status(:mob, 201, :sc_maxoverthrust)
    unprotected = %{context | wearer: wearer(%{})}
    self_break = if GameMode.mode() == :pre_renewal, do: [{:self, :weapon}], else: []

    assert EquipBreak.resolve_hit(unprotected, target(), skill_id: 485, rng: fn _ -> 10 end) ==
             self_break

    StatusStorage.clear_unit_statuses(:mob, 201)
    :ok = StatusStorage.apply_status(:player, 101, :sc_maxoverthrust)
    assert EquipBreak.resolve_hit(unprotected, target(), skill_id: 485, rng: fn _ -> 1 end) == []

    meltdown(:mob, 201)
    no_wearer = %{attacker: {:mob, 201}, source: {:mob, 201}, wearer: nil}

    assert EquipBreak.resolve_hit(no_wearer, target(), rng: fn _ -> 1 end) == [
             {:target, :weapon},
             {:target, :armor}
           ]

    assert EquipBreak.resolve_hit(no_wearer, {:unit, :mob, 202}, rng: fn _ -> 1 end) == strips()
  end

  test "meltdown_rates_sum_before_prevention" do
    meltdown(:mob, 201, 3)

    context = %{
      attacker: {:mob, 201},
      source: {:mob, 201},
      wearer: wearer(%{break_weapon_rate: 101, break_armor_rate: 91})
    }

    target = target(%{unbreakable: 50})
    test_pid = self()

    rng = fn 10_000 ->
      send(test_pid, :rolled)
      151
    end

    assert EquipBreak.resolve_hit(context, target, rng: rng) == [
             {:target, :weapon},
             {:target, :armor}
           ]

    assert_received :rolled
    assert_received :rolled
    refute_received :rolled

    {:player, id, _} = target
    :ok = StatusStorage.apply_status(:player, id, :sc_cp_weapon)
    assert EquipBreak.resolve_hit(context, target, rng: fn _ -> 1 end) == [{:target, :armor}]

    assert EquipBreak.resolve_hit(context, target(%{unbreakable_weapon: 1, unbreakable_armor: 1}),
             rng: fn _ -> flunk("protected slots rolled") end
           ) == []

    assert EquipBreak.resolve_hit(context, target(%{unbreakable: 101}),
             rng: fn _ -> flunk("negative rate rolled") end
           ) == []
  end

  test "excluded_skills_keep_self_break_only" do
    stub(Config, :natural_break_rate, fn -> 10_000 end)
    meltdown(:mob, 201)

    context = %{
      attacker: {:mob, 201},
      source: {:player, 101},
      wearer: wearer(%{break_weapon_rate: 10_000, break_armor_rate: 10_000})
    }

    for id <- [337, 485] do
      assert EquipBreak.resolve_hit(context, target(), skill_id: id, rng: fn _ -> 1 end) == [
               {:self, :weapon}
             ]

      assert EquipBreak.resolve_hit(%{context | wearer: nil}, target(),
               skill_id: id,
               rng: fn _ -> flunk("excluded target rolled") end
             ) == []
    end
  end

  test "non_player_break_uses_strip_values_and_duration" do
    meltdown(:mob, 201)
    context = %{attacker: {:mob, 201}, source: {:mob, 201}, wearer: nil}
    assert EquipBreak.resolve_hit(context, {:unit, :mob, 202}, rng: fn _ -> 1 end) == strips()
    :ok = StatusStorage.apply_status(:mob, 202, :sc_cp_weapon)

    assert EquipBreak.resolve_hit(context, {:unit, :mob, 202}, rng: fn _ -> 1 end) == [
             {:strip, :sc_striparmor, 40, 75_000}
           ]

    :ok = StatusStorage.apply_status(:mob, 202, :sc_cp_armor)

    assert EquipBreak.resolve_hit(context, {:unit, :mob, 202},
             rng: fn _ -> flunk("chemical protection rolled") end
           ) == []

    assert EquipBreak.resolve_rates(10_000, 10_000, {:mob, 202}, rng: fn _ -> 1 end) == []
  end

  test "zero_rates_do_not_roll_and_boundary_is_per_ten_thousand" do
    context = %{attacker: {:mob, 201}, source: {:mob, 201}, wearer: nil}

    assert EquipBreak.resolve_hit(context, target(), rng: fn _ -> flunk("zero rate rolled") end) ==
             []

    meltdown(:mob, 201)

    assert EquipBreak.resolve_hit(context, target(), rng: fn 10_000 -> 100 end) == [
             {:target, :weapon}
           ]

    assert EquipBreak.resolve_hit(context, target(), rng: fn 10_000 -> 101 end) == []

    for weapon <- [
          :fist,
          :one_handed_axe,
          :two_handed_axe,
          :mace,
          :two_handed_mace,
          :staff,
          :two_handed_staff,
          :book,
          :huuma
        ] do
      wearer = %{wearer(%{break_weapon_rate: 10_000}) | weapon: %{type: weapon}}
      stub(Config, :natural_break_rate, fn -> 10_000 end)

      assert EquipBreak.resolve_hit(%{context | wearer: wearer}, target(%{unbreakable: 100}),
               rng: fn _ -> flunk("immune weapon rolled") end
             ) == []
    end
  end

  test "offhand_axe_prevents_weapon_break_for_both_player_views" do
    target =
      {:player, 301,
       %Stats{equipment: %Equipment{right_hand: 1_101, left_hand: 1_301}, modifiers: %Modifiers{}}}

    assert EquipBreak.resolve_rates(10_000, 0, target,
             rng: fn _ -> flunk("offhand axe rolled") end
           ) == []

    {:player, _, stats} = target
    stub(Config, :natural_break_rate, fn -> 10_000 end)
    context = %{attacker: {:player, 101}, source: {:player, 101}, wearer: stats}

    assert EquipBreak.resolve_hit(context, target,
             rng: fn _ -> flunk("offhand axe self rolled") end
           ) == []

    hand = %WeaponHand{
      item_id: 1_301,
      subtype: :one_handed_axe,
      element: :neutral,
      base_atk: 38,
      weapon_level: 1,
      refine_atk: 0,
      overrefine_band: 0,
      slot: :left_hand
    }

    combatant = %{wearer(%{}) | left_hand: hand}

    assert EquipBreak.resolve_hit(%{context | wearer: combatant}, target,
             rng: fn _ -> flunk("offhand combatant axe rolled") end
           ) == []
  end

  test "legacy_opaque_nonplayer_targets_remain_safe" do
    meltdown(:mob, 201)
    context = %{attacker: {:mob, 201}, source: {:mob, 201}, wearer: nil}

    assert EquipBreak.resolve(context, {:mob, %URI{}},
             rng: fn _ -> flunk("opaque target rolled") end
           ) == []
  end

  defp wearer(mods) do
    wearer =
      CombatTestHelper.create_player_combatant(unit_id: 101, weapon_type: :one_handed_sword)

    %{wearer | equip_modifiers: mods}
  end

  defp target(mods \\ %{}) do
    {:player, 301,
     %Stats{equipment: %Equipment{right_hand: 1_101}, modifiers: %Modifiers{equipment: mods}}}
  end

  defp meltdown(type, id, level \\ 1) do
    StatusStorage.apply_status(type, id, :sc_meltdown,
      val1: level,
      val2: 100 * level,
      val3: 70 * level
    )
  end

  defp strips, do: [{:strip, :sc_stripweapon, 25, 75_000}, {:strip, :sc_striparmor, 40, 75_000}]
end
