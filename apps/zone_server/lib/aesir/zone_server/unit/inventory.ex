defmodule Aesir.ZoneServer.Unit.Inventory do
  @moduledoc """
  Inventory management for character items in the zone server.

  Handles:
  - Loading character inventory from database
  - Item manipulation (add, remove, move)
  - Equipment management
  - Inventory synchronization with client
  """

  import Ecto.Query
  require Logger

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Repo

  @max_inventory 100
  @max_stack 30_000

  @type inventory_slot :: non_neg_integer()
  @type item_result :: {:ok, InventoryItem.t()} | {:error, atom()}
  @type inventory_result :: {:ok, [InventoryItem.t()]} | {:error, atom()}

  @doc """
  Loads a character's complete inventory from the database.
  """
  @spec load_inventory(integer()) :: inventory_result()
  def load_inventory(char_id) do
    items =
      InventoryItem
      |> where([i], i.char_id == ^char_id)
      |> order_by([i], i.id)
      |> Repo.all()

    {:ok, items}
  rescue
    error ->
      Logger.error("Failed to load inventory for char_id #{char_id}: #{inspect(error)}")
      {:error, :inventory_load_failed}
  end

  @doc """
  Adds an item to the character's inventory.
  Automatically handles stacking for stackable items.
  """
  @spec add_item(integer(), integer(), integer(), map()) :: item_result()
  def add_item(char_id, nameid, amount, opts \\ %{}) do
    with {:ok, existing_items} <- load_inventory(char_id),
         :ok <- validate_inventory_space(existing_items, amount),
         {:ok, item} <- create_or_update_item(char_id, nameid, amount, existing_items, opts) do
      {:ok, item}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Removes an item or reduces its amount from the inventory.
  """
  @spec remove_item(integer(), integer(), integer()) :: item_result()
  def remove_item(char_id, item_id, amount) do
    with {:ok, item} <- get_item(char_id, item_id),
         :ok <- validate_removal(item, amount) do
      if item.amount <= amount do
        # Remove entire item
        case Repo.delete(item) do
          {:ok, deleted_item} ->
            {:ok, deleted_item}

          {:error, changeset} ->
            Logger.error("Failed to delete item #{item_id}: #{inspect(changeset.errors)}")
            {:error, :item_delete_failed}
        end
      else
        # Reduce amount
        changeset = InventoryItem.changeset(item, %{amount: item.amount - amount})

        case Repo.update(changeset) do
          {:ok, updated_item} ->
            {:ok, updated_item}

          {:error, changeset} ->
            Logger.error("Failed to update item #{item_id}: #{inspect(changeset.errors)}")
            {:error, :item_update_failed}
        end
      end
    end
  end

  @doc """
  Gets a specific item from character's inventory.
  """
  @spec get_item(integer(), integer()) :: item_result()
  def get_item(char_id, item_id) do
    case Repo.get_by(InventoryItem, id: item_id, char_id: char_id) do
      nil -> {:error, :item_not_found}
      item -> {:ok, item}
    end
  end

  @doc """
  Equips an item to a specific equipment slot.
  """
  @spec equip_item(integer(), integer(), integer()) :: item_result()
  def equip_item(char_id, item_id, equip_position) do
    with {:ok, item} <- get_item(char_id, item_id),
         :ok <- validate_equipment(item, equip_position),
         :ok <- unequip_conflicting_items(char_id, equip_position) do
      changeset = InventoryItem.changeset(item, %{equip: equip_position})

      case Repo.update(changeset) do
        {:ok, updated_item} ->
          {:ok, updated_item}

        {:error, changeset} ->
          Logger.error("Failed to equip item #{item_id}: #{inspect(changeset.errors)}")
          {:error, :equip_failed}
      end
    end
  end

  @doc """
  Unequips an item from its current equipment slot.
  """
  @spec unequip_item(integer(), integer()) :: item_result()
  def unequip_item(char_id, item_id) do
    with {:ok, item} <- get_item(char_id, item_id) do
      changeset = InventoryItem.changeset(item, %{equip: 0})

      case Repo.update(changeset) do
        {:ok, updated_item} ->
          {:ok, updated_item}

        {:error, changeset} ->
          Logger.error("Failed to unequip item #{item_id}: #{inspect(changeset.errors)}")
          {:error, :unequip_failed}
      end
    end
  end

  @doc """
  Gets all equipped items for a character.
  """
  @spec get_equipped_items(integer()) :: inventory_result()
  def get_equipped_items(char_id) do
    items =
      InventoryItem
      |> where([i], i.char_id == ^char_id and i.equip > 0)
      |> Repo.all()

    {:ok, items}
  rescue
    error ->
      Logger.error("Failed to load equipped items for char_id #{char_id}: #{inspect(error)}")
      {:error, :equipped_items_load_failed}
  end

  @doc """
  Generates a unique ID for a new item.
  """
  @spec generate_unique_id(integer()) :: integer()
  def generate_unique_id(char_id) do
    # Simple unique ID generation - in production, consider using a proper UUID or sequence
    :os.system_time(:microsecond) + char_id
  end

  # Private functions

  defp validate_inventory_space(existing_items, _amount) do
    if length(existing_items) >= @max_inventory do
      {:error, :inventory_full}
    else
      :ok
    end
  end

  defp create_or_update_item(char_id, nameid, amount, existing_items, opts) do
    # Try to find existing stackable item
    existing_item = find_stackable_item(existing_items, nameid)

    if existing_item && can_stack?(existing_item, amount) do
      # Stack with existing item
      new_amount = existing_item.amount + amount
      changeset = InventoryItem.changeset(existing_item, %{amount: new_amount})

      case Repo.update(changeset) do
        {:ok, updated_item} ->
          {:ok, updated_item}

        {:error, changeset} ->
          Logger.error("Failed to stack item #{nameid}: #{inspect(changeset.errors)}")
          {:error, :item_stack_failed}
      end
    else
      # Create new item
      item_attrs = %{
        char_id: char_id,
        nameid: nameid,
        amount: amount,
        unique_id: generate_unique_id(char_id),
        identify: Map.get(opts, :identify, 1),
        refine: Map.get(opts, :refine, 0),
        attribute: Map.get(opts, :attribute, 0),
        card0: Map.get(opts, :card0, 0),
        card1: Map.get(opts, :card1, 0),
        card2: Map.get(opts, :card2, 0),
        card3: Map.get(opts, :card3, 0),
        random_options: Map.get(opts, :random_options, %{}),
        bound: Map.get(opts, :bound, 0),
        favorite: Map.get(opts, :favorite, 0)
      }

      changeset = InventoryItem.changeset(%InventoryItem{}, item_attrs)

      case Repo.insert(changeset) do
        {:ok, new_item} ->
          {:ok, new_item}

        {:error, changeset} ->
          Logger.error("Failed to create item #{nameid}: #{inspect(changeset.errors)}")
          {:error, :item_create_failed}
      end
    end
  end

  defp find_stackable_item(items, nameid) do
    Enum.find(items, fn item ->
      item.nameid == nameid &&
        item.equip == 0 &&
        item.card0 == 0 && item.card1 == 0 && item.card2 == 0 && item.card3 == 0 &&
        map_size(item.random_options) == 0
    end)
  end

  defp can_stack?(item, additional_amount) do
    item.amount + additional_amount <= @max_stack
  end

  defp validate_removal(item, amount) do
    if item.amount >= amount do
      :ok
    else
      {:error, :insufficient_amount}
    end
  end

  defp validate_equipment(_item, _equip_position) do
    # TODO: Add proper equipment validation (job requirements, item type, etc.)
    :ok
  end

  defp unequip_conflicting_items(char_id, equip_position) do
    # TODO: Implement logic to unequip items that conflict with new equipment
    # For now, just allow it
    _ = char_id
    _ = equip_position
    :ok
  end
end
