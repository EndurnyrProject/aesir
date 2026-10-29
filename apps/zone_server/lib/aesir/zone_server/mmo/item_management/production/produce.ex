defmodule Aesir.ZoneServer.Mmo.ItemManagement.Production.Produce do
  @moduledoc """
  The production list an item's `produce <trigger>` script opens (the Mini
  Furnace's 21, the Iron, Golden and Oridecon Hammers' 1, 2 and 3), and the
  production its selection runs.

  The trigger selects recipes by item level: above 20 the level must equal it,
  11 to 20 accepts any level from 11 to 20, and 10 or less accepts every level up
  to it, so each hammer lists its weapon tier and the tiers below. A product is
  offered when the first recipe making it whose required skill is learned at the
  recipe's level passes the trigger, every material is held (an amount of zero
  only needs possession) and one more copy fits (`fits_inventory?/3`). A negative
  trigger (a skill producing directly, without a list) accepts any item level. While
  another skill's menu is open, a recipe needing a different skill does not
  count. Every recipe is walked in database order, so a product two recipes
  make is offered twice.

  The list is sent even when empty, but only a non-empty list replaces the open
  menu; while a production list is already open a new one is not sent. The menu
  carries `src_skill_id` 0 because no skill opens it. The reply runs the same
  check against the stored trigger, and the production uses the recipe's
  required skill for its success chance. A reply while trading fails the skill
  and closes the menu. Renewal and pre-renewal agree.
  """

  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.ItemManagement.Production.Forge
  alias Aesir.ZoneServer.Mmo.ItemManagement.Production.Recipes
  alias Aesir.ZoneServer.Mmo.ItemManagement.Production.Recipes.Recipe
  alias Aesir.ZoneServer.Mmo.Skill.Learned
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.ItemContainer
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats

  @menu_id 0
  @max_stack 30_000

  @doc "The `src_skill_id` a production list carries."
  @spec menu_id() :: 0
  def menu_id, do: @menu_id

  @doc """
  The products listed for `trigger`, with `open_menu_skill_id` the skill whose
  menu is open (0 for none).
  """
  @spec offer(PlayerState.t(), integer(), non_neg_integer()) :: [integer()]
  def offer(%PlayerState{} = caster, trigger, open_menu_skill_id),
    do: offer(caster, trigger, open_menu_skill_id, 0)

  @doc """
  The products a list opened by `list_skill_id` shows (0 for an item's list):
  as `offer/3`, keeping only the recipe rows that skill makes.
  """
  @spec offer(PlayerState.t(), integer(), non_neg_integer(), non_neg_integer()) :: [integer()]
  def offer(%PlayerState{} = caster, trigger, open_menu_skill_id, list_skill_id) do
    for recipe <- Recipes.all(),
        list_skill_id <= 0 or recipe.skill_id == list_skill_id,
        match?({:ok, _}, producible(caster, recipe.product_id, trigger, open_menu_skill_id)),
        do: recipe.product_id
  end

  @doc "The recipe `product_id` is made from, when `trigger` allows producing it now."
  @spec producible(PlayerState.t(), integer(), integer(), non_neg_integer()) ::
          {:ok, Recipe.t()} | :error
  def producible(%PlayerState{} = caster, product_id, trigger, open_menu_skill_id),
    do: producible(caster, product_id, trigger, open_menu_skill_id, 1)

  @doc """
  As `producible/4` for `qty` copies at once: every material must be held
  `qty` times over (one held copy for a possession-only one) and the whole
  quantity must fit (`fits_inventory?/3`).
  """
  @spec producible(PlayerState.t(), integer(), integer(), non_neg_integer(), pos_integer()) ::
          {:ok, Recipe.t()} | :error
  def producible(%PlayerState{} = caster, product_id, trigger, open_menu_skill_id, qty) do
    learned = PlayerStats.effective_skills(caster.stats)

    with {:ok, item_def} <- ItemManagement.get_item_by_id(product_id),
         %Recipe{} = recipe <- first_recipe(product_id, learned, open_menu_skill_id),
         true <- fits_inventory?(caster.inventory, item_def, qty),
         true <- trigger_allows?(trigger, recipe.item_level),
         true <- materials_held?(caster.inventory, recipe.materials, qty) do
      {:ok, recipe}
    else
      _ -> :error
    end
  end

  @doc "Runs the production selected from a production list opened with `trigger`."
  @spec on_menu_reply(
          PlayerState.t(),
          %{id: non_neg_integer(), extras: [non_neg_integer()]},
          integer(),
          map()
        ) :: {:ok, PlayerState.t()} | {:silent, PlayerState.t()} | {:error, atom()}
  def on_menu_reply(_caster, _selection, _trigger, %{trading?: true}), do: {:error, :skill_failed}

  def on_menu_reply(%PlayerState{} = caster, %{id: product_id, extras: extras}, trigger, _context) do
    case producible(caster, product_id, trigger, @menu_id) do
      {:ok, recipe} -> Forge.run(caster, recipe, extras)
      :error -> {:silent, caster}
    end
  end

  defp first_recipe(product_id, learned, open_menu_skill_id) do
    Enum.find(Recipes.all(), fn recipe ->
      recipe.product_id == product_id and
        (recipe.skill_id <= 0 or
           (Learned.learned_level(learned, recipe.skill_id) >= recipe.skill_level and
              (open_menu_skill_id <= 0 or open_menu_skill_id == recipe.skill_id)))
    end)
  end

  @doc """
  Whether `amount` more copies of `item_def` (one by default) fit `inventory`,
  weight aside.

  More than 30,000 never fits. A non-stackable item otherwise always fits. A
  stackable one must fit its own inventory stack limit, and the first slot
  already holding it (the lowest index) must stay within 30,000 and that limit
  with the new copies and lie within the usable inventory slots.
  """
  @spec fits_inventory?(ItemContainer.t(), ItemDefinition.t(), pos_integer()) :: boolean()
  def fits_inventory?(inventory, item_def, amount \\ 1) do
    limit = ItemDefinition.stack_limit(item_def, :inventory)

    cond do
      amount > @max_stack -> false
      not ItemDefinition.stackable?(item_def) -> true
      limit != nil and amount > limit -> false
      true -> first_stack_fits?(first_held(inventory, item_def.id), limit, amount)
    end
  end

  defp first_stack_fits?(nil, _limit, _amount), do: true

  defp first_stack_fits?({index, held}, limit, amount) do
    amount <= @max_stack - held.amount and (is_nil(limit) or amount <= limit - held.amount) and
      index < Inventory.capacity()
  end

  defp first_held(inventory, item_id) do
    inventory
    |> Enum.filter(fn {_index, item} -> item.nameid == item_id end)
    |> Enum.min_by(fn {index, _item} -> index end, fn -> nil end)
  end

  defp trigger_allows?(trigger, _item_level) when trigger < 0, do: true
  defp trigger_allows?(trigger, item_level) when trigger > 20, do: item_level == trigger
  defp trigger_allows?(trigger, item_level) when trigger > 10, do: item_level in 11..20
  defp trigger_allows?(trigger, item_level), do: item_level <= trigger

  defp materials_held?(inventory, materials, qty) do
    Enum.all?(materials, fn %{item_id: item_id, amount: amount} ->
      ItemContainer.held_amount(inventory, item_id) >= max(amount * qty, 1)
    end)
  end
end
