defmodule Aesir.ZoneServer.Mmo.ItemManagement.Production.ForgeTest do
  use Aesir.DataCase, async: false

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemCraft
  alias Aesir.ZoneServer.Mmo.ItemManagement.Production.Forge
  alias Aesir.ZoneServer.Mmo.ItemManagement.Production.Recipes.Recipe
  alias Aesir.ZoneServer.Unit.ItemContainer
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats

  @cdp_materials [937, 952, 939, 7033, 972, 657, 713]

  setup do
    previous_rng = Application.get_env(:zone_server, :forge_rng)

    on_exit(fn ->
      if previous_rng,
        do: Application.put_env(:zone_server, :forge_rng, previous_rng),
        else: Application.delete_env(:zone_server, :forge_rng)
    end)

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

    assert ItemCraft.from_map(output.craft) ==
             {:ok, ItemCraft.forged(:fire, 1, caster.character_id)}

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

  test "pharmacy ignores forge catalysts and signs its product", %{caster: caster} do
    Application.put_env(:zone_server, :forge_rng, fn _upper -> 1 end)

    caster =
      caster
      |> pharmacy_caster(10)
      |> Map.put(:inventory, inventory([{1002, 1}, {1000, 1}, {994, 1}]))

    assert {:ok, brewed} = Forge.run(caster, pharmacy_recipe(), [1000, 994])
    assert ItemContainer.held_amount(brewed.inventory, 1002) == 0
    assert ItemContainer.held_amount(brewed.inventory, 1000) == 1
    assert ItemContainer.held_amount(brewed.inventory, 994) == 1

    output =
      Enum.find_value(brewed.inventory, fn {_index, item} -> item.nameid == 501 && item end)

    assert output.amount == 1
    assert ItemCraft.from_map(output.craft) == {:ok, ItemCraft.signed(caster.character_id)}
    assert brewed.pending_production_result == %{success: true, item_id: 501}
  end

  test "pharmacy consumes signed materials across makers and keeps product identities separate",
       %{caster: caster} do
    Application.put_env(:zone_server, :forge_rng, fn _upper -> 1 end)
    own = ItemCraft.signed(caster.character_id) |> ItemCraft.to_map()
    other = ItemCraft.signed(caster.character_id + 1) |> ItemCraft.to_map()

    caster =
      caster
      |> pharmacy_caster(10)
      |> Map.put(:inventory, %{
        0 => %{item(501, 1) | craft: own},
        1 => %{item(501, 2) | craft: other},
        2 => item(501, 4)
      })

    recipe = %{pharmacy_recipe() | materials: [%{item_id: 501, amount: 2}]}

    assert {:ok, brewed} = Forge.run(caster, recipe, [])
    assert ItemContainer.held_amount(brewed.inventory, 501) == 6
    assert Enum.any?(brewed.inventory, fn {_, item} -> item.craft == own and item.amount == 1 end)

    assert Enum.any?(brewed.inventory, fn {_, item} ->
             item.craft == other and item.amount == 1
           end)

    assert Enum.any?(brewed.inventory, fn {_, item} -> item.craft == nil and item.amount == 4 end)
  end

  describe "run_batch/4" do
    # Pharmacy 1, job 70 and 1 INT/DEX/LUK keep the chance near 3,700: a unit
    # roll of 1 succeeds and one of 10,000 fails.
    defp batch_caster(caster, held) do
      caster
      |> pharmacy_caster(1)
      |> put_in([Access.key!(:stats), Access.key!(:base_stats), Access.key!(:int)], 1)
      |> put_in([Access.key!(:stats), Access.key!(:base_stats), Access.key!(:dex)], 1)
      |> put_in([Access.key!(:stats), Access.key!(:base_stats), Access.key!(:luk)], 1)
      |> Map.put(:inventory, inventory([{1002, held}]))
    end

    defp batch_rolls(unit_rolls) do
      {:ok, agent} = Agent.start_link(fn -> {unit_rolls, 0} end)

      Application.put_env(:zone_server, :forge_rng, fn
        10_000 ->
          Agent.get_and_update(agent, fn {[roll | rest], terms} -> {roll, {rest, terms}} end)

        _upper ->
          Agent.update(agent, fn {rolls, terms} -> {rolls, terms + 1} end)
          1
      end)

      agent
    end

    test "rolls every unit against one chance and adds the successes as one stack", %{
      caster: caster
    } do
      agent = batch_rolls([1, 10_000, 1, 10_000])

      assert {:ok, made} = Forge.run_batch(batch_caster(caster, 4), pharmacy_recipe(), 4, 0)

      assert ItemContainer.held_amount(made.inventory, 501) == 2

      output =
        Enum.find_value(made.inventory, fn {_index, item} -> item.nameid == 501 && item end)

      assert ItemCraft.from_map(output.craft) == {:ok, ItemCraft.signed(caster.character_id)}
      assert ItemContainer.held_amount(made.inventory, 1002) == 0
      assert made.pending_production_result == %{success: true, item_id: 501}
      assert {[], 1} = Agent.get(agent, & &1)
    end

    test "a batch whose every unit fails adds nothing and still spends the materials", %{
      caster: caster
    } do
      batch_rolls([10_000, 10_000, 10_000])

      assert {:ok, failed} = Forge.run_batch(batch_caster(caster, 3), pharmacy_recipe(), 3, 0)

      assert ItemContainer.held_amount(failed.inventory, 501) == 0
      assert ItemContainer.held_amount(failed.inventory, 1002) == 0

      assert failed.pending_production_result == [
               %{success: true, item_id: 501},
               %{success: false, item_id: 501}
             ]
    end

    test "materials split over several stacks are spent across them", %{caster: caster} do
      batch_rolls([1, 1, 1])

      caster = %{
        batch_caster(caster, 0)
        | inventory: %{0 => item(1002, 1), 7 => item(1002, 2)}
      }

      assert {:ok, made} = Forge.run_batch(caster, pharmacy_recipe(), 3, 0)
      assert ItemContainer.held_amount(made.inventory, 1002) == 0
      assert ItemContainer.held_amount(made.inventory, 501) == 3
    end

    test "materials short of the whole batch produce nothing", %{caster: caster} do
      batch_rolls([])
      short = batch_caster(caster, 3)

      assert {:error, :no_materials} = Forge.run_batch(short, pharmacy_recipe(), 4, 0)
    end
  end

  test "failed pharmacy attempt burns its recipe materials", %{caster: caster} do
    Application.put_env(:zone_server, :forge_rng, fn
      991 -> 1
      10_000 -> 10_000
    end)

    caster =
      caster
      |> pharmacy_caster(1)
      |> put_in([Access.key!(:stats), Access.key!(:base_stats), Access.key!(:int)], 0)
      |> put_in([Access.key!(:stats), Access.key!(:base_stats), Access.key!(:dex)], 0)
      |> put_in([Access.key!(:stats), Access.key!(:base_stats), Access.key!(:luk)], 0)
      |> put_in([Access.key!(:stats), Access.key!(:progression), Access.key!(:job_level)], 0)
      |> Map.put(:inventory, inventory([{1002, 1}]))

    assert {:ok, failed} = Forge.run(caster, pharmacy_recipe(), [])
    assert ItemContainer.held_amount(failed.inventory, 1002) == 0
    assert ItemContainer.held_amount(failed.inventory, 501) == 0
    assert failed.pending_production_result == %{success: false, item_id: 501}
  end

  test "a full inventory spends the materials and reports the refused add", %{caster: caster} do
    Application.put_env(:zone_server, :forge_rng, fn _upper -> 1 end)
    material = item(998, 3)

    full =
      1..99
      |> Map.new(fn index -> {index, item(90_000 + index, 1)} end)
      |> Map.put(0, material)

    assert {:ok, staged} = Forge.run(%{caster | inventory: full}, weapon_recipe(), [])

    assert ItemContainer.held_amount(staged.inventory, 998) == 1
    assert staged.pending_item_add_failures == [:inventory_full]
    assert staged.pending_production_result == %{success: true, item_id: 1101}

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

    assert {:ok, %ItemCraft{kind: :forged, element: :neutral}} =
             ItemCraft.from_map(output.craft)

    assert forged.pending_production_result.success

    assert {:error, :no_materials} =
             Forge.run(%{caster | inventory: inventory([{998, 2}])}, recipe, [])
  end

  test "a selected catalyst the player does not hold is skipped", %{caster: caster} do
    Application.put_env(:zone_server, :forge_rng, fn _upper -> 1 end)
    caster = %{caster | inventory: inventory([{998, 2}, {1000, 1}])}

    assert {:ok, forged} = Forge.run(caster, weapon_recipe(), [1000, 1000, 994])

    assert ItemContainer.held_amount(forged.inventory, 1000) == 0
    output = Enum.find_value(forged.inventory, fn {_i, item} -> item.nameid == 1101 && item end)

    assert {:ok, %ItemCraft{element: :neutral, star_crumbs: 1}} =
             ItemCraft.from_map(output.craft)
  end

  describe "success chance reads total stats" do
    # Each chance below is derived by hand from the reference formula with the
    # equipment bonus counted; the roll succeeds exactly up to the chance.
    test "weapon forging counts equipment DEX", %{caster: caster} do
      caster = controlled(caster, %{dex: 10, luk: 10}, %{dex: 40})
      caster = %{caster | inventory: inventory([{998, 2}])}

      # 20*70 + 10*50 + 10*10 + 10*1 + 4000 + 500*3 + 100*10 = 8510
      assert pinned_success?(caster, weapon_recipe(), 8510)
      refute pinned_success?(caster, weapon_recipe(), 8511)
    end

    test "pharmacy counts equipment INT, DEX and LUK", %{caster: caster} do
      caster =
        caster
        |> pharmacy_caster(10)
        |> controlled(%{int: 10, dex: 10, luk: 10}, %{int: 20, dex: 20, luk: 20})
        |> Map.put(:inventory, inventory([{1002, 1}]))

      # 300*10 + 20*70 + 10*div(30, 2) + 10*30 + 10*30 + 2010 = 7160
      assert pinned_success?(caster, pharmacy_recipe(), 7160)
      refute pinned_success?(caster, pharmacy_recipe(), 7161)
    end

    test "ore refining counts equipment DEX", %{caster: caster} do
      caster = controlled(caster, %{dex: 10, luk: 10}, %{dex: 20})
      caster = put_in(caster.stats.progression.learned_skills, %{94 => 5})
      caster = %{caster | inventory: inventory([{1002, 1}])}

      # 20*70 + 10*30 + 10*10 + 10*1 + 4000 + 500*5 = 8310
      assert pinned_success?(caster, iron_recipe(), 8310)
      refute pinned_success?(caster, iron_recipe(), 8311)
    end

    test "a baby class forges at 70 percent of the chance", %{caster: caster} do
      caster = controlled(caster, %{dex: 10, luk: 10}, %{dex: 40})
      caster = put_in(caster.stats.progression.job_id, 4033)
      caster = %{caster | inventory: inventory([{998, 2}])}

      # div(8510 * 70, 100) = 5957
      assert pinned_success?(caster, weapon_recipe(), 5957)
      refute pinned_success?(caster, weapon_recipe(), 5958)
    end
  end

  describe "Create Deadly Poison" do
    test "the chance counts equipment DEX and LUK", %{caster: caster} do
      caster = controlled(caster, %{dex: 10, luk: 10}, %{dex: 40, luk: 20})
      caster = %{caster | inventory: inventory(Enum.map(@cdp_materials, &{&1, 1}))}

      # 2000 + 40 * 50 + 20 * 30 = 4600
      assert pinned_skill_success?(caster, 4600)
      refute pinned_skill_success?(caster, 4601)
    end

    test "a chance above 10,000 always succeeds", %{caster: caster} do
      # 2000 + 40 * 200 + 20 * 50 = 11_000
      caster = controlled(caster, %{dex: 200, luk: 50}, %{})
      caster = %{caster | inventory: inventory(Enum.map(@cdp_materials, &{&1, 1}))}

      assert pinned_skill_success?(caster, 10_000)
    end

    test "a failure above 100,000 max HP takes 25 per hundred whole HP", %{caster: caster} do
      caster = controlled(caster, %{dex: 1, luk: 1}, %{})
      caster = put_in(caster.stats.derived_stats.max_hp, 100_050)
      caster = %{caster | inventory: inventory(Enum.map(@cdp_materials, &{&1, 1}))}
      Application.put_env(:zone_server, :forge_rng, fn 10_000 -> 10_000 end)

      assert {:ok, failed} = Forge.run_skill(caster, cdp_recipe(), 407)
      # div(100_050, 100) * 25, not div(100_050 * 25, 100) = 25_012
      assert failed.pending_hp_loss == 25_000
    end
  end

  defp pinned_skill_success?(caster, roll) do
    Application.put_env(:zone_server, :forge_rng, fn 10_000 -> roll end)
    {:ok, attempted} = Forge.run_skill(caster, cdp_recipe(), 407)
    attempted.pending_production_result.success
  end

  defp cdp_recipe do
    %Recipe{
      id: 127,
      product_id: 678,
      item_level: 22,
      skill_id: 407,
      skill_level: 1,
      materials: Enum.map(@cdp_materials, &%{item_id: &1, amount: 1})
    }
  end

  # Allocated stats `base`, no job bonus, and `equipment` as the only bonus.
  defp controlled(caster, base, equipment) do
    stats = caster.stats
    stats = %{stats | base_stats: Map.merge(stats.base_stats, base)}

    modifiers = %{
      stats.modifiers
      | job_bonuses: %{},
        equipment: Map.merge(stats.modifiers.equipment, equipment)
    }

    %{caster | stats: %{stats | modifiers: modifiers}}
  end

  # The formula's random terms take their lowest value and the success roll is `roll`.
  defp pinned_success?(caster, recipe, roll) do
    Application.put_env(:zone_server, :forge_rng, fn
      10_000 -> roll
      _upper -> 1
    end)

    {:ok, attempted} = Forge.run(caster, recipe, [])
    attempted.pending_production_result.success
  end

  defp iron_recipe do
    %Recipe{
      id: 0,
      product_id: 998,
      item_level: 26,
      skill_id: 94,
      skill_level: 1,
      materials: [%{item_id: 1002, amount: 1}]
    }
  end

  defp pharmacy_recipe do
    %Recipe{
      id: 119,
      product_id: 501,
      item_level: 22,
      skill_id: 228,
      skill_level: 1,
      materials: [%{item_id: 1002, amount: 1}]
    }
  end

  defp pharmacy_caster(caster, pharmacy_level) do
    caster
    |> put_in([Access.key!(:stats), Access.key!(:base_stats), Access.key!(:int)], 200)
    |> put_in([Access.key!(:stats), Access.key!(:base_stats), Access.key!(:dex)], 200)
    |> put_in([Access.key!(:stats), Access.key!(:base_stats), Access.key!(:luk)], 200)
    |> put_in([Access.key!(:stats), Access.key!(:progression), Access.key!(:job_level)], 70)
    |> put_in([Access.key!(:stats), Access.key!(:progression), Access.key!(:learned_skills)], %{
      228 => pharmacy_level
    })
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
