defmodule Aesir.ZoneServer.Unit.Pet.Handlers.AccessoryHandler do
  @moduledoc """
  Equips and removes a pet's accessory together with its owner's inventory.

  Every change is saved with the inventory before the owner and the area are
  told; a failed save leaves the session unchanged, and a failed equip save
  answers the owner with the equip failure.
  """

  require Logger

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Commons.Models.Pet
  alias Aesir.Net.EquipResult
  alias Aesir.Net.PetStateChange
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.PetManagement.Catalog
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Pet.Persistence
  alias Aesir.ZoneServer.Unit.Pet.PetState
  alias Aesir.ZoneServer.Unit.Pet.SpawnView
  alias Aesir.ZoneServer.Unit.Pet.StateCommit
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryManager
  alias Aesir.ZoneServer.Unit.Player.InventoryView
  alias Aesir.ZoneServer.Unit.Player.PlayerEvents
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Player.StateCommit, as: PlayerStateCommit

  @equip_fail 2

  @doc """
  Equips the inventory item at server `index` on the pet. An index outside the
  inventory is ignored. The item must be the species' accessory (non-zero) and
  the pet must wear none, else the owner gets the equip failure. One item is
  consumed, `equip` is set and ACCESSORY goes to the area.
  """
  @spec equip(SessionState.t(), integer()) :: SessionState.t()
  def equip(%SessionState{pet: %PetState{} = pet, game_state: owner} = session, index)
      when index >= 0 do
    {:ok, definition} = Catalog.by_mob(pet.class_id)

    with %InventoryItem{nameid: id} when id != 0 <- Map.get(owner.inventory, index),
         true <- id == definition.equip_item_id and pet.equip == 0 do
      {:ok, inventory, _change} = Inventory.remove(owner.inventory, index, 1)

      case persist(session, inventory, id) do
        {:ok, session} ->
          MessageRouter.send_to(session.connection_pid, InventoryView.item_removed(index, 1))
          PlayerEvents.inventory_changed(owner.character_id)
          broadcast_accessory(session)

        :error ->
          equip_failed(session, index)
      end
    else
      _invalid ->
        if index < Inventory.capacity(), do: equip_failed(session, index), else: session
    end
  end

  def equip(%SessionState{} = session, _index), do: session

  @doc """
  Returns the pet's accessory to the inventory; nothing equipped does nothing.
  When the add fails the owner sees the add error and the accessory is
  destroyed if `pet_unequip_destroy` is on, else the pet keeps it. Then
  `equip` is cleared and ACCESSORY goes to the area.
  """
  @spec unequip(SessionState.t()) :: SessionState.t()
  def unequip(%SessionState{pet: %PetState{equip: 0}} = session), do: session

  def unequip(%SessionState{pet: %PetState{} = pet, game_state: owner} = session) do
    {:ok, item} = ItemManagement.get_item_by_id(pet.equip)
    room = Inventory.weight_room(owner.inventory, owner.stats)

    case Inventory.add(owner.inventory, item, 1, %{}, room) do
      {:ok, inventory, change} ->
        case persist(session, inventory, 0) do
          {:ok, session} ->
            InventoryManager.notify_added(
              session.connection_pid,
              session.game_state.inventory,
              change
            )

            PlayerEvents.inventory_changed(owner.character_id)
            broadcast_accessory(session)

          :error ->
            session
        end

      {:error, reason} ->
        InventoryManager.notify_add_failed(session.connection_pid, reason)
        if Config.pet_unequip_destroy?(), do: destroy(session), else: session
    end
  end

  defp destroy(%SessionState{game_state: owner} = session) do
    case persist(session, owner.inventory, 0) do
      {:ok, session} -> broadcast_accessory(session)
      :error -> session
    end
  end

  defp persist(%SessionState{pet: pet, game_state: owner} = session, inventory, equip) do
    with %Pet{} = row <- Persistence.load(pet.pet_id),
         {:ok, inventory, _row} <-
           Persistence.save_with_inventory(
             row,
             %{equip: equip},
             owner.character_id,
             owner.inventory,
             inventory
           ) do
      session = PlayerStateCommit.commit(session, %{owner | inventory: inventory})
      {:ok, StateCommit.commit(session, %{pet | equip: equip})}
    else
      failure ->
        Logger.error("Failed to save pet #{pet.pet_id}: #{inspect(failure)}")
        :error
    end
  end

  defp equip_failed(session, index) do
    MessageRouter.send_to(session.connection_pid, %EquipResult{
      index: PlayerState.client_index(index),
      result: @equip_fail
    })

    session
  end

  defp broadcast_accessory(%SessionState{pet: pet} = session) do
    Broadcast.to_in_range(pet.map_name, pet.x, pet.y, Config.view_range(), %PetStateChange{
      gid: pet.world_gid,
      type: :PET_STATE_ACCESSORY,
      value: SpawnView.accessory_view(pet.equip)
    })

    session
  end
end
