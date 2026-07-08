defmodule Aesir.ZoneServer.Unit.Player.Handlers.RefineOps do
  @moduledoc """
  Single-writer transaction orchestrator for a single refine attempt.

  Mirrors `Aesir.ZoneServer.Unit.Player.Handlers.StorageOps`/`CartOps`: a pure
  pre-validation step guards every failure mode before any write, then one
  `Aesir.ZoneServer.Unit.Inventory.Persistence.transaction/1` consumes the ore
  (plus zeny, plus a Blacksmith Blessing when requested) **regardless of
  outcome** and applies the roll's effect on the target item. `apply/6` is the
  only entry point; callers pass the authoritative `PlayerState` and get back
  the advanced state plus a tagged result.

  ## Offsets

  The process lookup reads `RefineDatabase.level_info(group, item_level, refine
  + 1)` (the chances offset - see `RefineDatabase`'s moduledoc, "Off-by-one"):
  attempting `+N -> +N+1` consults the yml Level `N+1` node.

  ## Consumption order

  Ore, then (optionally) the Blacksmith Blessing, then zeny, then the outcome
  itself, all inside one transaction: a failure anywhere rolls back everything,
  leaving the player's inventory and zeny exactly as they were.

  ## Equip handling

  A broken worn item is destroyed via `InventoryOps.remove/4` (the same path
  a full-stack removal takes), which deletes the row outright - there is no
  separate "clear the bitmask" write because the row, bitmask included, ceases
  to exist. Whenever the touched item was equipped and the outcome changed its
  contribution to combat stats (success, downgrade, or break), stats are
  recalculated in place with `Stats.calculate_stats/3`, exactly like
  `EquipmentHandler.advance/2` does after an equip/unequip. Broadcasting the
  result and re-sending the item view are the caller's job (DSL routing,
  `ScriptEffectHandler`), not this module's.
  """

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.Refine.Refine
  alias Aesir.ZoneServer.Mmo.Refine.RefineDatabase
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Inventory.Persistence
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats

  @max_refine 20
  @ore_amount 1
  @blessing_aegis "Blacksmith_Blessing"

  @typedoc "Why a refine attempt was rejected before any write."
  @type reason :: :no_item | :not_refinable | :max_refine | :no_ore | :no_zeny | :no_blessing

  @typedoc "The tagged outcome of a refine attempt."
  @type result ::
          {:ok, :success, non_neg_integer()}
          | {:ok, :broke}
          | {:ok, :downgrade, non_neg_integer()}
          | {:ok, :fail}
          | {:error, reason()}

  @typedoc "Injectable rolls for deterministic tests; both default to a fresh `0..9999` roll."
  @type opt :: {:success_roll, 0..9999} | {:break_roll, 0..9999}

  @doc """
  Attempts to refine the item at inventory `index` using `cost_type`.

  `nameid` is the item identity the caller observed when it decided to refine
  (e.g. from `refine_targets/1`); this guards the TOCTOU window between that
  read and this call arriving at the single-writer session - the item at
  `index` is re-read here and, if its `nameid` no longer matches, the attempt
  is rejected with `{:error, :no_item}` before anything else is validated.

  Pre-validates the whole attempt (item present and identity-matched,
  refineable, below `MAX_REFINE`, the process `level_info` exists for
  `cost_type`, enough ore, enough zeny, and - when `use_blessing?` - enough
  Blacksmith Blessings) before rolling or writing anything; any miss returns
  `{state, {:error, reason}}` with nothing consumed. On a resolvable attempt,
  `Refine.outcome/6` decides the result and the whole consume-and-apply step
  commits in one transaction.

  `opts` accepts `:success_roll`/`:break_roll` (`0..9999`) to make the attempt
  deterministic in tests; in production both default to a fresh roll.
  """
  @spec apply(
          PlayerState.t(),
          non_neg_integer(),
          integer(),
          RefineDatabase.cost_type(),
          boolean(),
          [opt()]
        ) :: {PlayerState.t(), result()}
  def apply(state, index, nameid, cost_type, use_blessing? \\ false, opts \\ [])

  def apply(%PlayerState{} = state, index, nameid, cost_type, use_blessing?, opts)
      when is_integer(index) and index >= 0 and is_integer(nameid) and is_boolean(use_blessing?) do
    case validate(state, index, nameid, cost_type, use_blessing?) do
      {:ok, ctx} -> commit(state, index, cost_type, use_blessing?, ctx, opts)
      {:error, reason} -> {state, {:error, reason}}
    end
  end

  @spec validate(
          PlayerState.t(),
          non_neg_integer(),
          integer(),
          RefineDatabase.cost_type(),
          boolean()
        ) :: {:ok, map()} | {:error, reason()}
  defp validate(
         %PlayerState{inventory: inventory, zeny: zeny},
         index,
         nameid,
         cost_type,
         use_blessing?
       ) do
    with {:ok, item} <- fetch_item(inventory, index, nameid),
         {:ok, item_def} <- fetch_definition(item),
         :ok <- ensure_refinable(item_def),
         :ok <- ensure_below_max(item.refine),
         {:ok, group, item_level} <- group_and_level(item_def),
         {:ok, level_info} <- fetch_level_info(group, item_level, item.refine + 1),
         {:ok, chance} <- fetch_chance(level_info, cost_type),
         {:ok, ore_index} <- ensure_ore(inventory, chance),
         :ok <- ensure_zeny(zeny, chance.price),
         {:ok, blessing_index} <- ensure_blessing(inventory, level_info, use_blessing?) do
      {:ok,
       %{
         item: item,
         level_info: level_info,
         chance: chance,
         ore_index: ore_index,
         blessing_index: blessing_index
       }}
    end
  end

  @spec fetch_item(Inventory.t(), non_neg_integer(), integer()) ::
          {:ok, InventoryItem.t()} | {:error, :no_item}
  defp fetch_item(inventory, index, nameid) do
    case Map.get(inventory, index) do
      %InventoryItem{nameid: ^nameid} = item -> {:ok, item}
      _stale_or_missing -> {:error, :no_item}
    end
  end

  @spec fetch_definition(InventoryItem.t()) ::
          {:ok, ItemDefinition.t()} | {:error, :not_refinable}
  defp fetch_definition(%InventoryItem{nameid: nameid}) do
    case ItemManagement.get_item_by_id(nameid) do
      {:ok, item_def} -> {:ok, item_def}
      {:error, _reason} -> {:error, :not_refinable}
    end
  end

  @spec ensure_refinable(ItemDefinition.t()) :: :ok | {:error, :not_refinable}
  defp ensure_refinable(%ItemDefinition{refineable: true}), do: :ok
  defp ensure_refinable(%ItemDefinition{}), do: {:error, :not_refinable}

  @spec ensure_below_max(non_neg_integer()) :: :ok | {:error, :max_refine}
  defp ensure_below_max(refine) when refine < @max_refine, do: :ok
  defp ensure_below_max(_refine), do: {:error, :max_refine}

  @spec group_and_level(ItemDefinition.t()) ::
          {:ok, RefineDatabase.group(), integer()} | {:error, :not_refinable}
  defp group_and_level(%ItemDefinition{type: :weapon, weapon_level: level})
       when is_integer(level) do
    {:ok, :weapon, level}
  end

  defp group_and_level(%ItemDefinition{type: :armor, armor_level: level})
       when is_integer(level) do
    {:ok, :armor, level}
  end

  defp group_and_level(%ItemDefinition{}), do: {:error, :not_refinable}

  @spec fetch_level_info(RefineDatabase.group(), integer(), integer()) ::
          {:ok, RefineDatabase.level_info()} | {:error, :not_refinable}
  defp fetch_level_info(group, item_level, process_level) do
    case RefineDatabase.level_info(group, item_level, process_level) do
      nil -> {:error, :not_refinable}
      level_info -> {:ok, level_info}
    end
  end

  @spec fetch_chance(RefineDatabase.level_info(), RefineDatabase.cost_type()) ::
          {:ok, RefineDatabase.chance()} | {:error, :not_refinable}
  defp fetch_chance(%{chances: chances}, cost_type) do
    case Map.fetch(chances, cost_type) do
      {:ok, chance} -> {:ok, chance}
      :error -> {:error, :not_refinable}
    end
  end

  @spec ensure_ore(Inventory.t(), RefineDatabase.chance()) ::
          {:ok, non_neg_integer()} | {:error, :no_ore}
  defp ensure_ore(_inventory, %{material_nameid: nil}), do: {:error, :no_ore}

  defp ensure_ore(inventory, %{material_nameid: nameid}) do
    if Inventory.held_amount(inventory, nameid) >= @ore_amount do
      {:ok, Inventory.stackable_index(inventory, nameid)}
    else
      {:error, :no_ore}
    end
  end

  @spec ensure_zeny(integer(), non_neg_integer()) :: :ok | {:error, :no_zeny}
  defp ensure_zeny(zeny, price) when zeny >= price, do: :ok
  defp ensure_zeny(_zeny, _price), do: {:error, :no_zeny}

  @spec ensure_blessing(Inventory.t(), RefineDatabase.level_info(), boolean()) ::
          {:ok, non_neg_integer() | nil} | {:error, :no_blessing}
  defp ensure_blessing(_inventory, _level_info, false), do: {:ok, nil}
  defp ensure_blessing(_inventory, %{blessing_amount: 0}, true), do: {:error, :no_blessing}

  defp ensure_blessing(inventory, %{blessing_amount: amount}, true) do
    with {:ok, %ItemDefinition{id: blessing_nameid}} <-
           ItemManagement.get_item_by_aegis(@blessing_aegis),
         true <- Inventory.held_amount(inventory, blessing_nameid) >= amount do
      {:ok, Inventory.stackable_index(inventory, blessing_nameid)}
    else
      _ -> {:error, :no_blessing}
    end
  end

  @spec commit(
          PlayerState.t(),
          non_neg_integer(),
          RefineDatabase.cost_type(),
          boolean(),
          map(),
          [opt()]
        ) :: {PlayerState.t(), result()}
  defp commit(state, index, cost_type, use_blessing?, ctx, opts) do
    %{item: item, level_info: level_info, chance: chance} = ctx
    char_id = state.character_id
    new_zeny = state.zeny - chance.price

    success_roll = Keyword.get_lazy(opts, :success_roll, &default_roll/0)
    break_roll = Keyword.get_lazy(opts, :break_roll, &default_roll/0)

    outcome =
      Refine.outcome(item.refine, level_info, cost_type, use_blessing?, success_roll, break_roll)

    result =
      Persistence.transaction(fn ->
        with {:ok, inv1, _change} <-
               InventoryOps.remove(char_id, state.inventory, ctx.ore_index, @ore_amount),
             {:ok, inv2} <-
               consume_blessing(char_id, inv1, use_blessing?, ctx.blessing_index, level_info),
             {:ok, _character} <-
               CharacterPersistence.update_character(char_id, %{zeny: new_zeny}) do
          apply_outcome(char_id, inv2, index, item, outcome)
        end
      end)

    case result do
      {:ok, final_inventory} ->
        {advance_state(state, final_inventory, new_zeny, item, outcome), tag(outcome)}

      {:error, reason} ->
        {state, {:error, reason}}
    end
  end

  @spec default_roll() :: 0..9999
  defp default_roll, do: :rand.uniform(10_000) - 1

  @spec consume_blessing(
          integer(),
          Inventory.t(),
          boolean(),
          non_neg_integer() | nil,
          RefineDatabase.level_info()
        ) :: {:ok, Inventory.t()} | {:error, term()}
  defp consume_blessing(_char_id, inventory, false, _index, _level_info), do: {:ok, inventory}

  defp consume_blessing(char_id, inventory, true, index, %{blessing_amount: amount}) do
    with {:ok, persisted, _change} <- InventoryOps.remove(char_id, inventory, index, amount) do
      {:ok, persisted}
    end
  end

  @spec apply_outcome(
          integer(),
          Inventory.t(),
          non_neg_integer(),
          InventoryItem.t(),
          Refine.result()
        ) ::
          {:ok, Inventory.t()} | {:error, term()}
  defp apply_outcome(_char_id, inventory, index, item, {:success, new_level}) do
    update_refine(inventory, index, item, new_level)
  end

  defp apply_outcome(_char_id, inventory, index, item, {:downgrade, new_level}) do
    update_refine(inventory, index, item, new_level)
  end

  defp apply_outcome(char_id, inventory, index, item, {:break}) do
    with {:ok, persisted, _change} <- InventoryOps.remove(char_id, inventory, index, item.amount) do
      {:ok, persisted}
    end
  end

  defp apply_outcome(_char_id, inventory, _index, _item, {:fail}), do: {:ok, inventory}

  @spec update_refine(Inventory.t(), non_neg_integer(), InventoryItem.t(), non_neg_integer()) ::
          {:ok, Inventory.t()} | {:error, term()}
  defp update_refine(inventory, index, item, new_level) do
    with {:ok, updated_row} <- Persistence.update_item(item, %{refine: new_level}) do
      {:ok, PlayerState.put_item(inventory, index, updated_row)}
    end
  end

  @spec advance_state(
          PlayerState.t(),
          Inventory.t(),
          integer(),
          InventoryItem.t(),
          Refine.result()
        ) :: PlayerState.t()
  defp advance_state(state, final_inventory, new_zeny, item, outcome) do
    state = %{state | inventory: final_inventory, zeny: new_zeny}

    if item.equip != 0 and recalculates_stats?(outcome) do
      equipped = Map.values(Inventory.equipped_items(final_inventory))
      %{state | stats: Stats.calculate_stats(state.stats, state.character_id, equipped)}
    else
      state
    end
  end

  @spec recalculates_stats?(Refine.result()) :: boolean()
  defp recalculates_stats?({:success, _new_level}), do: true
  defp recalculates_stats?({:downgrade, _new_level}), do: true
  defp recalculates_stats?({:break}), do: true
  defp recalculates_stats?({:fail}), do: false

  @spec tag(Refine.result()) :: result()
  defp tag({:success, new_level}), do: {:ok, :success, new_level}
  defp tag({:break}), do: {:ok, :broke}
  defp tag({:downgrade, new_level}), do: {:ok, :downgrade, new_level}
  defp tag({:fail}), do: {:ok, :fail}
end
