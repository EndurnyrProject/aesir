defmodule Aesir.ZoneServer.Mmo.Combat.RaceModifiersTest do
  use ExUnit.Case, async: false

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat.RaceModifiers

  setup do
    game_mode = {
      Application.fetch_env(:commons, :game_mode),
      :persistent_term.get(GameMode, nil)
    }

    on_exit(fn -> restore_game_mode(game_mode) end)

    :ok
  end

  describe "demon_bane_atk/2" do
    test "adds level * (base_level/20 + 3) ATK vs undead and demon" do
      attacker = %{demon_bane_level: 5, progression: %{base_level: 40}}
      # 5 * (40/20 + 3) = 5 * 5 = 25
      assert RaceModifiers.demon_bane_atk(attacker, :undead) == 25
      assert RaceModifiers.demon_bane_atk(attacker, :demon) == 25
    end

    test "is zero vs non-undead/demon races" do
      attacker = %{demon_bane_level: 5, progression: %{base_level: 40}}
      assert RaceModifiers.demon_bane_atk(attacker, :brute) == 0
      assert RaceModifiers.demon_bane_atk(attacker, :demi_human) == 0
    end

    test "is zero when the attacker has no Demon Bane level" do
      attacker = %{demon_bane_level: 0, progression: %{base_level: 40}}
      assert RaceModifiers.demon_bane_atk(attacker, :undead) == 0
    end

    test "truncates the float product (level 10, base 60 -> 60)" do
      attacker = %{demon_bane_level: 10, progression: %{base_level: 60}}
      # 10 * (60/20 + 3) = 10 * 6 = 60
      assert RaceModifiers.demon_bane_atk(attacker, :demon) == 60
    end

    test "uses float division across the whole expression, not a floored base_level/20" do
      attacker = %{demon_bane_level: 5, progression: %{base_level: 45}}
      # rAthena: trunc(5 * (45/20.0 + 3.0)) = trunc(5 * 5.25) = trunc(26.25) = 26
      # a floored base_level/20 would give 5 * (2 + 3) = 25
      assert RaceModifiers.demon_bane_atk(attacker, :undead) == 26
    end
  end

  describe "beast_bane_atk/2" do
    test "adds four ATK per level against Brute and Insect targets" do
      attacker = %{beast_bane_level: 5}

      assert RaceModifiers.beast_bane_atk(attacker, :brute) == 20
      assert RaceModifiers.beast_bane_atk(attacker, :insect) == 20
    end

    test "is zero against every other supported race and when unlearned" do
      attacker = %{beast_bane_level: 5}

      for race <- [
            :formless,
            :undead,
            :plant,
            :fish,
            :demon,
            :demi_human,
            :player_human,
            :player_doram,
            :angel,
            :dragon,
            :boss
          ] do
        assert RaceModifiers.beast_bane_atk(attacker, race) == 0
      end

      assert RaceModifiers.beast_bane_atk(%{beast_bane_level: 0}, :brute) == 0
    end
  end

  describe "divine_protection_def/2" do
    test "adds (base_level/25 + 3) * level + 0.5 soft-DEF vs undead and demon attackers" do
      defender = %{divine_protection_level: 5, progression: %{base_level: 50}}
      # (50/25 + 3) * 5 + 0.5 = 5 * 5 + 0.5 = 25.5 -> 25
      assert RaceModifiers.divine_protection_def(defender, :undead) == 25
      assert RaceModifiers.divine_protection_def(defender, :demon) == 25
    end

    test "is zero vs non-undead/demon attackers" do
      defender = %{divine_protection_level: 5, progression: %{base_level: 50}}
      assert RaceModifiers.divine_protection_def(defender, :brute) == 0
      assert RaceModifiers.divine_protection_def(defender, :demi_human) == 0
    end

    test "is zero when the defender has no Divine Protection level" do
      defender = %{divine_protection_level: 0, progression: %{base_level: 50}}
      assert RaceModifiers.divine_protection_def(defender, :undead) == 0
    end

    test "truncates with the +0.5 round (level 10, base 75 -> 60)" do
      defender = %{divine_protection_level: 10, progression: %{base_level: 75}}
      # (75/25 + 3) * 10 + 0.5 = 6 * 10 + 0.5 = 60.5 -> 60
      assert RaceModifiers.divine_protection_def(defender, :demon) == 60
    end

    test "uses float division across the whole expression, not a floored base_level/25" do
      defender = %{divine_protection_level: 5, progression: %{base_level: 60}}
      # rAthena: trunc((60/25.0 + 3.0) * 5 + 0.5) = trunc(5.4 * 5 + 0.5) = trunc(27.5) = 27
      # a floored base_level/25 would give (2 + 3) * 5 + 0.5 = 25.5 -> 25
      assert RaceModifiers.divine_protection_def(defender, :undead) == 27
    end
  end

  describe "dragonology_atk_rate/2" do
    test "is level * 4 vs Dragon race" do
      attacker = %{dragonology_level: 5}
      assert RaceModifiers.dragonology_atk_rate(attacker, :dragon) == 20
      assert RaceModifiers.dragonology_atk_rate(%{dragonology_level: 1}, :dragon) == 4
    end

    test "is zero vs non-Dragon races" do
      attacker = %{dragonology_level: 5}
      assert RaceModifiers.dragonology_atk_rate(attacker, :brute) == 0
      assert RaceModifiers.dragonology_atk_rate(attacker, :demi_human) == 0
    end

    test "is zero when the attacker has no Dragonology level" do
      assert RaceModifiers.dragonology_atk_rate(%{dragonology_level: 0}, :dragon) == 0
    end
  end

  describe "dragonology_matk_rate/2" do
    test "is level * 2 vs Dragon race" do
      assert RaceModifiers.dragonology_matk_rate(%{dragonology_level: 5}, :dragon) == 10
      assert RaceModifiers.dragonology_matk_rate(%{dragonology_level: 1}, :dragon) == 2
    end

    test "is zero vs non-Dragon races" do
      assert RaceModifiers.dragonology_matk_rate(%{dragonology_level: 5}, :brute) == 0
    end

    test "is zero when the attacker has no Dragonology level" do
      assert RaceModifiers.dragonology_matk_rate(%{dragonology_level: 0}, :dragon) == 0
    end
  end

  describe "player_race/0" do
    test "returns the race for the active game mode" do
      set_game_mode(:renewal)
      assert RaceModifiers.player_race() == :player_human

      set_game_mode(:pre_renewal)
      assert RaceModifiers.player_race() == :demi_human
    end
  end

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

  describe "dragonology_resist_rate/2" do
    test "is level * 4 vs a Dragon-race attacker" do
      assert RaceModifiers.dragonology_resist_rate(%{dragonology_level: 5}, :dragon) == 20
      assert RaceModifiers.dragonology_resist_rate(%{dragonology_level: 1}, :dragon) == 4
    end

    test "is zero vs a non-Dragon attacker" do
      assert RaceModifiers.dragonology_resist_rate(%{dragonology_level: 5}, :brute) == 0
    end

    test "is zero when the defender has no Dragonology level" do
      assert RaceModifiers.dragonology_resist_rate(%{dragonology_level: 0}, :dragon) == 0
    end
  end
end
