defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsSkintemperTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.ElementModifiers
  alias Aesir.ZoneServer.Mmo.Combat.SizeModifiers
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :set_mimic_from_context
  setup :verify_on_exit!

  setup do
    Mimic.copy(ElementModifiers)
    Mimic.copy(SizeModifiers)
    Mimic.copy(ModifierCalculator)
    stub(ElementModifiers, :get_modifier, fn _, _, _, _ -> 1.0 end)
    stub(SizeModifiers, :get_modifier, fn _, _, _ -> 100 end)
    stub(ModifierCalculator, :get_all_modifiers, fn _, _ -> %{} end)
    :ok
  end

  test "learned levels reduce fire damage by 5% and neutral damage by 1% each" do
    attacker = CombatTestHelper.create_mob_combatant()
    unlearned = combatant(0)

    assert {:ok, base_damage} =
             DamageCalculator.apply_modifier_pipeline(1000, attacker, unlearned, element: :fire)

    assert base_damage == 1000.0

    for level <- 1..5 do
      learned = combatant(level)

      assert {:ok, fire_damage} =
               DamageCalculator.apply_modifier_pipeline(1000, attacker, learned, element: :fire)

      assert fire_damage == base_damage * (100 - 5 * level) / 100

      assert {:ok, neutral_damage} =
               DamageCalculator.apply_modifier_pipeline(1000, attacker, learned,
                 element: :neutral
               )

      assert neutral_damage == base_damage * (100 - level) / 100

      for element <- [:holy, :water, :earth, :wind, :poison, :shadow, :ghost, :undead] do
        assert {:ok, 1000.0} =
                 DamageCalculator.apply_modifier_pipeline(1000, attacker, learned,
                   element: element
                 )
      end

      if level == 5 do
        assert {fire_damage, neutral_damage} == {750.0, 950.0}
      end
    end
  end

  defp combatant(level) do
    %Character{
      id: 109,
      account_id: 1,
      name: "Skin Temper",
      last_map: "prontera",
      last_x: 100,
      last_y: 100,
      class: 0,
      base_level: 1,
      job_level: 1,
      str: 1,
      agi: 1,
      vit: 1,
      int: 1,
      dex: 1,
      luk: 1,
      hp: 40,
      max_hp: 40,
      sp: 11,
      max_sp: 11
    }
    |> PlayerState.new()
    |> put_in([Access.key(:stats), Access.key(:progression), Access.key(:learned_skills)], %{
      109 => level
    })
    |> PlayerState.to_combatant()
  end
end
