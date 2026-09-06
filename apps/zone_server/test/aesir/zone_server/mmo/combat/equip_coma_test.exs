defmodule Aesir.ZoneServer.Mmo.Combat.EquipComaTest do
  use ExUnit.Case, async: false

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.Combat.EquipComa
  alias Aesir.ZoneServer.PlayerStateFixture
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  test "rolls the signed exact-race plus :all rate" do
    attacker =
      CombatTestHelper.create_player_combatant()
      |> with_modifiers(%{{:coma_race, :brute} => 1_200, {:coma_race, :all} => -200})

    target = CombatTestHelper.create_mob_combatant(race: :brute)
    test_pid = self()

    assert EquipComa.trigger?(attacker, target,
             roll: fn rate ->
               send(test_pid, {:rolled, rate})
               true
             end
           )

    assert_received {:rolled, 1_000}
  end

  test "does not invoke the roller for a non-positive effective rate" do
    target = CombatTestHelper.create_mob_combatant(race: :brute)

    for all_rate <- [-100, -101] do
      attacker =
        CombatTestHelper.create_player_combatant()
        |> with_modifiers(%{{:coma_race, :brute} => 100, {:coma_race, :all} => all_rate})

      refute EquipComa.trigger?(attacker, target, roll: fn _rate -> flunk("unexpected roll") end)
    end
  end

  test "clamps rates above 10,000 and succeeds without invoking the roller" do
    attacker =
      CombatTestHelper.create_player_combatant()
      |> with_modifiers(%{{:coma_race, :brute} => 12_000})

    target = CombatTestHelper.create_mob_combatant(race: :brute)

    assert EquipComa.trigger?(attacker, target, roll: fn _rate -> flunk("unexpected roll") end)
  end

  test "rejects non-player attackers and unsupported target types without rolling" do
    player =
      CombatTestHelper.create_player_combatant()
      |> with_modifiers(%{{:coma_race, :all} => 10_000})

    mob = CombatTestHelper.create_mob_combatant()
    no_roll = [roll: fn _rate -> flunk("unexpected roll") end]

    for attacker_type <- [:mob, :npc, :homunculus, :skill_unit] do
      refute EquipComa.trigger?(%{player | unit_type: attacker_type}, mob, no_roll)
    end

    for target_type <- [:npc, :skill_unit] do
      refute EquipComa.trigger?(player, %{mob | unit_type: target_type}, no_roll)
    end
  end

  test "status immunity suppresses coma without rolling" do
    attacker =
      CombatTestHelper.create_player_combatant()
      |> with_modifiers(%{{:coma_race, :all} => 10_000})

    target = %{CombatTestHelper.create_mob_combatant() | status_immune: true}

    refute EquipComa.trigger?(attacker, target, roll: fn _rate -> flunk("unexpected roll") end)
  end

  test "competitive mob classifications suppress coma without rolling" do
    attacker =
      CombatTestHelper.create_player_combatant()
      |> with_modifiers(%{{:coma_race, :all} => 10_000})

    for classification <- [:gvg, :battlefield] do
      target = %{CombatTestHelper.create_mob_combatant() | race2: [classification]}

      refute EquipComa.trigger?(attacker, target, roll: fn _rate -> flunk("unexpected roll") end)
    end
  end

  test "accepts player, mob, and Homunculus recipients" do
    attacker =
      CombatTestHelper.create_player_combatant()
      |> with_modifiers(%{{:coma_race, :all} => 10_000})

    homunculus =
      Combatant.new!(%{
        unit_type: :homunculus,
        unit_id: 3_001,
        social_root: {:player, 1001},
        reward_root: {:player, 1001},
        race: :formless
      })

    targets = [
      CombatTestHelper.create_player_combatant(unit_id: 2_001),
      CombatTestHelper.create_mob_combatant(unit_id: 2_002),
      homunculus
    ]

    for target <- targets do
      assert EquipComa.trigger?(attacker, target, roll: fn _rate -> flunk("unexpected roll") end)
    end
  end

  test "returns the injected roller's decision" do
    attacker =
      CombatTestHelper.create_player_combatant()
      |> with_modifiers(%{{:coma_race, :brute} => 9_999})

    target = CombatTestHelper.create_mob_combatant(race: :brute)

    refute EquipComa.trigger?(attacker, target, roll: fn 9_999 -> false end)
  end

  test "adds exact and wildcard class coma rates to the race rate" do
    attacker =
      CombatTestHelper.create_player_combatant()
      |> with_modifiers(%{
        {:coma_class, :boss} => 2_000,
        {:coma_class, :all} => 500,
        {:coma_race, :brute} => 1_000
      })

    target = CombatTestHelper.create_mob_combatant(race: :brute, class: :boss)

    assert EquipComa.trigger?(attacker, target, roll: fn 3_500 -> true end)
  end

  test "does not apply a class-specific coma rate to another class" do
    attacker =
      CombatTestHelper.create_player_combatant()
      |> with_modifiers(%{{:coma_class, :boss} => 2_000, {:coma_class, :all} => 500})

    target = CombatTestHelper.create_mob_combatant(class: :normal)

    assert EquipComa.trigger?(attacker, target, roll: fn 500 -> true end)
  end

  @tag game_mode: :renewal
  test "renewal players match player-human coma but not demi-human coma" do
    target = player_target()
    attacker = CombatTestHelper.create_player_combatant()
    no_roll = [roll: fn _rate -> flunk("unexpected roll") end]

    assert EquipComa.trigger?(
             with_modifiers(attacker, %{{:coma_race, :player_human} => 10_000}),
             target,
             no_roll
           )

    refute EquipComa.trigger?(
             with_modifiers(attacker, %{{:coma_race, :demi_human} => 10_000}),
             target,
             no_roll
           )

    assert GameMode.mode() == :renewal
  end

  @tag game_mode: :pre_renewal
  test "pre-renewal players match demi-human coma but not player-human coma" do
    target = player_target()
    attacker = CombatTestHelper.create_player_combatant()
    no_roll = [roll: fn _rate -> flunk("unexpected roll") end]

    assert EquipComa.trigger?(
             with_modifiers(attacker, %{{:coma_race, :demi_human} => 10_000}),
             target,
             no_roll
           )

    refute EquipComa.trigger?(
             with_modifiers(attacker, %{{:coma_race, :player_human} => 10_000}),
             target,
             no_roll
           )

    assert GameMode.mode() == :pre_renewal
  end

  defp with_modifiers(combatant, modifiers), do: %{combatant | equip_modifiers: modifiers}

  defp player_target do
    %PlayerState{
      character_id: 2_003,
      map_name: "prontera",
      x: 100,
      y: 100,
      stats: %{}
    }
    |> PlayerStateFixture.build()
    |> PlayerState.to_combatant()
  end
end
