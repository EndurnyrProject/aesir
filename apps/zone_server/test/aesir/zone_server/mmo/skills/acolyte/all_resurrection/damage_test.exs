defmodule Aesir.ZoneServer.Mmo.Skills.Acolyte.AllResurrection.DamageTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skills.Acolyte.AllResurrection.Damage

  @score_inputs %{
    level: 4,
    luk: 50,
    int: 60,
    base_level: 90,
    target_hp: 500,
    target_max_hp: 1_000
  }

  describe "instant_kill_score/2" do
    test "renewal weighs the skill level lightly and the HP gap heavily" do
      # 10*4 + 50 + 60 + 90 + 300 - 300*500/1000 = 40 + 200 + 300 - 150 = 390
      assert Damage.instant_kill_score(:renewal, @score_inputs) == 390
    end

    test "pre-renewal doubles the level term and halves the HP-gap span" do
      # 20*4 + 50 + 60 + 90 + 200 - 200*500/1000 = 80 + 200 + 200 - 100 = 380
      assert Damage.instant_kill_score(:pre_renewal, @score_inputs) == 380
    end

    test "both modes cap the score at 700" do
      inputs = %{@score_inputs | luk: 400, int: 400, base_level: 300}

      assert Damage.instant_kill_score(:renewal, inputs) == 700
      assert Damage.instant_kill_score(:pre_renewal, inputs) == 700
    end

    test "a full-health target loses the whole HP-gap term" do
      inputs = %{@score_inputs | target_hp: 1_000}

      assert Damage.instant_kill_score(:renewal, inputs) == 240
      assert Damage.instant_kill_score(:pre_renewal, inputs) == 280
    end
  end

  describe "undead_hit/2" do
    test "renewal scales the caster's magic attack by the skill level" do
      assert Damage.undead_hit(:renewal, %{level: 3, base_level: 90, int: 60}) ==
               [skill_ratio: 3]
    end

    test "pre-renewal deals a flat amount that ignores the caster's magic attack" do
      # 90 + 60 + 3 * 10 = 180
      assert Damage.undead_hit(:pre_renewal, %{level: 3, base_level: 90, int: 60}) ==
               [skill_ratio: 0, bonus_matk: 180]
    end
  end
end
