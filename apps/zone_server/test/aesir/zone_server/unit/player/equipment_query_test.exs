defmodule Aesir.ZoneServer.Unit.Player.EquipmentQueryTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Transpiler
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.EquipmentFold
  alias Aesir.ZoneServer.Unit.Player.Stats.Modifiers
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.Stats.BaseStats

  @provider 9_910_001
  @sword 9_910_002
  @garment 9_910_003
  @card 9_910_004

  setup :set_mimic_private
  setup :verify_on_exit!

  setup do
    {:ok, provider_program} =
      Transpiler.transpile_equip("""
      bonus bStr,getequiprefinerycnt(EQI_HAND_R);
      bonus bDex,getequiprefinerycnt(EQI_GARMENT);
      if (getiteminfo(getequipid(EQI_HAND_R),ITEMINFO_VIEW) == W_1HSWORD)
        bonus bHit,5;
      """)

    {:ok, card_program} =
      Transpiler.transpile_equip("""
      if (getiteminfo(getequipid(EQI_HAND_R),ITEMINFO_VIEW) == W_1HSWORD)
        bonus bCritical,5;
      """)

    definitions = %{
      @provider => definition(@provider, :armor, on_equip: provider_program),
      @sword =>
        definition(@sword, :weapon, subtype: :one_handed_sword, weapon_level: 1, slots: 1),
      @garment => definition(@garment, :armor),
      @card => definition(@card, :card, on_equip: card_program)
    }

    stub(ItemManagement, :get_item_by_id, fn id ->
      case Map.fetch(definitions, id) do
        {:ok, definition} -> {:ok, definition}
        :error -> {:error, :item_not_found}
      end
    end)

    :ok
  end

  test "slot reads use the queried instance and refresh after refine and unequip" do
    provider = worn(@provider, 256, 9)
    sword = worn(@sword, 2, 7)
    garment = worn(@garment, 4, 3)

    stats = EquipmentFold.apply_equipment_modifiers(stats(), [provider, sword, garment])
    assert Map.take(stats.modifiers.equipment, [:str, :dex, :hit]) == %{str: 7, dex: 3, hit: 5}

    stats =
      EquipmentFold.apply_equipment_modifiers(stats, [provider, %{sword | refine: 4}, garment])

    assert stats.modifiers.equipment.str == 4
    assert stats.modifiers.equipment.dex == 3

    stats = EquipmentFold.apply_equipment_modifiers(stats, [provider, garment])
    assert stats.modifiers.equipment.str == 0
    assert stats.modifiers.equipment.dex == 3
    assert Map.get(stats.modifiers.equipment, :hit, 0) == 0
  end

  test "card queries see a two-handed weapon in the explicit right-hand slot" do
    sword = %{worn(@sword, 34, 5) | card0: @card}
    stats = EquipmentFold.apply_equipment_modifiers(stats(), [sword])
    assert stats.modifiers.equipment.critical == 5
  end

  defp stats do
    %Stats{
      base_stats: %BaseStats{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
      progression: %PlayerProgression{job_id: 0},
      modifiers: %Modifiers{equipment: %{}, status_effects: %{}, job_bonuses: %{}}
    }
  end

  defp definition(id, type, attrs \\ []) do
    struct!(
      ItemDefinition,
      [id: id, aegis_name: "Query_#{id}", name: "Query #{id}", type: type] ++ attrs
    )
  end

  defp worn(id, position, refine) do
    %InventoryItem{id: id, nameid: id, amount: 1, identify: 1, equip: position, refine: refine}
  end
end
