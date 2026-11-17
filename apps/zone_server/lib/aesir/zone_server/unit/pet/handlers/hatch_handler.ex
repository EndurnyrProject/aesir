defmodule Aesir.ZoneServer.Unit.Pet.Handlers.HatchHandler do
  @moduledoc """
  The egg list and hatching: `birthpet` opens the list and the client's pick
  hatches the egg.

  The list is parked on the shared skill menu slot
  (`SkillMenuHandler.open_pet_egg_offer/1`), so a pick is taken only while it
  is parked, and a skill use, death or warp cancels it.
  """

  require Logger

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Commons.Models.Pet
  alias Aesir.Net.ChatNotice
  alias Aesir.Net.PetEggList
  alias Aesir.Net.PetStateChange
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.ItemManagement.Items
  alias Aesir.ZoneServer.Mmo.PetManagement.Catalog
  alias Aesir.ZoneServer.Mmo.PetManagement.Egg
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Pet.Handlers.AiHandler
  alias Aesir.ZoneServer.Unit.Pet.Handlers.LifecycleHandler
  alias Aesir.ZoneServer.Unit.Pet.Persistence
  alias Aesir.ZoneServer.Unit.Pet.PetState
  alias Aesir.ZoneServer.Unit.Pet.SpawnView
  alias Aesir.ZoneServer.Unit.Pet.StateCommit
  alias Aesir.ZoneServer.Unit.Player.Handlers.SkillMenuHandler
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Player.StateCommit, as: PlayerStateCommit

  @gvg_refusal "Pets are not allowed in Guild Wars."

  @doc """
  Opens the egg list: nothing while a pet is out; message 666 on a GvG map
  (War of Emperium TE included) with `pet_disable_in_gvg`; otherwise every pet
  egg item in the inventory, hatched ones included, is listed and the offer is
  parked, even when the list is empty.
  """
  @spec open_egg_list(SessionState.t()) :: SessionState.t()
  def open_egg_list(%SessionState{pet: %PetState{}} = session), do: session

  def open_egg_list(%SessionState{game_state: owner} = session) do
    if Config.pet_disable_in_gvg?() and MapFlags.gvg2?(owner.map_name) do
      MessageRouter.send_to(session.connection_pid, %ChatNotice{kind: :INFO, text: @gvg_refusal})
      session
    else
      indexes =
        for {index, item} <- owner.inventory, item.amount > 0, egg_item?(item.nameid), do: index

      MessageRouter.send_to(session.connection_pid, %PetEggList{indexes: Enum.sort(indexes)})
      SkillMenuHandler.open_pet_egg_offer(session)
    end
  end

  @doc """
  Hatches the egg at inventory `index`. Ignored with no egg list parked;
  otherwise the list closes and the pick is ignored while trading, for an
  empty slot, an item that is no pet's egg, an egg without a pet
  (`card0 != 256`) or a pet row that is gone or belongs to someone else.

  A pet in its egg hatches from the first egg carrying its id: the egg hides
  (`attribute 1`), the row takes the owner and `incubate 0`,
  `characters.pet_id` points at it, and the pet spawns next to the owner. With
  no such egg nothing happens; with an unknown class the egg stays hidden and
  no pet comes out. A hatched pet the owner already owns comes out without
  touching its egg.
  """
  @spec select_egg(SessionState.t(), non_neg_integer()) :: SessionState.t()
  def select_egg(%SessionState{} = session, index) do
    if SkillMenuHandler.pet_egg_offer?(session),
      do: session |> SkillMenuHandler.clear() |> select(index),
      else: session
  end

  defp select(%SessionState{trade: trade} = session, _index) when not is_nil(trade), do: session

  # A pet out never has the list parked: `birthpet` refuses to open it and
  # only a pick, which closes it, brings a pet out.
  defp select(%SessionState{pet: %PetState{}} = session, _index), do: session

  defp select(%SessionState{game_state: owner} = session, index) do
    with %InventoryItem{nameid: nameid} = egg <- Map.get(owner.inventory, index),
         {:ok, _definition} <- Catalog.by_egg(nameid),
         pet_id when is_integer(pet_id) <- Egg.pet_id(egg),
         %Pet{} = row <- Persistence.load(pet_id) do
      receive_pet(session, row)
    else
      _ignored -> session
    end
  end

  # A pet in its egg is always handed over, a hatched one only to its owner.
  defp receive_pet(session, %Pet{incubate: 1} = row), do: hatch(session, row)

  defp receive_pet(%SessionState{game_state: owner} = session, %Pet{} = row)
       when row.account_id == owner.account_id and row.char_id == owner.character_id do
    with {:ok, pet} <- LifecycleHandler.build(row, owner),
         :ok <- Persistence.link(row.id, owner.character_id) do
      come_out(session, pet, false)
    else
      _no_pet -> session
    end
  end

  defp receive_pet(session, %Pet{}), do: session

  defp hatch(%SessionState{game_state: owner} = session, row) do
    with {:ok, pet} <- LifecycleHandler.build(row, owner),
         {:ok, inventory, _row} <-
           Persistence.hatch(row, owner.account_id, owner.character_id, owner.inventory) do
      session
      |> PlayerStateCommit.commit(%{owner | inventory: inventory})
      |> come_out(pet, true)
    else
      :error ->
        LifecycleHandler.hide_egg(session, row)

      {:error, :egg_missing} ->
        session

      {:error, reason} ->
        Logger.error("Failed to hatch pet #{row.id}: #{inspect(reason)}")
        session
    end
  end

  # Spawn, INIT and (on a hatch) UPDATE_EGG to the owner, ACCESSORY to the
  # area, then the status and autofeed setting.
  defp come_out(session, pet, hatched?) do
    case StateCommit.spawn(session, pet) do
      {:ok, session} ->
        send_state_change(session, :PET_STATE_INIT, 0)

        if hatched?,
          do: send_state_change(session, :PET_STATE_UPDATE_EGG, update_egg(session.pet))

        broadcast_accessory(session)
        LifecycleHandler.send_private_state(session)
        AiHandler.arm(session)

      {:error, :exhausted} ->
        Logger.error("No world id left to spawn pet #{pet.pet_id}")
        session
    end
  end

  defp update_egg(%PetState{intimate: 1}), do: 0
  defp update_egg(%PetState{}), do: 1

  defp send_state_change(%SessionState{pet: pet} = session, type, value) do
    MessageRouter.send_to(session.connection_pid, %PetStateChange{
      gid: pet.world_gid,
      type: type,
      value: value
    })
  end

  defp broadcast_accessory(%SessionState{pet: pet, game_state: owner} = session) do
    packet = %PetStateChange{
      gid: pet.world_gid,
      type: :PET_STATE_ACCESSORY,
      value: SpawnView.accessory_view(pet.equip)
    }

    MessageRouter.send_to(session.connection_pid, packet)

    Broadcast.to_in_range(pet.map_name, pet.x, pet.y, Config.view_range(), packet,
      exclude_id: owner.character_id
    )
  end

  defp egg_item?(nameid), do: match?({:ok, %{type: :pet_egg}}, Items.by_id(nameid))
end
