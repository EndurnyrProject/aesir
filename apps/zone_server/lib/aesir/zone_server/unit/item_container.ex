defmodule Aesir.ZoneServer.Unit.ItemContainer do
  @moduledoc """
  Pure, container-agnostic core shared by every indexed item container
  (`Aesir.ZoneServer.Unit.Inventory`, `Aesir.ZoneServer.Unit.Cart`, and future
  storage).

  Operates purely on an indexed container map (`%{non_neg_integer() =>
  InventoryItem.t()}`) and returns a change descriptor describing what
  happened. There is no database access, no socket, and no other side effect
  here; persistence and packet emission are the orchestrator's job.

  Every consumer holds `%InventoryItem{}` structs regardless of the concrete
  container (inventory, cart, or storage); only the slot cap differs between
  them, so `capacity` is the sole parameter threaded through the stacking and
  slot-assignment logic.

  `add_preserving/5` is the public cross-container transfer API: it carries a
  moved item's full attribute set (cards, refine, random options, bound,
  favorite, `unique_id`, `enchant_grade`, `expire_time`) across a move between
  two containers (inventory <-> cart, inventory <-> storage) and guarantees an
  item with any distinguishing attribute never merges into an anonymous plain
  stack.
  """

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition

  @max_stack 30_000

  @typedoc "Container keyed by stable session index."
  @type t :: %{non_neg_integer() => InventoryItem.t()}

  @typedoc "Descriptor of the change produced by a successful generic operation."
  @type change ::
          {:added, non_neg_integer(), InventoryItem.t()}
          | {:stacked, non_neg_integer(), pos_integer()}
          | {:split, [{non_neg_integer(), pos_integer()}]}
          | {:removed, non_neg_integer()}
          | {:reduced, non_neg_integer(), pos_integer()}

  @typedoc "Successful operation result: the new container plus the change."
  @type op_result :: {:ok, t(), change()} | {:error, atom()}

  @doc """
  Adds `amount` of `item_def` to `container`, whose slot cap is `capacity`.

  Stacks into an existing stackable item (same `nameid`, not equipped, no
  cards, no random options) up to `#{@max_stack}` and spills the overflow into
  the lowest free index(es). With no stackable target it creates a new item at
  the lowest free index. The add is all-or-nothing: if any required slot is
  missing, `capacity` is already reached, the container is left untouched and
  `{:error, :inventory_full}` is returned.

  Weight is intentionally NOT enforced here; the orchestrator enforces it.
  """
  @spec add(t(), ItemDefinition.t(), pos_integer(), pos_integer(), map()) :: op_result()
  def add(container, %ItemDefinition{} = item_def, amount, capacity, opts \\ %{})
      when is_map(container) and is_integer(amount) and amount > 0 and is_integer(capacity) do
    case find_stackable_index(container, item_def.id) do
      nil -> add_to_new_slots(container, item_def, amount, capacity, opts)
      index -> stack_onto(container, index, item_def, amount, capacity, opts)
    end
  end

  @doc """
  Removes `amount` from the item at `index`.

  Reduces the stack or, when the amount reaches zero, drops the slot entirely.
  """
  @spec remove(t(), non_neg_integer(), pos_integer()) :: op_result()
  def remove(container, index, amount)
      when is_map(container) and is_integer(amount) and amount > 0 do
    case Map.get(container, index) do
      nil ->
        {:error, :not_found}

      %InventoryItem{amount: held} when held < amount ->
        {:error, :insufficient_amount}

      %InventoryItem{amount: held} when held == amount ->
        {:ok, delete_index(container, index), {:removed, index}}

      %InventoryItem{amount: held} = item ->
        left = held - amount
        updated = %{item | amount: left}
        {:ok, put_item(container, index, updated), {:reduced, index, left}}
    end
  end

  @doc """
  Total quantity of item `nameid` held across all stackable slots.

  Sums the stackable stacks of `nameid` (unequipped, no cards, no random
  options); equipped or carded copies do not count toward the stackable total.
  """
  @spec held_amount(t(), integer()) :: non_neg_integer()
  def held_amount(container, nameid) when is_map(container) do
    Enum.reduce(container, 0, fn {_index, item}, acc ->
      if stackable?(item, nameid), do: acc + item.amount, else: acc
    end)
  end

  @doc """
  Index of a stackable slot holding item `nameid`, or `nil` when none exists.
  """
  @spec stackable_index(t(), integer()) :: non_neg_integer() | nil
  def stackable_index(container, nameid) when is_map(container) do
    find_stackable_index(container, nameid)
  end

  @doc """
  Returns the smallest unused non-negative index in the container map.
  """
  @spec lowest_free_index(t()) :: non_neg_integer()
  def lowest_free_index(container) when is_map(container) do
    Stream.iterate(0, &(&1 + 1))
    |> Enum.find(fn index -> not Map.has_key?(container, index) end)
  end

  @doc """
  Returns the item at the given session index, or nil when absent.
  """
  @spec get_by_index(t(), non_neg_integer()) :: InventoryItem.t() | nil
  def get_by_index(container, index) when is_map(container) do
    Map.get(container, index)
  end

  @doc """
  Puts an item at the given session index.
  """
  @spec put_item(t(), non_neg_integer(), InventoryItem.t()) :: t()
  def put_item(container, index, %InventoryItem{} = item) when is_map(container) do
    Map.put(container, index, item)
  end

  @doc """
  Removes the item at the given session index.
  """
  @spec delete_index(t(), non_neg_integer()) :: t()
  def delete_index(container, index) when is_map(container) do
    Map.delete(container, index)
  end

  @doc """
  Adds `source` to `container` (whose slot cap is `capacity`), preserving every
  attribute.

  A plain item (per `plain?/1`) may stack via `add/5`; anything distinguishing
  always takes a fresh slot so a carded, refined, optioned, bound, or otherwise
  distinguished item never merges onto a plain stack and loses its attributes.
  Pure: computes the new container map and change descriptor without any DB
  write, so it composes inside a larger transaction (cart moves, storage
  deposits/withdrawals, cross-player trades).
  """
  @spec add_preserving(t(), ItemDefinition.t(), pos_integer(), pos_integer(), InventoryItem.t()) ::
          op_result()
  def add_preserving(
        container,
        %ItemDefinition{} = item_def,
        amount,
        capacity,
        %InventoryItem{} = source
      )
      when is_map(container) and is_integer(amount) and amount > 0 and is_integer(capacity) do
    if plain?(source) do
      add(container, item_def, amount, capacity, item_opts(source))
    else
      add_to_new_slot(container, item_def, amount, capacity, source)
    end
  end

  @doc """
  True when `item` carries no distinguishing attribute and may stack anonymously.

  An item with a non-default refine, attribute, bound, card, random option,
  favorite flag, `unique_id`, `enchant_grade`, or `expire_time` is not plain and
  must always take a fresh slot on transfer.
  """
  @spec plain?(InventoryItem.t()) :: boolean()
  def plain?(%InventoryItem{} = item) do
    zero_fields = [
      item.refine,
      item.attribute,
      item.bound,
      item.card0,
      item.card1,
      item.card2,
      item.card3,
      item.unique_id,
      item.enchant_grade
    ]

    item.identify == 1 and item.favorite == 0 and item.expire_time == nil and
      map_size(item.random_options) == 0 and Enum.all?(zero_fields, &(&1 == 0))
  end

  defp find_stackable_index(container, nameid) do
    Enum.find_value(container, fn {index, item} ->
      if stackable?(item, nameid), do: index
    end)
  end

  defp stackable?(%InventoryItem{} = item, nameid) do
    item.nameid == nameid and item.equip == 0 and
      item.card0 == 0 and item.card1 == 0 and item.card2 == 0 and item.card3 == 0 and
      map_size(item.random_options) == 0
  end

  defp stack_onto(container, index, item_def, amount, capacity, opts) do
    item = Map.fetch!(container, index)
    total = item.amount + amount

    if total <= @max_stack do
      updated = %{item | amount: total}
      {:ok, put_item(container, index, updated), {:stacked, index, total}}
    else
      remainder = total - @max_stack
      topped = %{item | amount: @max_stack}
      container = put_item(container, index, topped)

      case add_to_new_slots(container, item_def, remainder, capacity, opts) do
        {:ok, new_container, {:added, new_index, %InventoryItem{amount: new_amount}}} ->
          {:ok, new_container, {:split, [{index, @max_stack}, {new_index, new_amount}]}}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp add_to_new_slots(container, item_def, amount, capacity, opts) do
    if map_size(container) >= capacity do
      {:error, :inventory_full}
    else
      index = lowest_free_index(container)
      new_item = build_item(item_def, amount, opts)
      {:ok, put_item(container, index, new_item), {:added, index, new_item}}
    end
  end

  defp add_to_new_slot(container, item_def, amount, capacity, %InventoryItem{} = source) do
    if map_size(container) >= capacity do
      {:error, :inventory_full}
    else
      index = lowest_free_index(container)
      new_item = build_item(item_def, amount, source)
      {:ok, put_item(container, index, new_item), {:added, index, new_item}}
    end
  end

  defp build_item(%ItemDefinition{} = item_def, amount, %InventoryItem{} = source) do
    %InventoryItem{
      nameid: item_def.id,
      amount: amount,
      equip: 0,
      identify: source.identify,
      refine: source.refine,
      attribute: source.attribute,
      card0: source.card0,
      card1: source.card1,
      card2: source.card2,
      card3: source.card3,
      random_options: source.random_options,
      bound: source.bound,
      favorite: source.favorite,
      unique_id: source.unique_id,
      enchant_grade: source.enchant_grade,
      expire_time: source.expire_time
    }
  end

  defp build_item(%ItemDefinition{} = item_def, amount, opts) do
    %InventoryItem{
      nameid: item_def.id,
      amount: amount,
      equip: 0,
      identify: Map.get(opts, :identify, 1),
      refine: Map.get(opts, :refine, 0),
      attribute: Map.get(opts, :attribute, 0),
      card0: Map.get(opts, :card0, 0),
      card1: Map.get(opts, :card1, 0),
      card2: Map.get(opts, :card2, 0),
      card3: Map.get(opts, :card3, 0),
      random_options: Map.get(opts, :random_options, %{}),
      bound: Map.get(opts, :bound, 0),
      favorite: Map.get(opts, :favorite, 0),
      unique_id: Map.get(opts, :unique_id, 0),
      enchant_grade: Map.get(opts, :enchant_grade, 0),
      expire_time: Map.get(opts, :expire_time)
    }
  end

  defp item_opts(%InventoryItem{} = item) do
    %{
      identify: item.identify,
      refine: item.refine,
      attribute: item.attribute,
      card0: item.card0,
      card1: item.card1,
      card2: item.card2,
      card3: item.card3,
      random_options: item.random_options,
      bound: item.bound,
      favorite: item.favorite,
      unique_id: item.unique_id,
      enchant_grade: item.enchant_grade,
      expire_time: item.expire_time
    }
  end
end
