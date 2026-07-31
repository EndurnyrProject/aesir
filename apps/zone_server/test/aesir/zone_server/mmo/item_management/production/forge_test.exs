defmodule Aesir.ZoneServer.Mmo.ItemManagement.Production.ForgeTest do
  use Aesir.DataCase, async: true

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.ItemManagement.Production.Forge
  alias Aesir.ZoneServer.Mmo.ItemManagement.Production.ForgeStamp
  alias Aesir.ZoneServer.Mmo.ItemManagement.Production.Recipes.Recipe
  alias Aesir.ZoneServer.Unit.ItemContainer
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats

  setup do
    suffix = System.unique_integer([:positive])

    account =
      %Account{}
      |> Account.changeset(%{
        username: "forge#{suffix}",
        userid: "forge#{suffix}",
        user_pass: "password",
        email: "forge#{suffix}@test.com"
      })
      |> Repo.insert!()

    character =
      %Character{}
      |> Character.changeset(%{
        account_id: account.id,
        char_num: 0,
        name: "Forge#{suffix}",
        class: 10,
        base_level: 99,
        job_level: 70,
        str: 99,
        dex: 99,
        luk: 99
      })
      |> Repo.insert!()

    stats = Stats.from_character(character)
    learned = %{97 => 5, 99 => 3, 107 => 10}
    stats = put_in(stats.progression.learned_skills, learned)

    %{caster: %PlayerState{character_id: character.id, stats: stats}}
  end

  test "successful weapon forge consumes selected catalysts and stamps its creator", %{
    caster: caster
  } do
    :rand.seed(:exsss, {1, 1, 1})
    caster = %{caster | inventory: inventory([{998, 2}, {1000, 1}, {994, 1}, {995, 1}])}

    assert {:ok, forged} = Forge.run(caster, weapon_recipe(), [1000, 994, 995])

    output =
      Enum.find_value(forged.inventory, fn {_index, item} -> item.nameid == 1101 && item end)

    assert Map.take(output, [:card0, :card1, :card2, :card3]) ==
             ForgeStamp.encode(:fire, 1, caster.character_id)

    assert ItemContainer.held_amount(forged.inventory, 995) == 1
    assert forged.pending_production_result == %{success: true, item_id: 1101}
    assert output.identify == 1
  end

  test "failed roll consumes materials and catalysts and stages failure", %{caster: caster} do
    :rand.seed(:exsss, {1, 1, 1})
    low = caster |> put_in([Access.key!(:stats), Access.key!(:base_stats), Access.key!(:dex)], 0)
    low = low |> put_in([Access.key!(:stats), Access.key!(:base_stats), Access.key!(:luk)], 0)

    low =
      low |> put_in([Access.key!(:stats), Access.key!(:progression), Access.key!(:job_level)], 0)

    low = put_in(low.stats.progression.learned_skills, %{})
    low = %{low | inventory: inventory([{999, 1}, {1000, 3}, {994, 1}])}
    recipe = %{weapon_recipe() | item_level: 3, materials: [%{item_id: 999, amount: 1}]}

    assert {:ok, failed} = Forge.run(low, recipe, [1000, 1000, 1000])
    assert ItemContainer.held_amount(failed.inventory, 999) == 0
    assert ItemContainer.held_amount(failed.inventory, 1000) == 0
    assert ItemContainer.held_amount(failed.inventory, 994) == 1
    assert failed.pending_production_result == %{success: false, item_id: 1101}
    assert length(failed.pending_inventory_persist) == 2
  end

  test "full inventory and stale materials are rejected before consumption", %{caster: caster} do
    material = item(998, 2)

    full =
      1..99
      |> Map.new(fn index -> {index, %{item(501 + index, 1) | equip: 1}} end)
      |> Map.put(0, material)

    assert {:error, :inventory_full} = Forge.run(%{caster | inventory: full}, weapon_recipe(), [])
    assert full[0].amount == 2

    assert {:error, :no_materials} = Forge.run(%{caster | inventory: %{}}, weapon_recipe(), [])
  end

  test "possession-only materials remain held and a forge without a stone is neutral", %{
    caster: caster
  } do
    :rand.seed(:exsss, {1, 1, 1})

    recipe = %{
      weapon_recipe()
      | materials: [%{item_id: 998, amount: 2}, %{item_id: 986, amount: 0}]
    }

    assert {:ok, forged} =
             Forge.run(%{caster | inventory: inventory([{998, 2}, {986, 1}])}, recipe, [])

    assert ItemContainer.held_amount(forged.inventory, 986) == 1

    output =
      Enum.find_value(forged.inventory, fn {_index, item} -> item.nameid == 1101 && item end)

    assert {:ok, %{element: :neutral}} = ForgeStamp.decode(output)
    assert forged.pending_production_result.success

    assert {:error, :no_materials} =
             Forge.run(%{caster | inventory: inventory([{998, 2}])}, recipe, [])
  end

  defp weapon_recipe do
    %Recipe{
      id: 0,
      product_id: 1101,
      item_level: 1,
      skill_id: 99,
      skill_level: 1,
      materials: [%{item_id: 998, amount: 2}]
    }
  end

  defp inventory(entries) do
    entries
    |> Enum.with_index()
    |> Map.new(fn {{id, amount}, index} -> {index, item(id, amount)} end)
  end

  defp item(id, amount), do: %InventoryItem{nameid: id, amount: amount, identify: 1}
end
