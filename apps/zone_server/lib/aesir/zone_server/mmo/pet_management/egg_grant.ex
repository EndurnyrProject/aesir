defmodule Aesir.ZoneServer.Mmo.PetManagement.EggGrant do
  @moduledoc """
  Creates a pet and its identified egg for one fresh egg grant (rAthena
  `pet_create_egg`, `pet.cpp:668-688`, and `pet_get_egg`).

  `:not_egg` (no pet hatches from the item, or its mob is unknown) and
  `:no_slot` (no free inventory slot) are the reference's pre-checks, after
  which the callers that test the result add the plain item instead. Any later
  refusal (`:overweight`) leaves no pet row and is terminal for that egg.
  """

  alias Aesir.ZoneServer.Mmo.MobManagement.Mobs
  alias Aesir.ZoneServer.Mmo.PetManagement.Catalog
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Pet.Persistence

  @doc "Grants one fresh pet egg, or reports why it could not be created."
  @spec grant(pos_integer(), pos_integer(), pos_integer(), Inventory.t(), integer() | :infinity) ::
          {:ok, Inventory.t()} | {:error, :not_egg | :no_slot | term()}
  def grant(item_id, account_id, character_id, inventory, weight_room) do
    with {:ok, definition} <- Catalog.by_egg(item_id),
         {:ok, mob} <- Mobs.by_id(definition.mob_id),
         true <- Inventory.blank_slots(inventory) > 0,
         {:ok, inventory, _pet} <-
           Persistence.create_with_egg(
             account_id,
             character_id,
             definition,
             mob,
             inventory,
             weight_room
           ) do
      {:ok, inventory}
    else
      :error -> {:error, :not_egg}
      false -> {:error, :no_slot}
      {:error, reason} -> {:error, reason}
    end
  end
end
