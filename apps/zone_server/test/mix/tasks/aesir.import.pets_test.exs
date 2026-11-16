defmodule Mix.Tasks.Aesir.Import.PetsTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.Aesir.Import.Pets

  @resolvers %{mob: %{"poring" => 1002}, item: %{"poring_egg" => 9001}}

  test "an absent field takes the parser default" do
    row =
      Pets.to_row(
        %{
          "Mob" => "PORING",
          "EggItem" => "Poring_Egg",
          "Fullness" => 3,
          "IntimacyFed" => 40,
          "CaptureRate" => 2000
        },
        @resolvers
      )

    assert row == %{
             "mob_id" => 1002,
             "tame_item_id" => 0,
             "egg_item_id" => 9001,
             "equip_item_id" => 0,
             "food_item_id" => 0,
             "fullness" => 3,
             "hungry_delay_ms" => 60_000,
             "hunger_increase" => 20,
             "intimacy_start" => 250,
             "intimacy_fed" => 40,
             "intimacy_overfed" => -100,
             "intimacy_hungry" => -5,
             "intimacy_owner_die" => -20,
             "capture_rate" => 2000,
             "special_performance" => true,
             "attack_rate" => 10_001,
             "retaliate_rate" => 10_001,
             "change_target_rate" => 10_001,
             "allow_auto_feed" => false,
             "bonus_program" => nil,
             "support_ops" => [],
             "evolution" => []
           }
  end

  test "fullness, intimacy start and rates are capped and the delay is stored in ms" do
    row =
      Pets.to_row(
        %{
          "Mob" => "poring",
          "EggItem" => "POring_Egg",
          "Fullness" => 150,
          "CaptureRate" => 20_000,
          "IntimacyStart" => 12_000,
          "HungryDelay" => 30,
          "AttackRate" => 15_000,
          "RetaliateRate" => 500,
          "ChangeTargetRate" => 10_000
        },
        @resolvers
      )

    assert %{
             "fullness" => 100,
             "capture_rate" => 10_000,
             "intimacy_start" => 10_000,
             "hungry_delay_ms" => 30_000,
             "attack_rate" => 10_000,
             "retaliate_rate" => 500,
             "change_target_rate" => 10_000
           } = row
  end

  test "hunger delay multiplication wraps at uint32" do
    row =
      Pets.to_row(
        %{
          "Mob" => "PORING",
          "EggItem" => "Poring_Egg",
          "Fullness" => 3,
          "CaptureRate" => 1,
          "HungryDelay" => 4_294_968
        },
        @resolvers
      )

    assert row["hungry_delay_ms"] == 704
  end

  test "parser numeric inputs wrap to their declared widths before caps" do
    row =
      Pets.to_row(
        %{
          "Mob" => "PORING",
          "EggItem" => "Poring_Egg",
          "Fullness" => 65_537,
          "CaptureRate" => 65_538,
          "IntimacyStart" => 4_294_967_297,
          "HungerIncrease" => 2_147_483_648,
          "IntimacyFed" => 4_294_967_297,
          "IntimacyOverfed" => 2_147_483_648,
          "IntimacyHungry" => 4_294_967_297,
          "IntimacyOwnerDie" => 2_147_483_648,
          "AttackRate" => 65_539,
          "RetaliateRate" => 65_540,
          "ChangeTargetRate" => 65_541,
          "Evolution" => [
            %{
              "Target" => "PORING",
              "ItemRequirements" => [%{"Item" => "Poring_Egg", "Amount" => 65_537}]
            }
          ]
        },
        @resolvers
      )

    assert %{
             "fullness" => 1,
             "capture_rate" => 2,
             "intimacy_start" => 1,
             "hunger_increase" => -2_147_483_648,
             "intimacy_fed" => 1,
             "intimacy_overfed" => -2_147_483_648,
             "intimacy_hungry" => 1,
             "intimacy_owner_die" => -2_147_483_648,
             "attack_rate" => 3,
             "retaliate_rate" => 4,
             "change_target_rate" => 5,
             "evolution" => [%{"requirements" => [%{"amount" => 1}]}]
           } = row
  end

  test "a row missing a mandatory field or naming an unknown item fails the import" do
    assert_raise Mix.Error, ~r/missing CaptureRate/, fn ->
      Pets.to_row(%{"Mob" => "PORING", "EggItem" => "Poring_Egg", "Fullness" => 3}, @resolvers)
    end

    assert_raise Mix.Error, ~r/unknown item Apple/, fn ->
      Pets.to_row(
        %{
          "Mob" => "PORING",
          "EggItem" => "Poring_Egg",
          "Fullness" => 3,
          "CaptureRate" => 1,
          "TameItem" => "Apple"
        },
        @resolvers
      )
    end
  end
end
