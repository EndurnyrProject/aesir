defmodule Aesir.ZoneServer.Unit.Pet.Handlers.LifecycleHandler do
  @moduledoc """
  The pet's life around its owner's session: restored at login, put in the
  world after each map load, carried along an owner warp, returned to its egg,
  and saved (or deleted once it ran away) when the session ends.
  """

  require Logger

  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.Pet
  alias Aesir.Net.ChatNotice
  alias Aesir.Net.PetPrivateState
  alias Aesir.Net.PetStateChange
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Constants.DespawnReason
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.MobManagement.Mobs
  alias Aesir.ZoneServer.Mmo.PetManagement.Catalog
  alias Aesir.ZoneServer.Mmo.PetManagement.Egg
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Unit.Pet.Clock
  alias Aesir.ZoneServer.Unit.Pet.Handlers.AiHandler
  alias Aesir.ZoneServer.Unit.Pet.Handlers.HungerHandler
  alias Aesir.ZoneServer.Unit.Pet.Handlers.MovementHandler
  alias Aesir.ZoneServer.Unit.Pet.Persistence
  alias Aesir.ZoneServer.Unit.Pet.PetState
  alias Aesir.ZoneServer.Unit.Pet.StateCommit
  alias Aesir.ZoneServer.Unit.Player.InventoryView
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Player.StateCommit, as: PlayerStateCommit

  # msg_conf 666
  @gvg_refusal "Pets are not allowed in Guild Wars."

  @doc """
  Restores the pet named by `characters.pet_id` at login, held off the map
  until `spawned_after_map_load/1`.

  With no row, a hatched row of another account or character or an unknown
  class, `pet_id` is cleared. A row still in its egg hides the egg
  (`attribute 1`) and clears `pet_id`: the hatch that follows fails because
  `pet_id` was set; with no egg only `pet_id` is cleared.
  Otherwise the pet stands next to the owner facing the owner's direction,
  and an unrenamed pet takes its mob's name. Its hunger timer starts now and
  keeps running across owner warps.
  """
  @spec restore(SessionState.t(), Character.t()) :: SessionState.t()
  def restore(%SessionState{} = session, %Character{pet_id: pet_id} = character)
      when is_integer(pet_id) and pet_id > 0 do
    case Persistence.load(pet_id) do
      %Pet{incubate: 1} = row ->
        hide_egg(session, row)

      %Pet{account_id: account_id, char_id: char_id} = row
      when account_id == character.account_id and char_id == character.id ->
        init(session, row)

      _missing_or_foreign ->
        unlink(session, pet_id, session.game_state.inventory)
    end
  end

  def restore(%SessionState{} = session, %Character{}), do: session

  @doc """
  Puts the pet in the world once the owner's map has loaded: it spawns and the
  owner gets INIT and the private state. On a GvG map with
  `pet_disable_in_gvg` the owner sees message 666 and the pet returns to its
  egg instead.
  """
  @spec spawned_after_map_load(SessionState.t()) :: SessionState.t()
  def spawned_after_map_load(%SessionState{pet: %PetState{}, game_state: owner} = session) do
    if Config.pet_disable_in_gvg?() and gvg?(owner.map_name) do
      MessageRouter.send_to(session.connection_pid, %ChatNotice{kind: :INFO, text: @gvg_refusal})
      return_to_egg(session)
    else
      session = StateCommit.attach(session)
      send_state_change(session, :PET_STATE_INIT, 0)
      send_private_state(session)
      AiHandler.arm(session)
    end
  end

  def spawned_after_map_load(%SessionState{} = session), do: session

  @doc """
  Carries the pet along an owner warp: it leaves the map out of sight with its
  owner, stops walking and thinking, and stands on the destination cell
  facing the owner's direction until `spawned_after_map_load/1`.
  Partial item-script sessions do not carry pet state and pass through unchanged.
  """
  @spec detach_for_warp(map(), {String.t(), integer(), integer()}) :: map()
  def detach_for_warp(
        %SessionState{pet: %PetState{intimate: 0} = pet, game_state: owner} = session,
        _destination
      ) do
    :ok = Persistence.delete(pet.pet_id, owner.character_id)
    StateCommit.remove(session, DespawnReason.out_of_sight())
  end

  def detach_for_warp(%SessionState{pet: %PetState{}} = session, {map_name, x, y}) do
    session = MovementHandler.stop(session)
    runtime = session.pet_runtime
    Clock.cancel(runtime.ai_timer_ref)
    Clock.cancel(runtime.teleport_timer_ref)

    session = %{
      session
      | pet_runtime: %{runtime | ai_timer_ref: nil, teleport_timer_ref: nil, can_move_at_ms: nil}
    }

    pet = %{
      session.pet
      | map_name: map_name,
        x: x,
        y: y,
        dir: session.game_state.dir,
        target: nil
    }

    StateCommit.detach(session, pet)
  end

  def detach_for_warp(session, _destination) when is_map(session), do: session

  @doc """
  Returns the pet to its egg: the egg
  shows again (`attribute 0`), the pet goes back in it (`incubate 1`) and is
  unlinked from the character, the owner gets the inventory and UPDATE_EGG,
  and the pet leaves the world out of sight. With its egg gone from the
  inventory nothing changes. The live pet is saved with the transition.
  """
  @spec return_to_egg(SessionState.t()) :: SessionState.t()
  def return_to_egg(%SessionState{pet: %PetState{} = pet, game_state: owner} = session) do
    with %Pet{} = row <- Persistence.load(pet.pet_id),
         {:ok, inventory, _row} <-
           Persistence.return_to_egg(row, owner.character_id, owner.inventory, row_attrs(pet)) do
      session = PlayerStateCommit.commit(session, %{owner | inventory: inventory})
      MessageRouter.send_to(session.connection_pid, InventoryView.inventory_list(inventory))
      send_state_change(session, :PET_STATE_UPDATE_EGG, if(pet.intimate == 1, do: 0, else: 1))
      StateCommit.remove(session, DespawnReason.out_of_sight())
    else
      _no_egg -> session
    end
  end

  def return_to_egg(%SessionState{} = session), do: session

  @doc """
  Ends the pet with its owner's session:
  it leaves the world out of sight; a pet with intimacy is saved, a pet that
  ran away (intimacy 0) is deleted and unlinked from the character.
  """
  @spec terminate(SessionState.t()) :: :ok
  def terminate(%SessionState{pet: %PetState{} = pet, game_state: owner} = session) do
    StateCommit.remove(session, DespawnReason.out_of_sight())

    if pet.intimate > 0,
      do: save(pet),
      else: Persistence.delete(pet.pet_id, owner.character_id)
  end

  def terminate(%SessionState{}), do: :ok

  @doc """
  Sends the owner its pet's status with the autofeed setting. `renamed` is
  reported only while `pet_rename` is off.
  """
  @spec send_private_state(SessionState.t()) :: :ok
  def send_private_state(%SessionState{pet: %PetState{} = pet} = session) do
    {:ok, definition} = Catalog.by_mob(pet.class_id)
    autofeed? = Config.feature_pet_autofeed?()

    MessageRouter.send_to(session.connection_pid, %PetPrivateState{
      gid: pet.world_gid,
      name: pet.name,
      renamed: not Config.pet_rename?() and pet.rename_flag == 1,
      level: pet.level,
      hunger: pet.hungry,
      intimacy: pet.intimate,
      accessory_item_id: pet.equip,
      class_id: pet.class_id,
      autofeed_enabled: autofeed? and pet.autofeed,
      autofeed_available: autofeed? and definition.allow_auto_feed
    })
  end

  defp init(%SessionState{game_state: owner} = session, %Pet{} = row) do
    with {:ok, pet} <- build(row, owner),
         {:ok, session} <- StateCommit.restore(session, pet) do
      HungerHandler.arm(session)
    else
      :error ->
        unlink(session, row.id, owner.inventory)

      {:error, :exhausted} ->
        Logger.error("No world id left to restore pet #{row.id}")
        session
    end
  end

  @doc """
  Builds the pet for `row` as it first appears: next to the owner facing the
  owner's direction, an unrenamed pet named after its mob. `:error` for a
  class with no pet or mob entry.
  """
  @spec build(Pet.t(), PlayerState.t()) :: {:ok, PetState.t()} | :error
  def build(%Pet{} = row, %PlayerState{} = owner) do
    with {:ok, _definition} <- Catalog.by_mob(row.class),
         {:ok, mob} <- Mobs.by_id(row.class) do
      pet = PetState.from_row(row, owner)
      {x, y} = MovementHandler.calc_pos(pet, owner)
      {:ok, %{pet | x: x, y: y, name: if(row.rename_flag == 0, do: mob.name, else: row.name)}}
    end
  end

  @doc """
  Hides the pet's egg (`attribute 1`), if the owner carries it, and clears
  `characters.pet_id`: what a failed hatch leaves behind.
  """
  @spec hide_egg(SessionState.t(), Pet.t()) :: SessionState.t()
  def hide_egg(%SessionState{game_state: owner} = session, %Pet{id: pet_id}) do
    case Enum.find(owner.inventory, fn {_index, item} -> Egg.pet_id(item) == pet_id end) do
      {index, egg} -> unlink(session, pet_id, %{owner.inventory | index => %{egg | attribute: 1}})
      nil -> unlink(session, pet_id, owner.inventory)
    end
  end

  defp unlink(%SessionState{game_state: owner} = session, pet_id, inventory) do
    case Persistence.unlink(pet_id, owner.character_id, owner.inventory, inventory) do
      {:ok, inventory} ->
        PlayerStateCommit.commit(session, %{owner | inventory: inventory})

      {:error, reason} ->
        Logger.error("Failed to unlink pet #{pet_id}: #{inspect(reason)}")
        session
    end
  end

  defp save(%PetState{} = pet) do
    with %Pet{} = row <- Persistence.load(pet.pet_id),
         {:error, changeset} <- Persistence.save(row, row_attrs(pet)) do
      Logger.error("Failed to save pet #{pet.pet_id}: #{inspect(changeset.errors)}")
    end

    :ok
  end

  defp row_attrs(%PetState{} = pet) do
    %{
      class: pet.class_id,
      name: pet.name,
      level: pet.level,
      egg_id: pet.egg_id,
      equip: pet.equip,
      intimate: pet.intimate,
      hungry: pet.hungry,
      rename_flag: pet.rename_flag,
      autofeed: pet.autofeed
    }
  end

  defp send_state_change(%SessionState{pet: pet} = session, type, value) do
    MessageRouter.send_to(session.connection_pid, %PetStateChange{
      gid: pet.world_gid,
      type: type,
      value: value
    })
  end

  # A TE castle never counts: Aesir runs no TE agit.
  defp gvg?(map_name), do: MapFlags.gvg?(map_name) or MapFlags.get(map_name, :gvg_te)
end
