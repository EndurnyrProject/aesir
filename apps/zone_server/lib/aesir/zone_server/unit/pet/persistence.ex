defmodule Aesir.ZoneServer.Unit.Pet.Persistence do
  @moduledoc "Synchronous atomic persistence for pets and their inventory."

  import Ecto.Query

  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Commons.Models.Pet
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.PetManagement.Egg
  alias Aesir.ZoneServer.Mmo.PetManagement.PetDefinition
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Ecto.Multi

  @type result :: {:ok, Inventory.t(), Pet.t()} | {:error, term()}

  @doc "Loads a pet by its id."
  @spec load(pos_integer()) :: Pet.t() | nil
  def load(id), do: Repo.get(Pet, id)

  @doc "Creates a pet and its egg in one transaction."
  @spec create_with_egg(
          pos_integer(),
          pos_integer(),
          PetDefinition.t(),
          MobDefinition.t(),
          Inventory.t(),
          integer() | :infinity
        ) :: {:ok, Inventory.t(), Pet.t()} | {:error, atom() | Ecto.Changeset.t()}
  def create_with_egg(_account_id, character_id, definition, mob, inventory, weight_room) do
    attrs = %{
      class: definition.mob_id,
      name: mob.name,
      account_id: 0,
      char_id: 0,
      level: mob.level,
      egg_id: definition.egg_item_id,
      intimate: definition.intimacy_start,
      hungry: 100,
      rename_flag: 0,
      incubate: 1
    }

    Multi.new()
    |> Multi.insert(:pet, Pet.changeset(%Pet{}, attrs))
    |> Multi.run(:inventory, fn _repo, %{pet: pet} ->
      with {:ok, item} <- ItemManagement.get_item_by_id(pet.egg_id),
           {:ok, new_inventory, change} <-
             Inventory.add(inventory, item, 1, Egg.egg_attrs(pet.id, pet.intimate), weight_room) do
        InventoryOps.persist_change(character_id, inventory, new_inventory, change)
      end
    end)
    |> transact()
  end

  @doc "Hatches the matching egg and attaches the pet to its owner."
  @spec hatch(Pet.t(), pos_integer(), pos_integer(), Inventory.t()) :: result()
  def hatch(pet, account_id, character_id, inventory) do
    transition(
      pet,
      character_id,
      inventory,
      %{incubate: 0, account_id: account_id, char_id: character_id},
      1,
      pet.id
    )
  end

  @doc """
  Returns a pet to its matching egg, saving `attrs` (the live pet fields) with
  the transition.
  """
  @spec return_to_egg(Pet.t(), pos_integer(), Inventory.t(), map()) :: result()
  def return_to_egg(pet, character_id, inventory, attrs \\ %{}) do
    transition(pet, character_id, inventory, Map.put(attrs, :incubate, 1), 0, 0)
  end

  defp transition(pet, character_id, inventory, attrs, attribute, pet_id) do
    case Egg.find(inventory, pet.id) do
      {:ok, egg} -> transition_egg(pet, character_id, inventory, attrs, attribute, pet_id, egg)
      :error -> {:error, :egg_missing}
    end
  end

  defp transition_egg(pet, character_id, inventory, attrs, attribute, pet_id, egg) do
    {index, _} = Enum.find(inventory, fn {_index, item} -> item.id == egg.id end)
    next = Map.put(inventory, index, %{egg | attribute: attribute})

    Multi.new()
    |> inventory_change(character_id, inventory, next)
    |> Multi.update(:pet, Pet.changeset(pet, attrs))
    |> Multi.run(:character, fn repo, _ -> update_character(repo, character_id, pet_id) end)
    |> transact()
  end

  defp update_character(repo, character_id, pet_id) do
    case repo.update_all(from(c in Character, where: c.id == ^character_id),
           set: [pet_id: pet_id]
         ) do
      {1, _} -> {:ok, :updated}
      {0, _} -> {:error, :character_missing}
    end
  end

  @doc """
  Points the character at `pet_id`, restoring the link to a hatched pet it
  owns.
  """
  @spec link(pos_integer(), pos_integer()) :: :ok | {:error, :character_missing}
  def link(pet_id, character_id) do
    with {:ok, :updated} <- update_character(Repo, character_id, pet_id), do: :ok
  end

  @doc "Saves pet attributes."
  @spec save(Pet.t(), map()) :: {:ok, Pet.t()} | {:error, Ecto.Changeset.t()}
  def save(pet, attrs), do: pet |> Pet.changeset(attrs) |> Repo.update()

  @doc "Saves pet attributes and inventory changes atomically."
  @spec save_with_inventory(Pet.t(), map(), pos_integer(), Inventory.t(), Inventory.t()) ::
          result()
  def save_with_inventory(pet, attrs, character_id, old, new) do
    Multi.new()
    |> inventory_change(character_id, old, new)
    |> Multi.update(:pet, Pet.changeset(pet, attrs))
    |> transact()
  end

  @doc """
  Clears the character's reference to `pet_id`, if it still points at it, and
  applies the inventory change from `old` to `new` in the same transaction.
  """
  @spec unlink(pos_integer(), pos_integer(), Inventory.t(), Inventory.t()) ::
          {:ok, Inventory.t()} | {:error, term()}
  def unlink(pet_id, character_id, old, new) do
    Multi.new()
    |> inventory_change(character_id, old, new)
    |> Multi.update_all(:character, unlink_query(pet_id, character_id), set: [pet_id: 0])
    |> Repo.transact()
    |> case do
      {:ok, %{inventory: inventory}} -> {:ok, inventory}
      {:error, _operation, reason, _changes} -> {:error, reason}
    end
  end

  @doc "Deletes a pet and clears its character's reference if it matches."
  @spec delete(pos_integer(), pos_integer() | nil) :: :ok
  def delete(pet_id, character_id) do
    Multi.new()
    |> Multi.delete_all(:pet, from(p in Pet, where: p.id == ^pet_id))
    |> Multi.run(:character, fn repo, _ ->
      if character_id do
        repo.update_all(unlink_query(pet_id, character_id), set: [pet_id: 0])
      end

      {:ok, :updated}
    end)
    |> Repo.transact()
    |> case do
      {:ok, _} ->
        :ok

      {:error, operation, reason, _} ->
        raise "pet deletion failed at #{operation}: #{inspect(reason)}"
    end
  end

  defp unlink_query(pet_id, character_id),
    do: from(c in Character, where: c.id == ^character_id and c.pet_id == ^pet_id)

  defp inventory_change(multi, character_id, old, new) do
    Multi.run(multi, :inventory, fn _repo, _changes ->
      indices = (Map.keys(old) ++ Map.keys(new)) |> Enum.uniq()

      Enum.reduce_while(indices, {:ok, new}, fn index, {:ok, current} ->
        persist_inventory_slot(character_id, old, current, index)
      end)
    end)
  end

  defp persist_inventory_slot(character_id, old, current, index) do
    before = Map.get(old, index)
    after_item = Map.get(current, index)

    case persist_slot(character_id, old, current, index, before, after_item) do
      {:ok, persisted} -> {:cont, {:ok, persisted}}
      {:error, reason} -> {:halt, {:error, reason}}
    end
  end

  defp persist_slot(
         character_id,
         old,
         current,
         index,
         %InventoryItem{id: old_id},
         %InventoryItem{id: new_id} = item
       )
       when old_id != new_id do
    with {:ok, inventory} <-
           InventoryOps.persist_change(character_id, old, current, {:removed, index}) do
      InventoryOps.persist_change(character_id, old, inventory, {:added, index, item})
    end
  end

  defp persist_slot(character_id, old, current, index, before, after_item) do
    case inventory_change_descriptor(before, after_item, index) do
      nil -> {:ok, current}
      descriptor -> InventoryOps.persist_change(character_id, old, current, descriptor)
    end
  end

  defp inventory_change_descriptor(nil, nil, _index), do: nil
  defp inventory_change_descriptor(nil, item, index), do: {:added, index, item}
  defp inventory_change_descriptor(_item, nil, index), do: {:removed, index}
  defp inventory_change_descriptor(item, item, _index), do: nil

  defp inventory_change_descriptor(_old, new, index) do
    fields = InventoryItem.__schema__(:fields) -- [:id, :char_id, :inserted_at, :updated_at]
    {:updated, index, Map.take(Map.from_struct(new), fields)}
  end

  defp transact(multi) do
    case Repo.transact(multi) do
      {:ok, %{pet: pet, inventory: inventory}} -> {:ok, inventory, pet}
      {:error, _operation, reason, _changes} -> {:error, reason}
    end
  end
end
