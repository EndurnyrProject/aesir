defmodule Aesir.ZoneServer.Mmo.Combat.EquipComaTest do
  use ExUnit.Case, async: false

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.Combat.EquipComa
  alias Aesir.ZoneServer.PlayerStateFixture
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup do
    game_mode = {
      Application.fetch_env(:commons, :game_mode),
      :persistent_term.get(GameMode, nil)
    }

    on_exit(fn -> restore_game_mode(game_mode) end)

    :ok
  end

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

  test "matches player races from the active game mode" do
    player =
      %PlayerState{
        character_id: 2_003,
        map_name: "prontera",
        x: 100,
        y: 100,
        stats: %{}
      }
      |> PlayerStateFixture.build()

    attacker = CombatTestHelper.create_player_combatant()
    no_roll = [roll: fn _rate -> flunk("unexpected roll") end]

    set_game_mode(:renewal)
    renewal_target = PlayerState.to_combatant(player)
    renewal_attacker = with_modifiers(attacker, %{{:coma_race, :player_human} => 10_000})
    assert EquipComa.trigger?(renewal_attacker, renewal_target, no_roll)

    set_game_mode(:pre_renewal)
    pre_renewal_target = PlayerState.to_combatant(player)
    refute EquipComa.trigger?(renewal_attacker, pre_renewal_target, no_roll)

    pre_renewal_attacker = with_modifiers(attacker, %{{:coma_race, :demi_human} => 10_000})
    assert EquipComa.trigger?(pre_renewal_attacker, pre_renewal_target, no_roll)
  end

  defp with_modifiers(combatant, modifiers), do: %{combatant | equip_modifiers: modifiers}

  defp set_game_mode(mode) do
    Application.put_env(:commons, :game_mode, mode)
    :persistent_term.erase(GameMode)
  end

  defp restore_game_mode({configured_mode, cached_mode}) do
    case configured_mode do
      {:ok, mode} -> Application.put_env(:commons, :game_mode, mode)
      :error -> Application.delete_env(:commons, :game_mode)
    end

    if cached_mode do
      :persistent_term.put(GameMode, cached_mode)
    else
      :persistent_term.erase(GameMode)
    end
  end
end
