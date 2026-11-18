defmodule Aesir.ZoneServer.Unit.Pet.Handlers.EvolutionHandler do
  @moduledoc """
  Pet evolution: a Loyal pet wearing no accessory turns into a species its
  pet entry lists, spending that evolution's materials, and its egg becomes
  the new species' egg in place.

  The pet keeps its world id, level and the mob entry it came out with
  (`PetState.mob_db_id`) until it next comes out.
  """

  require Logger

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Commons.Models.Pet
  alias Aesir.Net.PetStateChange
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Mmo.MobManagement.Mobs
  alias Aesir.ZoneServer.Mmo.PetManagement.Catalog
  alias Aesir.ZoneServer.Mmo.PetManagement.Egg
  alias Aesir.ZoneServer.Mmo.PetManagement.PetDefinition
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Emote
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Pet.Handlers.HungerHandler
  alias Aesir.ZoneServer.Unit.Pet.Handlers.LifecycleHandler
  alias Aesir.ZoneServer.Unit.Pet.Handlers.MovementHandler
  alias Aesir.ZoneServer.Unit.Pet.Persistence
  alias Aesir.ZoneServer.Unit.Pet.PetState
  alias Aesir.ZoneServer.Unit.Pet.SpawnView
  alias Aesir.ZoneServer.Unit.Pet.StateCommit
  alias Aesir.ZoneServer.Unit.Player.Handlers.EquipmentHandler
  alias Aesir.ZoneServer.Unit.Player.InventoryView
  alias Aesir.ZoneServer.Unit.Player.PlayerEvents
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Player.StateCommit, as: PlayerStateCommit
  alias Aesir.ZoneServer.Unit.SpecialEffect

  @intimate_loyal 910

  @typedoc "The evolution outcome, carried by the request's `PetResult`."
  @type result :: {:ok, :PET_ERROR_EVOLUTION_SUCCESS} | {:error, atom()}

  @doc """
  Evolves the pet into the species hatched from `egg_item_id`.

  Refused, changing nothing, in this order: an item that is no pet's egg
  (`FAIL_NOT_PETEGG`); no pet out or `feature_pet_evolution` off
  (`FAIL_UNKNOWN`); intimacy below Loyal or an accessory worn
  (`FAIL_RG_FAMILIAR`); a species the pet does not evolve into
  (`FAIL_NOTEXIST_CALLPET`); fewer materials than required, counted over all
  stacks (`FAIL_MATERIAL`).

  Then the materials are spent: for each requirement every matching stack in
  slot order loses up to the full required amount until exactly nothing is
  owed, so an overshoot keeps taking later stacks. With no pet entry for the
  new species nothing else happens; with the pet's egg gone the answer is
  `FAIL_NOTEXIST_CALLPET`. Otherwise the egg becomes the new species' egg,
  the pet leaves sight, takes the new class and egg (and the new mob's name
  when never renamed), its intimacy is set to the new species'
  `intimacy_start`, and it reappears: INIT and the status to the owner,
  ACCESSORY to the area, the owner's `best` emotion, `EF_HO_UP` on the pet,
  and the whole inventory to the owner.
  """
  @spec evolve(SessionState.t(), non_neg_integer()) :: {result(), SessionState.t()}
  def evolve(%SessionState{} = session, egg_item_id) do
    with {:ok, target} <- requested_species(egg_item_id),
         {:ok, pet} <- evolvable(session),
         {:ok, requirements} <- requirements(pet, target),
         :ok <- materials_held(session.game_state.inventory, requirements) do
      session
      |> spend(requirements)
      |> morph(target)
    else
      {:error, error} -> {{:error, error}, session}
    end
  end

  defp requested_species(egg_item_id) do
    case Catalog.by_egg(egg_item_id) do
      {:ok, %PetDefinition{mob_id: mob_id}} -> {:ok, mob_id}
      :error -> {:error, :PET_ERROR_EVOLUTION_FAIL_NOT_PETEGG}
    end
  end

  defp evolvable(%SessionState{pet: nil}), do: {:error, :PET_ERROR_EVOLUTION_FAIL_UNKNOWN}

  defp evolvable(%SessionState{pet: %PetState{} = pet}) do
    cond do
      not Config.feature_pet_evolution?() -> {:error, :PET_ERROR_EVOLUTION_FAIL_UNKNOWN}
      pet.intimate < @intimate_loyal -> {:error, :PET_ERROR_EVOLUTION_FAIL_RG_FAMILIAR}
      pet.equip != 0 -> {:error, :PET_ERROR_EVOLUTION_FAIL_RG_FAMILIAR}
      true -> {:ok, pet}
    end
  end

  defp requirements(%PetState{class_id: class_id}, target) do
    {:ok, definition} = Catalog.by_mob(class_id)

    case Enum.find(definition.evolution, &(&1.target_mob_id == target)) do
      %{requirements: requirements} -> {:ok, requirements}
      nil -> {:error, :PET_ERROR_EVOLUTION_FAIL_NOTEXIST_CALLPET}
    end
  end

  defp materials_held(inventory, requirements) do
    if Enum.all?(requirements, &(Inventory.held_amount(inventory, &1.item_id) >= &1.amount)),
      do: :ok,
      else: {:error, :PET_ERROR_EVOLUTION_FAIL_MATERIAL}
  end

  # Takes off every worn row that loses its whole stack, then returns the
  # session with the removals still to save.
  defp spend(%SessionState{game_state: owner} = session, requirements) do
    removals = removals(owner.inventory, requirements)

    session =
      Enum.reduce(removals, session, fn {index, amount}, session ->
        take_off(session, index, amount)
      end)

    {session, removals}
  end

  defp removals(inventory, requirements) do
    slots = Enum.sort_by(inventory, &elem(&1, 0))

    Enum.flat_map(requirements, fn %{item_id: item_id, amount: amount} ->
      slots
      |> Enum.filter(fn {_index, item} -> item.nameid == item_id end)
      |> take_stacks(amount, amount)
    end)
  end

  # Each stack loses up to the full `amount`; only an owed count of exactly 0
  # stops the walk.
  defp take_stacks([], _amount, _owed), do: []

  defp take_stacks([{index, item} | rest], amount, owed) do
    deduction = min(amount, item.amount)

    case owed - deduction do
      0 -> [{index, deduction}]
      owed -> [{index, deduction} | take_stacks(rest, amount, owed)]
    end
  end

  defp take_off(%SessionState{game_state: owner} = session, index, amount) do
    case Map.fetch!(owner.inventory, index) do
      %InventoryItem{equip: equip, amount: ^amount} when equip != 0 ->
        {:noreply, session} = EquipmentHandler.force_unequip(index, session)
        session

      %InventoryItem{} ->
        session
    end
  end

  defp morph({%SessionState{pet: pet, game_state: owner} = session, removals}, target) do
    inventory = remove(owner.inventory, removals)

    with {:ok, definition} <- Catalog.by_mob(target),
         index when is_integer(index) <- egg_index(inventory, pet.pet_id) do
      changes = changes(pet, target, definition)
      egg = %{Map.fetch!(inventory, index) | nameid: definition.egg_item_id}
      attrs = %{class: target, egg_id: changes.egg_id, name: changes.name}

      case save(session, removals, Map.put(inventory, index, egg), attrs) do
        {:ok, session} ->
          notify_egg_changed(session, index)
          {{:ok, :PET_ERROR_EVOLUTION_SUCCESS}, reappear(session, changes, definition)}

        :error ->
          {{:error, :PET_ERROR_EVOLUTION_FAIL_UNKNOWN}, session}
      end
    else
      :error -> spent(session, removals, inventory, :PET_ERROR_INVALID_REQUEST)
      nil -> spent(session, removals, inventory, :PET_ERROR_EVOLUTION_FAIL_NOTEXIST_CALLPET)
    end
  end

  defp remove(inventory, removals) do
    Enum.reduce(removals, inventory, fn {index, amount}, inventory ->
      {:ok, inventory, _change} = Inventory.remove(inventory, index, amount)
      inventory
    end)
  end

  defp changes(%PetState{} = pet, target, %PetDefinition{} = definition) do
    name =
      if pet.rename_flag == 0 do
        {:ok, mob} = Mobs.by_id(target)
        mob.name
      else
        pet.name
      end

    %{class_id: target, egg_id: definition.egg_item_id, name: name}
  end

  # The evolution stopped after the materials were spent.
  defp spent(session, removals, inventory, error) do
    case save(session, removals, inventory, %{}) do
      {:ok, session} -> {{:error, error}, session}
      :error -> {{:error, :PET_ERROR_EVOLUTION_FAIL_UNKNOWN}, session}
    end
  end

  defp save(%SessionState{pet: pet, game_state: owner} = session, removals, inventory, attrs) do
    with %Pet{} = row <- Persistence.load(pet.pet_id),
         {:ok, inventory, _row} <-
           Persistence.save_with_inventory(
             row,
             attrs,
             owner.character_id,
             owner.inventory,
             inventory
           ) do
      session = PlayerStateCommit.commit(session, %{owner | inventory: inventory})

      Enum.each(removals, fn {index, amount} ->
        MessageRouter.send_to(session.connection_pid, InventoryView.item_removed(index, amount))
      end)

      PlayerEvents.inventory_changed(owner.character_id)
      {:ok, session}
    else
      failure ->
        Logger.error("Failed to evolve pet #{pet.pet_id}: #{inspect(failure)}")
        :error
    end
  end

  defp notify_egg_changed(%SessionState{game_state: owner} = session, index) do
    egg = Map.fetch!(owner.inventory, index)
    MessageRouter.send_to(session.connection_pid, InventoryView.item_removed(index, 1))
    MessageRouter.send_to(session.connection_pid, InventoryView.item_added(egg, index))
  end

  # Out of sight, changed, and back on the same cell: a stopped walk and no
  # move delay, the other timers kept.
  defp reappear(session, changes, %PetDefinition{} = definition) do
    %SessionState{pet: pet, pet_runtime: runtime} = session = MovementHandler.stop(session)
    session = %{session | pet_runtime: %{runtime | can_move_at_ms: nil}}

    session =
      session
      |> StateCommit.detach(struct!(pet, changes))
      |> HungerHandler.set_intimate(definition.intimacy_start)
      |> StateCommit.attach()

    %SessionState{pet: pet, game_state: owner} = session

    MessageRouter.send_to(session.connection_pid, %PetStateChange{
      gid: pet.world_gid,
      type: :PET_STATE_INIT,
      value: 0
    })

    Broadcast.to_in_range(pet.map_name, pet.x, pet.y, Config.view_range(), %PetStateChange{
      gid: pet.world_gid,
      type: :PET_STATE_ACCESSORY,
      value: SpawnView.accessory_view(pet.equip)
    })

    LifecycleHandler.send_private_state(session)
    Emote.show({:player, owner.character_id}, :best)
    SpecialEffect.play({:pet, pet.world_gid}, :ho_up)
    MessageRouter.send_to(session.connection_pid, InventoryView.inventory_list(owner.inventory))
    session
  end

  defp egg_index(inventory, pet_id) do
    inventory
    |> Enum.filter(fn {_index, item} -> Egg.pet_id(item) == pet_id end)
    |> Enum.map(&elem(&1, 0))
    |> Enum.min(fn -> nil end)
  end
end
