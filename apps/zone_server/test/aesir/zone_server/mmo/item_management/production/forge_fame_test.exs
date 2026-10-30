defmodule Aesir.ZoneServer.Mmo.ItemManagement.Production.ForgeFameTest do
  use Aesir.DataCase, async: false
  use Mimic

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.ItemManagement.Production.Forge
  alias Aesir.ZoneServer.Mmo.ItemManagement.Production.Recipes.Recipe
  alias Aesir.ZoneServer.Mmo.Skills.Alchemist.TwilightAlchemy
  alias Aesir.ZoneServer.Unit.ItemContainer
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats

  setup :set_mimic_private

  setup do
    account =
      Repo.insert!(%Account{userid: "forge-fame", user_pass: "unused", email: "fame@test.local"})

    character =
      Repo.insert!(%Character{
        account_id: account.id,
        char_num: 0,
        name: "FameMaker",
        class: 4019,
        job_level: 70
      })

    stats = Stats.from_character(character)
    stats = put_in(stats.progression.learned_skills, %{228 => 1, 99 => 3})
    %{caster: %PlayerState{character_id: character.id, stats: stats}}
  end

  test "single condensed preparations carry milestones across calls", %{caster: caster} do
    rolls([1, 1, 1])
    caster = %{caster | potion_success_counter: 2, inventory: inventory([{1002, 3}])}
    assert {:ok, first} = Forge.run(caster, recipe(547), [])
    assert first.fame == 1
    assert first.potion_success_counter == 3
    assert {:ok, ordinary} = Forge.run(first, recipe(501), [])
    assert ordinary.potion_success_counter == 3
    assert {:ok, next} = Forge.run(ordinary, recipe(547), [])
    assert next.potion_success_counter == 4
    assert next.fame == 1
    assert length(next.pending_fame_awards) == 1
  end

  test "a mixed batch preserves roll order and stages one summed award", %{caster: caster} do
    rolls([1, 1, 1, 10_000, 1, 1, 1, 1, 1, 1, 1])
    caster = %{caster | potion_success_counter: 2, inventory: inventory([{1002, 11}])}
    assert {:ok, made} = Forge.run_batch(caster, recipe(547), 11, 0)
    assert ItemContainer.held_amount(made.inventory, 547) == 10
    assert made.potion_success_counter == 7
    assert made.fame == 18

    assert made.pending_fame_awards == [
             %{category: :alchemist, awarded_points: 18, total_fame: 18}
           ]

    assert Process.get(:fame_rolls) == []
    assert Enum.reverse(Process.get(:fame_rng_calls)) == [491 | List.duplicate(10_000, 11)]
  end

  test "twilight sub-batches retain independent award boundaries", %{caster: caster} do
    rolls(List.duplicate(1, 10))
    caster = %{caster | inventory: inventory([{1002, 10}])}
    first = TwilightAlchemy.add_batch(caster, recipe(547), 5)
    made = TwilightAlchemy.add_batch(first, recipe(547), 5)
    assert made.potion_success_counter == 0
    assert made.fame == 64

    assert made.pending_fame_awards == [
             %{category: :alchemist, awarded_points: 4, total_fame: 4},
             %{category: :alchemist, awarded_points: 60, total_fame: 64}
           ]
  end

  test "actual potion failure resets but validation rejection and forge failure do not", %{
    caster: caster
  } do
    caster = %{caster | potion_success_counter: 7}
    assert {:error, :no_materials} = Forge.run(caster, recipe(547), [])
    rolls([10_000, 10_000])

    assert {:ok, failed} =
             Forge.run_batch(%{caster | inventory: inventory([{1002, 2}])}, recipe(501), 2, 0)

    assert failed.potion_success_counter == 0
    rolls([10_000])

    assert {:ok, failed} =
             Forge.run(%{caster | inventory: inventory([{1002, 1}])}, recipe(547), [])

    assert failed.potion_success_counter == 0

    for recipe <- [%{recipe(1126) | skill_id: 99, item_level: 3}, %{recipe(998) | skill_id: 94}] do
      rolls([10_000])
      assert {:ok, failed} = Forge.run(%{caster | inventory: inventory([{1002, 1}])}, recipe, [])
      assert failed.potion_success_counter == 7
      assert failed.fame == 0
    end

    rolls([10_000])
    caster = put_in(caster.stats.derived_stats.max_hp, 1_000)
    poison = %{recipe(678) | skill_id: 407}

    assert {:ok, failed} =
             Forge.run_skill(%{caster | inventory: inventory([{1002, 1}])}, poison, 407)

    assert failed.potion_success_counter == 0
    assert failed.pending_hp_loss == 250
  end

  test "qualifying forging earns fame even when delivery is refused", %{caster: caster} do
    rolls([1])
    caster = put_in(caster.stats.progression.job_id, 10)
    recipe = %{recipe(1126) | skill_id: 99, item_level: 3}

    stub(InventoryOps, :add, fn _id, _inventory, _stats, _definition, _amount, _opts ->
      {:error, :inventory_full}
    end)

    caster = %{caster | inventory: inventory([{1002, 1}, {1000, 3}])}
    assert {:ok, made} = Forge.run(caster, recipe, [1000, 1000, 1000])
    assert made.fame == 10
    assert made.pending_production_result.success
    assert made.pending_item_add_failures == [:inventory_full]
    assert ItemContainer.held_amount(made.inventory, 1000) == 0

    rolls([1])

    assert {:ok, unqualified} =
             Forge.run(%{caster | inventory: inventory([{1002, 1}, {1000, 2}])}, recipe, [
               1000,
               1000,
               1000
             ])

    assert unqualified.fame == 0
  end

  defp rolls(values) do
    Process.put(:fame_rolls, values)
    Process.put(:fame_rng_calls, [])

    rng = fn upper ->
      Process.put(:fame_rng_calls, [upper | Process.get(:fame_rng_calls)])

      if upper == 10_000 do
        [value | rest] = Process.get(:fame_rolls)
        Process.put(:fame_rolls, rest)
        value
      else
        1
      end
    end

    stub(Application, :get_env, fn
      :zone_server, :forge_rng, _default -> rng
      app, key, default -> Mimic.call_original(Application, :get_env, [app, key, default])
    end)
  end

  defp recipe(product) do
    %Recipe{
      id: 1,
      product_id: product,
      item_level: 22,
      skill_id: 228,
      skill_level: 1,
      materials: [%{item_id: 1002, amount: 1}]
    }
  end

  defp inventory(entries) do
    entries
    |> Enum.with_index()
    |> Map.new(fn {{id, amount}, index} ->
      {index, %InventoryItem{nameid: id, amount: amount, identify: 1}}
    end)
  end
end
