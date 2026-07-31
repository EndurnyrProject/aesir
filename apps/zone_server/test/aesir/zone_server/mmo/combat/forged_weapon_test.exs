defmodule Aesir.ZoneServer.Mmo.Combat.ForgedWeaponTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.ItemManagement.Production.ForgeStamp
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats

  setup :set_mimic_from_context
  setup :verify_on_exit!

  setup do
    Mimic.copy(ModifierCalculator)
    :ok
  end

  test "forged star damage stays constant while weapon variance changes" do
    forged = combatant(forged_weapon(1101, :neutral, 3))
    plain = combatant(weapon(1101))

    {plain_rolls, star_contributions} =
      Enum.unzip(
        for seed <- 1..20 do
          :rand.seed(:exsss, {seed, seed + 1, seed + 2})
          {:ok, plain_damage} = DamageCalculator.calculate_base_attack(plain)
          :rand.seed(:exsss, {seed, seed + 1, seed + 2})
          {:ok, forged_damage} = DamageCalculator.calculate_base_attack(forged)
          {plain_damage, forged_damage - plain_damage}
        end
      )

    assert length(Enum.uniq(plain_rolls)) > 1
    assert Enum.uniq(star_contributions) == [40]
  end

  test "three star crumbs contribute 40 mastery attack" do
    combatant = combatant(forged_weapon(1101, :neutral, 3))

    assert combatant.combat_stats.passive_atk == 40
  end

  test "forged element applies when the weapon has no inherent element" do
    assert combatant(forged_weapon(1101, :fire, 0)).weapon.element == :fire
  end

  test "forged element does not override the weapon's inherent element" do
    assert combatant(forged_weapon(1133, :water, 0)).weapon.element == :fire
  end

  test "equipment script element overrides the forged element" do
    assert combatant(forged_weapon(1101, :fire, 0), %{atk_ele: :wind}).weapon.element == :wind
  end

  test "active endow overrides a forged element" do
    attacker = combatant(forged_weapon(1101, :fire, 0))
    defender = CombatTestHelper.create_mob_combatant(element: {:earth, 1})

    stub(ModifierCalculator, :get_all_modifiers, fn _, _ -> %{} end)
    :rand.seed(:exsss, {1, 2, 3})

    assert {:ok, %{damage: forged_damage}} =
             DamageCalculator.calculate_damage(attacker, defender, skip_crit: true)

    stub(ModifierCalculator, :get_all_modifiers, fn _, _ -> %{attack_element: :water} end)
    :rand.seed(:exsss, {1, 2, 3})

    assert {:ok, %{damage: endow_damage}} =
             DamageCalculator.calculate_damage(attacker, defender, skip_crit: true)

    assert endow_damage < forged_damage
  end

  test "corrupt forged cards are treated as unforged" do
    corrupt = %{weapon(1101) | card0: 255, card1: 65_535, card2: 0, card3: 0}
    combatant = combatant(corrupt)

    assert combatant.combat_stats.passive_atk == 0
    assert combatant.weapon.element == :neutral
  end

  defp combatant(item, equipment_modifiers \\ %{}) do
    character = %Character{
      id: 91_013,
      account_id: 1,
      name: "Forger",
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

    state = PlayerState.new(character)

    stats =
      state.stats
      |> Stats.apply_equipment_modifiers([item])
      |> update_in(
        [Access.key(:modifiers), Access.key(:equipment)],
        &Map.merge(&1, equipment_modifiers)
      )
      |> Stats.calculate_combat_stats()

    PlayerState.to_combatant(%{state | stats: stats})
  end

  defp forged_weapon(nameid, element, crumbs) do
    Map.merge(weapon(nameid), ForgeStamp.encode(element, crumbs, 91_013))
  end

  defp weapon(nameid) do
    %InventoryItem{nameid: nameid, amount: 1, equip: 2, identify: 1}
  end
end
