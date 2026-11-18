defmodule Aesir.ZoneServer.Mmo.Combat.EquipComaTest do
  use ExUnit.Case, async: true

  import Aesir.ZoneServer.Factory

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat.EquipComa
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  test "rolls the signed exact-race plus :all rate" do
    attacker =
      build(:player_combatant,
        equip_modifiers: %{{:coma_race, :brute} => 1_200, {:coma_race, :all} => -200}
      )

    target = build(:mob_combatant, race: :brute)
    test_pid = self()

    assert EquipComa.trigger?(attacker, target,
             roll: fn rate ->
               send(test_pid, {:rolled, rate})
               true
             end
           )

    assert_received {:rolled, 1_000}
  end

  test "bonus? is the attacker's class or race coma bonus, whatever the target" do
    assert EquipComa.bonus?(build(:player_combatant, equip_modifiers: %{{:coma_race, :all} => 1}))

    assert EquipComa.bonus?(
             build(:player_combatant,
               equip_modifiers: %{
                 {:coma_class, :boss} => 1
               }
             )
           )

    refute EquipComa.bonus?(build(:player_combatant, equip_modifiers: %{{:crit_race, :all} => 5}))

    refute EquipComa.bonus?(build(:player_combatant))
  end

  test "does not invoke the roller for a non-positive effective rate" do
    target = build(:mob_combatant, race: :brute)

    for all_rate <- [-100, -101] do
      attacker =
        build(:player_combatant,
          equip_modifiers: %{{:coma_race, :brute} => 100, {:coma_race, :all} => all_rate}
        )

      refute EquipComa.trigger?(attacker, target, roll: fn _rate -> flunk("unexpected roll") end)
    end
  end

  test "clamps rates above 10,000 and succeeds without invoking the roller" do
    attacker =
      build(:player_combatant, equip_modifiers: %{{:coma_race, :brute} => 12_000})

    target = build(:mob_combatant, race: :brute)

    assert EquipComa.trigger?(attacker, target, roll: fn _rate -> flunk("unexpected roll") end)
  end

  test "rejects non-player attackers and unsupported target types without rolling" do
    player =
      build(:player_combatant, equip_modifiers: %{{:coma_race, :all} => 10_000})

    mob = build(:mob_combatant)
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
      build(:player_combatant, equip_modifiers: %{{:coma_race, :all} => 10_000})

    target = build(:mob_combatant, status_immune: true)

    refute EquipComa.trigger?(attacker, target, roll: fn _rate -> flunk("unexpected roll") end)
  end

  test "a status-immune target still takes the class coma, without its race share" do
    attacker =
      build(:player_combatant,
        equip_modifiers: %{{:coma_race, :all} => 10_000, {:coma_class, :boss} => 300}
      )

    target = build(:mob_combatant, class: :boss, status_immune: true)

    assert EquipComa.trigger?(attacker, target, roll: fn 300 -> true end)
  end

  test "the gvg monster group and the battlefield sprite id suppress coma without rolling" do
    attacker =
      build(:player_combatant, equip_modifiers: %{{:coma_race, :all} => 10_000})

    no_roll = [roll: fn _rate -> flunk("unexpected roll") end]

    refute EquipComa.trigger?(
             attacker,
             build(:mob_combatant, race2: [:gvg]),
             no_roll
           )

    refute EquipComa.trigger?(
             attacker,
             build(:mob_combatant, monster_id: 4),
             no_roll
           )
  end

  test "neither the battlefield class nor the battlefield group suppresses coma" do
    attacker =
      build(:player_combatant, equip_modifiers: %{{:coma_class, :battlefield} => 10_000})

    target =
      build(:mob_combatant,
        class: :battlefield,
        monster_id: 1_909,
        race2: [:battlefield],
        status_immune: true
      )

    assert EquipComa.trigger?(attacker, target, roll: fn _rate -> flunk("unexpected roll") end)
  end

  test "accepts player, mob, and Homunculus recipients" do
    attacker =
      build(:player_combatant, equip_modifiers: %{{:coma_race, :all} => 10_000})

    homunculus =
      build(:player_combatant,
        unit_type: :homunculus,
        unit_id: 3_001,
        social_root: {:player, 1001},
        reward_root: {:player, 1001},
        race: :formless
      )

    targets = [
      build(:player_combatant, unit_id: 2_001),
      build(:mob_combatant, unit_id: 2_002),
      homunculus
    ]

    for target <- targets do
      assert EquipComa.trigger?(attacker, target, roll: fn _rate -> flunk("unexpected roll") end)
    end
  end

  test "returns the injected roller's decision" do
    attacker =
      build(:player_combatant, equip_modifiers: %{{:coma_race, :brute} => 9_999})

    target = build(:mob_combatant, race: :brute)

    refute EquipComa.trigger?(attacker, target, roll: fn 9_999 -> false end)
  end

  test "adds exact and wildcard class coma rates to the race rate" do
    attacker =
      build(:player_combatant,
        equip_modifiers: %{
          {:coma_class, :boss} => 2_000,
          {:coma_class, :all} => 500,
          {:coma_race, :brute} => 1_000
        }
      )

    target = build(:mob_combatant, race: :brute, class: :boss)

    assert EquipComa.trigger?(attacker, target, roll: fn 3_500 -> true end)
  end

  test "does not apply a class-specific coma rate to another class" do
    attacker =
      build(:player_combatant,
        equip_modifiers: %{{:coma_class, :boss} => 2_000, {:coma_class, :all} => 500}
      )

    target = build(:mob_combatant, class: :normal)

    assert EquipComa.trigger?(attacker, target, roll: fn 500 -> true end)
  end

  @tag game_mode: :renewal
  test "renewal players match player-human coma but not demi-human coma" do
    target = player_target()
    no_roll = [roll: fn _rate -> flunk("unexpected roll") end]

    assert EquipComa.trigger?(
             build(:player_combatant, equip_modifiers: %{{:coma_race, :player_human} => 10_000}),
             target,
             no_roll
           )

    refute EquipComa.trigger?(
             build(:player_combatant, equip_modifiers: %{{:coma_race, :demi_human} => 10_000}),
             target,
             no_roll
           )

    assert GameMode.mode() == :renewal
  end

  @tag game_mode: :pre_renewal
  test "pre-renewal players match demi-human coma but not player-human coma" do
    target = player_target()
    no_roll = [roll: fn _rate -> flunk("unexpected roll") end]

    assert EquipComa.trigger?(
             build(:player_combatant, equip_modifiers: %{{:coma_race, :demi_human} => 10_000}),
             target,
             no_roll
           )

    refute EquipComa.trigger?(
             build(:player_combatant, equip_modifiers: %{{:coma_race, :player_human} => 10_000}),
             target,
             no_roll
           )

    assert GameMode.mode() == :pre_renewal
  end

  defp player_target do
    :player_state
    |> build(character_id: 2_003, map_name: "prontera", x: 100, y: 100)
    |> PlayerState.to_combatant()
  end
end
