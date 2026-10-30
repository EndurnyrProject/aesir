defmodule Aesir.ZoneServer.Unit.ItemContainer do
  @moduledoc """
  Pure core shared by every indexed item container: the inventory, the cart,
  the account storage and the guild storage.

  Operates purely on an indexed container map (`%{non_neg_integer() =>
  InventoryItem.t()}`) and returns a change descriptor describing what
  happened. There is no database access, no socket, and no other side effect
  here; persistence and packet emission are the orchestrator's job. Reading
  static item definitions is a deterministic lookup and stays here.

  `put/6` adds an item with the recipe of the container `kind` it enters. The
  four recipes differ in their checks, their order, which held stack an item
  merges into and the reason a refusal reports, so an orchestrator always
  names the kind rather than passing a slot cap alone.
  """

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition

  @max_stack 30_000

  @typedoc "Container keyed by stable session index."
  @type t :: %{non_neg_integer() => InventoryItem.t()}

  @typedoc "The container an item is added to; each has its own add recipe."
  @type kind :: :inventory | :cart | :storage | :guild_storage

  @typedoc """
  Room an add may use: the container's slot cap and the weight still free,
  `:infinity` for an unweighted container.
  """
  @type room :: %{capacity: pos_integer(), weight: integer() | :infinity}

  @typedoc """
  Why an add was refused.

  The inventory reports `:invalid`, `:over_amount`, `:stack_limit`,
  `:overweight` or `:inventory_full` (no free slot). The cart reports
  `:invalid`, `:stack_limit`, `:restricted`, `:overweight` or `:over_amount`
  (also when no slot is free). The storages report `:invalid`, `:restricted`
  (the item or a card may not be stored there), `:bound` (its binding may
  not) or `:storage_full` (no room, a full stack or the stack limit).
  """
  @type add_error ::
          :invalid
          | :over_amount
          | :stack_limit
          | :overweight
          | :inventory_full
          | :restricted
          | :bound
          | :storage_full

  @typedoc "Descriptor of the change produced by a successful generic operation."
  @type change ::
          {:added, non_neg_integer(), InventoryItem.t()}
          | {:stacked, non_neg_integer(), pos_integer()}
          | {:removed, non_neg_integer()}
          | {:reduced, non_neg_integer(), pos_integer()}
          | {:identified, non_neg_integer()}

  @typedoc "Successful operation result: the new container plus the change."
  @type op_result :: {:ok, t(), change()} | {:error, atom()}

  @doc """
  Adds `amount` copies of `item` to `container` with the recipe of `kind`.

  `item` carries the attributes a new slot takes (a fresh grant from
  `new_item/2`, or the moved row of another container); its own `amount` and
  `id` are ignored. The checks run in the recipe's order and the first failing
  one is reported (see `t:add_error/0`). A stackable item merges into the
  lowest-index held stack its recipe matches, refusing when that stack would
  pass 30,000 or the item's stack limit for `kind`; there is never a spill into
  a second slot. Otherwise the item takes the lowest free index. A
  non-stackable item added with `amount` above one takes one slot holding all
  of them; callers that grant one copy per slot loop.

  - Inventory: invalid amount, over 30,000, stack limit, weight, then the
    merge on name, binding, unique id and cards into a stack with no expiry
    (an equipped stack included; an expiring item never merges); a new slot
    is unequipped and not a favourite.
  - Cart: invalid amount, stack limit, the item's or a card's cart
    restriction or any binding past account, weight, then the merge on name,
    binding, unique id and cards (an expiring item never merges); a new slot
    is not a favourite.
  - Storage: invalid amount, stack limit, storage restriction, binding past
    account, then the merge on every stored attribute; a new slot copies the
    item.
  - Guild storage: invalid amount, stack limit, guild storage restriction or
    any expiry, account binding or binding past guild, then as storage.
  """
  @spec put(t(), kind(), ItemDefinition.t(), InventoryItem.t(), integer(), room()) ::
          {:ok, t(), change()} | {:error, add_error()}
  def put(container, kind, %ItemDefinition{} = item_def, %InventoryItem{} = item, amount, room)
      when is_map(container) and is_integer(amount) do
    with :ok <- check(kind, item_def, item, amount, room) do
      container
      |> merge_index(kind, item_def, item)
      |> place(container, kind, item_def, item, amount, room.capacity)
    end
  end

  @doc """
  Builds the item a fresh grant of `item_def` adds, from optional attributes.

  Unset attributes take their defaults: identified, unrefined, no cards,
  unbound, no expiry.
  """
  @spec new_item(ItemDefinition.t(), map()) :: InventoryItem.t()
  def new_item(%ItemDefinition{} = item_def, opts \\ %{}) do
    %InventoryItem{
      nameid: item_def.id,
      amount: 0,
      equip: 0,
      identify: Map.get(opts, :identify, 1),
      refine: Map.get(opts, :refine, 0),
      attribute: Map.get(opts, :attribute, 0),
      card0: Map.get(opts, :card0, 0),
      card1: Map.get(opts, :card1, 0),
      card2: Map.get(opts, :card2, 0),
      card3: Map.get(opts, :card3, 0),
      random_options: Map.get(opts, :random_options, []),
      craft: Map.get(opts, :craft),
      bound: Map.get(opts, :bound, 0),
      favorite: Map.get(opts, :favorite, 0),
      unique_id: Map.get(opts, :unique_id, 0),
      enchant_grade: Map.get(opts, :enchant_grade, 0),
      expire_time: Map.get(opts, :expire_time)
    }
  end

  @doc """
  Whether `item` or a card in its slots carries the restriction `flag`
  (`:no_cart`, `:no_storage` or `:no_guild_storage`).

  Cards are read only for a slotted item that is not crafted, and only within
  the item's slot count.
  """
  @spec restricted?(InventoryItem.t(), ItemDefinition.t(), atom()) :: boolean()
  def restricted?(%InventoryItem{} = item, %ItemDefinition{} = item_def, flag) do
    Map.fetch!(item_def, flag) or card_restricted?(item, item_def, flag)
  end

  defp card_restricted?(_item, %ItemDefinition{slots: 0}, _flag), do: false

  defp card_restricted?(%InventoryItem{craft: craft}, _item_def, _flag) when craft != nil,
    do: false

  defp card_restricted?(item, %ItemDefinition{slots: slots}, flag) do
    item
    |> InventoryItem.cards()
    |> Enum.take(slots)
    |> Enum.reject(&(&1 in [0, nil]))
    |> Enum.any?(fn card_id ->
      case ItemManagement.get_item_by_id(card_id) do
        {:ok, card_def} -> Map.fetch!(card_def, flag)
        {:error, _reason} -> false
      end
    end)
  end

  defp check(:inventory, item_def, _item, amount, room) do
    cond do
      amount <= 0 -> {:error, :invalid}
      amount > @max_stack -> {:error, :over_amount}
      over_limit?(item_def, :inventory, amount) -> {:error, :stack_limit}
      overweight?(item_def, amount, room) -> {:error, :overweight}
      true -> :ok
    end
  end

  defp check(:cart, item_def, item, amount, room) do
    cond do
      amount <= 0 -> {:error, :invalid}
      over_limit?(item_def, :cart, amount) -> {:error, :stack_limit}
      restricted?(item, item_def, :no_cart) or item.bound > 1 -> {:error, :restricted}
      overweight?(item_def, amount, room) -> {:error, :overweight}
      true -> :ok
    end
  end

  defp check(:storage, item_def, item, amount, _room) do
    cond do
      amount <= 0 -> {:error, :invalid}
      over_limit?(item_def, :storage, amount) -> {:error, :storage_full}
      restricted?(item, item_def, :no_storage) -> {:error, :restricted}
      item.bound > 1 -> {:error, :bound}
      true -> :ok
    end
  end

  defp check(:guild_storage, item_def, item, amount, _room) do
    cond do
      amount <= 0 -> {:error, :invalid}
      over_limit?(item_def, :guild_storage, amount) -> {:error, :storage_full}
      restricted?(item, item_def, :no_guild_storage) -> {:error, :restricted}
      item.expire_time != nil -> {:error, :restricted}
      item.bound == 1 or item.bound > 2 -> {:error, :bound}
      true -> :ok
    end
  end

  defp over_limit?(item_def, kind, amount) do
    case ItemDefinition.stack_limit(item_def, kind) do
      nil -> false
      limit -> amount > limit
    end
  end

  defp overweight?(_item_def, _amount, %{weight: :infinity}), do: false
  defp overweight?(item_def, amount, %{weight: room}), do: item_def.weight * amount > room

  defp merge_index(container, kind, item_def, item) do
    if ItemDefinition.stackable?(item_def) and mergeable?(kind, item) do
      container
      |> Enum.filter(fn {_index, held} -> same_stack?(kind, held, item) end)
      |> Enum.map(&elem(&1, 0))
      |> Enum.min(fn -> nil end)
    end
  end

  defp mergeable?(kind, item) when kind in [:inventory, :cart], do: item.expire_time == nil
  defp mergeable?(_kind, _item), do: true

  defp same_stack?(:inventory, held, item),
    do: held.expire_time == nil and same_identity?(held, item)

  defp same_stack?(:cart, held, item), do: same_identity?(held, item)

  defp same_stack?(_storage, held, item) do
    same_identity?(held, item) and held.identify == item.identify and
      held.refine == item.refine and held.attribute == item.attribute and
      same_expiry?(held.expire_time, item.expire_time)
  end

  defp same_identity?(held, item) do
    held.nameid == item.nameid and held.bound == item.bound and
      held.unique_id == item.unique_id and InventoryItem.cards(held) == InventoryItem.cards(item) and
      held.craft == item.craft
  end

  defp same_expiry?(nil, nil), do: true
  defp same_expiry?(nil, _other), do: false
  defp same_expiry?(_held, nil), do: false
  defp same_expiry?(held, item), do: NaiveDateTime.compare(held, item) == :eq

  defp place(nil, container, kind, item_def, item, amount, capacity) do
    index = lowest_free_index(container)

    if index >= capacity do
      {:error, no_slot(kind)}
    else
      new_item = %{slot_copy(kind, item_def, item) | amount: amount}
      {:ok, put_item(container, index, new_item), {:added, index, new_item}}
    end
  end

  defp place(index, container, kind, item_def, _item, amount, capacity) do
    held = Map.fetch!(container, index)
    limit = ItemDefinition.stack_limit(item_def, kind)

    cond do
      amount > @max_stack - held.amount -> {:error, full_stack(kind)}
      limit != nil and amount > limit - held.amount -> {:error, full_stack(kind)}
      kind == :inventory and index >= capacity -> {:error, :over_amount}
      true -> stack(container, index, held, amount)
    end
  end

  defp stack(container, index, held, amount) do
    total = held.amount + amount
    {:ok, put_item(container, index, %{held | amount: total}), {:stacked, index, total}}
  end

  defp no_slot(:inventory), do: :inventory_full
  defp no_slot(:cart), do: :over_amount
  defp no_slot(_storage), do: :storage_full

  defp full_stack(kind) when kind in [:inventory, :cart], do: :over_amount
  defp full_stack(_storage), do: :storage_full

  defp slot_copy(kind, item_def, item) do
    copy = %InventoryItem{
      nameid: item_def.id,
      amount: 0,
      equip: item.equip,
      identify: item.identify,
      refine: item.refine,
      attribute: item.attribute,
      card0: item.card0,
      card1: item.card1,
      card2: item.card2,
      card3: item.card3,
      random_options: item.random_options,
      craft: item.craft,
      bound: item.bound,
      favorite: item.favorite,
      unique_id: item.unique_id,
      enchant_grade: item.enchant_grade,
      expire_time: item.expire_time
    }

    case kind do
      :inventory -> %{copy | equip: 0, favorite: 0}
      :cart -> %{copy | favorite: 0}
      _storage -> copy
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
  Identifies the item at `index`.
  """
  @spec identify(t(), non_neg_integer()) :: op_result()
  def identify(container, index) when is_map(container) do
    case Map.get(container, index) do
      nil ->
        {:error, :not_found}

      %InventoryItem{identify: 1} ->
        {:error, :already_identified}

      %InventoryItem{} = item ->
        {:ok, put_item(container, index, %{item | identify: 1}), {:identified, index}}
    end
  end

  @doc """
  Total quantity of item `nameid` held across all slots.

  Matches by item id regardless of equipment, cards, random options or craft
  metadata. This is a possession lookup, not a stack-merge check.
  """
  @spec held_amount(t(), integer()) :: non_neg_integer()
  def held_amount(container, nameid) when is_map(container) do
    Enum.reduce(container, 0, fn {_index, item}, acc ->
      if item.nameid == nameid, do: acc + item.amount, else: acc
    end)
  end

  @doc """
  Lowest index holding a positive amount of item `nameid`, or `nil` when absent.

  Matches by item id only, including equipped and crafted copies.
  """
  @spec stackable_index(t(), integer()) :: non_neg_integer() | nil
  def stackable_index(container, nameid) when is_map(container) do
    container
    |> Enum.filter(fn {_index, item} -> item.nameid == nameid and item.amount > 0 end)
    |> Enum.map(&elem(&1, 0))
    |> Enum.min(fn -> nil end)
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

  @doc "Returns the session indices an add-type `change` touched."
  @spec affected_indices(change()) :: [non_neg_integer()]
  def affected_indices({:added, index, _item}), do: [index]
  def affected_indices({:stacked, index, _total}), do: [index]

  @doc "Returns the session index a remove-type `change` touched."
  @spec removal_index(change()) :: non_neg_integer()
  def removal_index({:removed, index}), do: index
  def removal_index({:reduced, index, _left}), do: index
end
