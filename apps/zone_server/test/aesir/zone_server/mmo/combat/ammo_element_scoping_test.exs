defmodule Aesir.ZoneServer.Mmo.Combat.AmmoElementScopingTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup
  import Aesir.ZoneServer.Factory

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats.EquipmentFold

  setup :set_mimic_from_context
  setup :setup_ets_tables

  test "ammo_element_scoping_test" do
    defender = build(:mob_combatant, def: 0, soft_def: 0, element: {:earth, 1})
    opts = [force_crit: true]

    for weapon <- [:dagger, :musical, :whip, :fist] do
      attacker = attacker(weapon)
      assert attacker.weapon.element == :neutral
      assert attacker.arrow_element == :fire

      assert {:ok, ordinary} = DamageCalculator.calculate_damage(attacker, defender, opts)

      assert {:ok, neutral} =
               DamageCalculator.calculate_damage(attacker, defender, opts ++ [element: :neutral])

      assert ordinary.damage == neutral.damage

      skill_opts = opts ++ [skill_id: 46]

      assert {:ok, arrow_skill} =
               DamageCalculator.calculate_damage(attacker, defender, skill_opts)

      assert {:ok, fire} =
               DamageCalculator.calculate_damage(
                 attacker,
                 defender,
                 skill_opts ++ [element: :fire]
               )

      assert {:ok, neutral_skill} =
               DamageCalculator.calculate_damage(
                 attacker,
                 defender,
                 skill_opts ++ [element: :neutral]
               )

      assert arrow_skill.damage == fire.damage
      assert arrow_skill.damage > neutral_skill.damage
    end

    for weapon <- [:bow, :revolver, :rifle, :gatling, :shotgun, :grenade] do
      assert attacker(weapon).weapon.element == :fire
    end
  end

  test "an endow overrides the arrow element, and an explicit skill element overrides both" do
    attacker = attacker(:dagger)
    defender = build(:mob_combatant, def: 0, soft_def: 0, element: {:water, 1})
    opts = [force_crit: true, skill_id: 46]
    assert {:ok, fire} = DamageCalculator.calculate_damage(attacker, defender, opts)

    stub(ModifierCalculator, :get_battle_modifiers, fn
      :player, 7_003 -> %{attack_element: :wind}
      _type, _id -> %{}
    end)

    assert {:ok, endowed} = DamageCalculator.calculate_damage(attacker, defender, opts)

    assert {:ok, wind} =
             DamageCalculator.calculate_damage(attacker, defender, opts ++ [element: :wind])

    assert endowed.damage == wind.damage
    assert endowed.damage > fire.damage

    assert {:ok, forced} =
             DamageCalculator.calculate_damage(attacker, defender, opts ++ [element: :fire])

    assert forced.damage == fire.damage
  end

  defp attacker(weapon) do
    definitions = %{
      90_001 => %ItemDefinition{
        id: 90_001,
        aegis_name: "Weapon",
        name: "Weapon",
        type: :weapon,
        subtype: weapon,
        attack: 100,
        weapon_level: 1
      },
      90_002 => %ItemDefinition{
        id: 90_002,
        aegis_name: "FireKunai",
        name: "Fire Kunai",
        type: :ammo,
        subtype: :kunai,
        attack_element: :fire,
        on_equip: [{:set, :atk_ele, :fire}]
      }
    }

    stub(ItemManagement, :get_item_by_id, &Map.fetch(definitions, &1))

    state =
      PlayerState.new(
        Aesir.Factory.build(:character,
          id: 7_003,
          account_id: 7_003,
          name: "Ammo",
          last_map: "prontera",
          class: 0,
          sex: "M"
        )
      )

    worn = [
      %InventoryItem{nameid: 90_001, equip: 2, identify: 1},
      %InventoryItem{nameid: 90_002, equip: 32_768, identify: 1}
    ]

    stats = EquipmentFold.apply_equipment_modifiers(state.stats, worn)
    combatant = state |> Map.put(:stats, stats) |> PlayerState.to_combatant()
    combat_stats = build(:player_combatant, flat_atk: 100).combat_stats
    %{combatant | combat_stats: combat_stats}
  end
end
