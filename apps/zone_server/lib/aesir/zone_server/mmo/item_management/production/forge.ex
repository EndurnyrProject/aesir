defmodule Aesir.ZoneServer.Mmo.ItemManagement.Production.Forge do
  @moduledoc """
  Orchestrates a production attempt inside the caster's player session.

  Possession is checked before materials are consumed. A selected catalyst the
  player does not hold is skipped rather than failing the attempt. The product is added
  afterwards, as the reference does: a refused add still leaves the materials
  and catalysts spent, reports the reason to the client, and does not undo the
  production result.
  """

  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemCraft
  alias Aesir.ZoneServer.Mmo.ItemManagement.Production.Anvil
  alias Aesir.ZoneServer.Mmo.ItemManagement.Production.Catalysts
  alias Aesir.ZoneServer.Mmo.ItemManagement.Production.Recipes.Recipe
  alias Aesir.ZoneServer.Mmo.ItemManagement.Production.SuccessRate
  alias Aesir.ZoneServer.Mmo.Skill.Learned
  alias Aesir.ZoneServer.Unit.ItemContainer
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryManager
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats

  @weapon_skill_ids 98..104
  @pharmacy_skill_id 228
  @weapon_research_id 107
  @oridecon_research_id 97
  @default_rng &:rand.uniform/1

  @doc """
  Runs one production attempt and stages its inventory and result changes.
  """
  @spec run(PlayerState.t(), Recipe.t(), [non_neg_integer()]) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def run(%PlayerState{} = caster, %Recipe{} = recipe, chosen_catalyst_ids) do
    run(caster, recipe, chosen_catalyst_ids, 0)
  end

  @doc """
  Runs one production attempt with the caller-supplied Instruction Change rank.
  """
  @spec run(PlayerState.t(), Recipe.t(), [non_neg_integer()], non_neg_integer()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def run(
        %PlayerState{} = caster,
        %Recipe{} = recipe,
        chosen_catalyst_ids,
        instruction_change_rank
      )
      when is_integer(instruction_change_rank) and instruction_change_rank >= 0 do
    {crumb_count, element, catalyst_ids} =
      catalysts(recipe, chosen_catalyst_ids, caster.inventory)

    with {:ok, item_def} <- ItemManagement.get_item_by_id(recipe.product_id),
         :ok <- check_materials(caster.inventory, recipe.materials, catalyst_ids) do
      consumed = consume_all(caster, recipe.materials, catalyst_ids)
      chance = success_chance(consumed, recipe, crumb_count, element, instruction_change_rank)
      success? = rng().(10_000) <= chance

      finish(consumed, recipe, item_def, success?, crumb_count, element)
    end
  end

  defp check_materials(inventory, materials, catalyst_ids) do
    consumed =
      materials
      |> Enum.reject(&(&1.amount == 0))
      |> Enum.map(&{&1.item_id, &1.amount})
      |> Kernel.++(Enum.map(catalyst_ids, &{&1, 1}))
      |> Enum.reduce(%{}, fn {id, amount}, counts ->
        Map.update(counts, id, amount, &(&1 + amount))
      end)

    possession_only? =
      Enum.all?(materials, fn material ->
        required = if material.amount == 0, do: 1, else: Map.fetch!(consumed, material.item_id)
        ItemContainer.held_amount(inventory, material.item_id) >= required
      end)

    catalysts? =
      Enum.all?(consumed, fn {id, amount} ->
        ItemContainer.held_amount(inventory, id) >= amount
      end)

    if possession_only? and catalysts?, do: :ok, else: {:error, :no_materials}
  end

  defp consume_all(caster, materials, catalyst_ids) do
    ids =
      materials
      |> Enum.reject(&(&1.amount == 0))
      |> Enum.flat_map(fn material -> List.duplicate(material.item_id, material.amount) end)
      |> Kernel.++(catalyst_ids)

    ids
    |> Enum.frequencies()
    |> Enum.reduce(caster, fn {id, amount}, state -> consume(state, id, amount) end)
  end

  defp consume(caster, id, amount) do
    index = ItemContainer.stackable_index(caster.inventory, id)
    {:ok, inventory, change} = ItemContainer.remove(caster.inventory, index, amount)

    %{
      caster
      | inventory: inventory,
        pending_inventory_persist:
          caster.pending_inventory_persist ++ [{caster.inventory, inventory, change}]
    }
  end

  defp catalysts(%Recipe{skill_id: @pharmacy_skill_id}, _chosen_catalyst_ids, _inventory),
    do: {0, nil, []}

  defp catalysts(_recipe, chosen_catalyst_ids, inventory) do
    {held, _taken} =
      chosen_catalyst_ids
      |> Enum.take(3)
      |> Enum.flat_map_reduce(%{}, fn id, taken ->
        count = Map.get(taken, id, 0)

        if ItemContainer.held_amount(inventory, id) > count,
          do: {[id], Map.put(taken, id, count + 1)},
          else: {[], taken}
      end)

    Catalysts.resolve(held)
  end

  defp success_chance(
         caster,
         %Recipe{skill_id: skill_id} = recipe,
         crumbs,
         element,
         _instruction_change_rank
       )
       when skill_id in @weapon_skill_ids do
    learned = PlayerStats.effective_skills(caster.stats)

    SuccessRate.weapon(%{
      job_level: caster.stats.progression.job_level,
      dex: caster.stats.base_stats.dex,
      luk: caster.stats.base_stats.luk,
      random_term: 10 * rng().(100),
      tier: recipe.item_level,
      family_skill_level: Learned.learned_level(learned, skill_id),
      weapon_research_level: Learned.learned_level(learned, @weapon_research_id),
      oridecon_research_level: Learned.learned_level(learned, @oridecon_research_id),
      crumb_count: crumbs,
      elemental_stone?: not is_nil(element),
      anvil_bonus: Anvil.best(caster.inventory)
    })
  end

  defp success_chance(
         caster,
         %Recipe{skill_id: @pharmacy_skill_id} = recipe,
         _crumbs,
         _element,
         instruction_change_rank
       ) do
    learned = PlayerStats.effective_skills(caster.stats)

    SuccessRate.pharmacy(recipe.product_id, %{
      job_level: caster.stats.progression.job_level,
      int: caster.stats.base_stats.int,
      dex: caster.stats.base_stats.dex,
      luk: caster.stats.base_stats.luk,
      skill_level: Learned.learned_level(learned, recipe.skill_id),
      learned_skills: learned,
      instruction_change_rank: instruction_change_rank,
      random_term: SuccessRate.pharmacy_roll(recipe.product_id, rng())
    })
  end

  defp success_chance(caster, recipe, _crumbs, _element, _instruction_change_rank) do
    learned = PlayerStats.effective_skills(caster.stats)

    SuccessRate.mineral(mineral_kind(recipe), %{
      job_level: caster.stats.progression.job_level,
      dex: caster.stats.base_stats.dex,
      luk: caster.stats.base_stats.luk,
      random_term: 10 * rng().(100),
      skill_level: Learned.learned_level(learned, recipe.skill_id)
    })
  end

  defp mineral_kind(%Recipe{skill_id: 94}), do: :iron
  defp mineral_kind(%Recipe{skill_id: 95}), do: :steel
  defp mineral_kind(%Recipe{skill_id: 96, product_id: 1000}), do: :star_crumb
  defp mineral_kind(%Recipe{skill_id: 96}), do: :elemental_stone

  defp rng, do: Application.get_env(:zone_server, :forge_rng, @default_rng)

  defp finish(caster, recipe, _item_def, false, _crumbs, _element) do
    {:ok, stage_result(caster, recipe.product_id, false)}
  end

  defp finish(caster, recipe, item_def, true, crumbs, element) do
    opts =
      if recipe.skill_id in @weapon_skill_ids do
        forged_element = if is_nil(element), do: :neutral, else: element
        craft = ItemCraft.forged(forged_element, crumbs, caster.character_id)
        %{identify: 1, craft: ItemCraft.to_map(craft)}
      else
        %{identify: 1}
      end

    case InventoryOps.add(caster.character_id, caster.inventory, caster.stats, item_def, 1, opts) do
      {:ok, inventory, change} ->
        forged = %{
          caster
          | inventory: inventory,
            pending_inventory_notify: caster.pending_inventory_notify ++ [change]
        }

        {:ok, stage_result(forged, recipe.product_id, true)}

      {:error, reason} ->
        # The craft already succeeded and its materials are spent; the reference
        # still reports the production result and tells the client why the
        # product could not be carried.
        {:ok,
         stage_result(InventoryManager.stage_add_failure(caster, reason), recipe.product_id, true)}
    end
  end

  defp stage_result(caster, item_id, success?) do
    %{caster | pending_production_result: %{success: success?, item_id: item_id}}
  end
end
