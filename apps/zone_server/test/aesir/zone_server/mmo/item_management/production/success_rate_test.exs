defmodule Aesir.ZoneServer.Mmo.ItemManagement.Production.SuccessRateTest do
  use ExUnit.Case, async: false
  use Mimic

  alias Aesir.ZoneServer.Mmo.ItemManagement.Production.SuccessRate
  alias Aesir.ZoneServer.Mmo.Skill.Catalog

  setup :set_mimic_private
  setup :verify_on_exit!

  describe "weapon/1" do
    test "includes the shared base and each tier bonus" do
      params = weapon_params()

      assert SuccessRate.weapon(%{params | tier: 1}) == 5200
      assert SuccessRate.weapon(%{params | tier: 2}) == 3200
      assert SuccessRate.weapon(%{params | tier: 3}) == 2200
    end

    test "applies each shared base coefficient independently" do
      params = %{
        weapon_params()
        | job_level: 0,
          dex: 0,
          luk: 0,
          random_term: 0,
          tier: 3
      }

      assert SuccessRate.weapon(params) == 1000
      assert SuccessRate.weapon(%{params | job_level: 1}) == 1020
      assert SuccessRate.weapon(%{params | dex: 1}) == 1010
      assert SuccessRate.weapon(%{params | luk: 1}) == 1010
      assert SuccessRate.weapon(%{params | random_term: 10}) == 1010
    end

    test "adds 500 per family skill level" do
      params = weapon_params()

      assert Enum.map(0..3, &SuccessRate.weapon(%{params | family_skill_level: &1})) ==
               [5200, 5700, 6200, 6700]
    end

    test "adds 100 per Weapon Research level" do
      params = weapon_params()

      assert SuccessRate.weapon(%{params | weapon_research_level: 0}) == 5200
      assert SuccessRate.weapon(%{params | weapon_research_level: 1}) == 5300
      assert SuccessRate.weapon(%{params | weapon_research_level: 10}) == 6200
    end

    test "adds Oridecon Research only for tier 3" do
      params = weapon_params()

      for tier <- [1, 2] do
        without_research = SuccessRate.weapon(%{params | tier: tier, oridecon_research_level: 0})
        with_research = SuccessRate.weapon(%{params | tier: tier, oridecon_research_level: 5})

        assert with_research == without_research
      end

      assert SuccessRate.weapon(%{params | tier: 3, oridecon_research_level: 0}) == 2200
      assert SuccessRate.weapon(%{params | tier: 3, oridecon_research_level: 5}) == 2700
    end

    test "subtracts 1500 per Star Crumb for counts zero through three" do
      params = weapon_params()

      assert Enum.map(0..3, &SuccessRate.weapon(%{params | crumb_count: &1})) ==
               [5200, 3700, 2200, 700]
    end

    test "subtracts 2500 when an elemental stone is used" do
      params = weapon_params()

      assert SuccessRate.weapon(%{params | elemental_stone?: false}) == 5200
      assert SuccessRate.weapon(%{params | elemental_stone?: true}) == 2700
    end

    test "adds each anvil grade bonus" do
      params = weapon_params()

      assert Enum.map([0, 250, 500, 1000], &SuccessRate.weapon(%{params | anvil_bonus: &1})) ==
               [5200, 5450, 5700, 6200]
    end

    test "clamps a high chance to 10_000" do
      params = %{
        weapon_params()
        | job_level: 70,
          dex: 200,
          luk: 200,
          random_term: 1000,
          family_skill_level: 3,
          weapon_research_level: 10,
          anvil_bonus: 1000
      }

      assert SuccessRate.weapon(params) == 10_000
    end

    test "clamps a heavily penalised chance to 1" do
      params = %{
        weapon_params()
        | job_level: 0,
          dex: 0,
          luk: 0,
          random_term: 0,
          tier: 3,
          crumb_count: 3,
          elemental_stone?: true
      }

      assert SuccessRate.weapon(params) == 1
    end

    test "uses the caller-supplied random term without rolling" do
      params = weapon_params()

      assert SuccessRate.weapon(%{params | random_term: 10}) == 4710
      assert SuccessRate.weapon(%{params | random_term: 1000}) == 5700
      assert SuccessRate.weapon(%{params | random_term: 10}) == 4710
    end
  end

  describe "mineral/2" do
    test "uses each mineral bonus without the weapon production multiplier" do
      params = mineral_params()

      assert SuccessRate.mineral(:iron, params) == 6200
      assert SuccessRate.mineral(:steel, params) == 5200
      assert SuccessRate.mineral(:elemental_stone, params) == 3200
    end

    test "Star Crumb is guaranteed before any arithmetic" do
      assert SuccessRate.mineral(:star_crumb, %{not_formula_inputs: :deliberately}) == 10_000
    end
  end

  describe "pharmacy/2" do
    test "includes the cast level, job level, integer Intelligence, DEX, and LUK terms" do
      params = %{pharmacy_params() | skill_level: 1}

      assert SuccessRate.pharmacy(999, params) == 300
      assert SuccessRate.pharmacy(999, %{params | job_level: 1}) == 320
      assert SuccessRate.pharmacy(999, %{params | int: 1}) == 300
      assert SuccessRate.pharmacy(999, %{params | int: 2}) == 310
      assert SuccessRate.pharmacy(999, %{params | dex: 1}) == 310
      assert SuccessRate.pharmacy(999, %{params | luk: 1}) == 310
    end

    test "adds 50 per learned Learning Potion level" do
      stub(Catalog, :by_name, fn :am_learningpotion -> {:ok, %{id: 227}} end)

      assert SuccessRate.pharmacy(999, %{pharmacy_params() | learned_skills: %{227 => 3}}) ==
               150
    end

    test "treats unavailable Learning Potion as level zero" do
      stub(Catalog, :by_name, fn :am_learningpotion -> :error end)

      params = %{pharmacy_params() | skill_level: 1, learned_skills: %{227 => 10}}

      assert SuccessRate.pharmacy(999, params) == 300
    end

    test "uses the supplied product-class roll at each class boundary" do
      params = %{pharmacy_params() | skill_level: 4}

      assert SuccessRate.pharmacy(501, %{params | random_term: 2010}) == 3210
      assert SuccessRate.pharmacy(504, %{params | random_term: 3000}) == 4200
      assert SuccessRate.pharmacy(970, %{params | random_term: 1010}) == 2210
      assert SuccessRate.pharmacy(970, %{params | random_term: 2000}) == 3200
      assert SuccessRate.pharmacy(7135, %{params | random_term: 10}) == 1210
      assert SuccessRate.pharmacy(7138, %{params | random_term: 1000}) == 2200
      assert SuccessRate.pharmacy(547, %{params | random_term: -10}) == 1190
      assert SuccessRate.pharmacy(547, %{params | random_term: -500}) == 700
      assert SuccessRate.pharmacy(12_428, %{params | random_term: -10}) == 1190
      assert SuccessRate.pharmacy(7139, %{params | random_term: -1000}) == 200
      assert SuccessRate.pharmacy(999, %{params | random_term: 3000}) == 1200
    end

    test "clamps pharmacy chance at both bounds" do
      assert SuccessRate.pharmacy(7139, %{pharmacy_params() | skill_level: 1, random_term: -1000}) ==
               1

      params = %{
        pharmacy_params()
        | job_level: 70,
          int: 100,
          dex: 200,
          luk: 100,
          skill_level: 10,
          random_term: 3000
      }

      assert SuccessRate.pharmacy(501, params) == 10_000
    end
  end

  defp weapon_params do
    %{
      job_level: 10,
      dex: 20,
      luk: 30,
      random_term: 500,
      tier: 1,
      family_skill_level: 0,
      weapon_research_level: 0,
      oridecon_research_level: 0,
      crumb_count: 0,
      elemental_stone?: false,
      anvil_bonus: 0
    }
  end

  defp mineral_params do
    %{
      job_level: 10,
      dex: 20,
      luk: 30,
      random_term: 500,
      skill_level: 2
    }
  end

  defp pharmacy_params do
    %{
      job_level: 0,
      int: 0,
      dex: 0,
      luk: 0,
      skill_level: 0,
      learned_skills: %{},
      random_term: 0
    }
  end
end
