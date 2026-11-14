defmodule Aesir.ZoneServer.Mmo.Skills.Gunslinger.MagicalbulletRenewalTermTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Combat.DamageInputs
  alias Aesir.ZoneServer.Mmo.Mechanics.PhysicalAttack.Renewal

  defp term(matk_min, matk_max, mdef, soft_mdef) do
    DamageInputs.magical_bullet_atk(
      %{matk_min: matk_min, matk_max: matk_max},
      %{mdef: mdef, soft_mdef: soft_mdef}
    )
  end

  describe "magical_bullet_atk/2" do
    test "rolls the half-open band minus hard and soft MDEF when matk_min exceeds it" do
      for _ <- 1..30, do: assert(term(100, 101, 30, 20) == 50)
    end

    test "uses matk_min when matk_min does not exceed the MDEF, clamped at 0" do
      for _ <- 1..30 do
        assert term(50, 200, 30, 20) == 0
        assert term(40, 200, 30, 20) == 0
      end
    end

    test "a degenerate band takes matk_min minus the MDEF" do
      assert term(80, 80, 30, 20) == 30
      assert term(80, 60, 30, 20) == 30
    end
  end

  test "the term is added after the card fix and before EDP" do
    components = %{
      status_atk: 0,
      weapon_atk: 100,
      flat_atk: 0,
      mastery_atk: 0,
      percent_atk: 0,
      hand: :right_hand,
      source: :weapon
    }

    context = %{attacker_cards: [100], defense_mode: :ignore, edp_level: 5}

    with_term =
      Renewal.calculate_components(components, Map.put(context, :post_card_weapon_atk, 50))

    without = Renewal.calculate_components(components, context)

    assert with_term - without == div(50 * 400, 100)
  end
end
