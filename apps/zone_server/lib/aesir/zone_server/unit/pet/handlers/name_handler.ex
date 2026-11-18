defmodule Aesir.ZoneServer.Unit.Pet.Handlers.NameHandler do
  @moduledoc "Renames pets and relays their emotions to nearby players."

  import Bitwise
  require Logger

  alias Aesir.Commons.Models.Pet
  alias Aesir.Net.ChatNotice
  alias Aesir.Net.PetEmotion
  alias Aesir.Net.PetStateChange
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Mmo.PetManagement.Egg
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Pet.Handlers.LifecycleHandler
  alias Aesir.ZoneServer.Unit.Pet.Persistence
  alias Aesir.ZoneServer.Unit.Pet.SpawnView
  alias Aesir.ZoneServer.Unit.Pet.StateCommit
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Player.StateCommit, as: PlayerStateCommit
  alias Aesir.ZoneServer.Unit.SpatialIndex

  @doc "Renames the active pet, returning an error when the request is refused."
  @spec rename(SessionState.t(), String.t()) ::
          {:ok, SessionState.t()} | {:error, SessionState.t()}
  def rename(%SessionState{pet: pet} = session, name) do
    name = name |> :binary.split(<<0>>) |> hd()
    name = binary_part(name, 0, min(byte_size(name), 24))

    cond do
      pet.rename_flag == 1 and not Config.pet_rename?() ->
        {:error, session}

      Enum.any?(:binary.bin_to_list(name), &((&1 &&& 0xE0) == 0 or &1 == 0x7F)) ->
        {:error, session}

      true ->
        name =
          name
          |> binary_part(0, min(byte_size(name), 23))
          |> complete_utf8()
          |> String.split(" ", trim: true)
          |> Enum.join(" ")

        if name == "", do: refuse(session), else: persist(session, name)
    end
  end

  defp complete_utf8(name) do
    case :unicode.characters_to_binary(name) do
      valid when is_binary(valid) -> valid
      {_, valid, _} -> valid
    end
  end

  defp refuse(session) do
    MessageRouter.send_to(session.connection_pid, %ChatNotice{kind: :INFO, text: "Invalid name."})
    LifecycleHandler.send_private_state(session)
    {:error, session}
  end

  defp persist(%SessionState{pet: pet, game_state: owner} = session, name) do
    inventory =
      case Egg.find(owner.inventory, pet.pet_id) do
        {:ok, egg} ->
          {index, _} = Enum.find(owner.inventory, fn {_index, item} -> item.id == egg.id end)
          Map.put(owner.inventory, index, %{egg | card3: egg.card3 ||| 1})

        :error ->
          owner.inventory
      end

    with %Pet{} = row <- Persistence.load(pet.pet_id),
         {:ok, inventory, _row} <-
           Persistence.save_with_inventory(
             row,
             %{name: name, rename_flag: 1},
             owner.character_id,
             owner.inventory,
             inventory
           ) do
      session = PlayerStateCommit.commit(session, %{owner | inventory: inventory})
      pet = %{pet | name: name, rename_flag: 1}
      session = StateCommit.commit(session, pet)

      pet.map_name
      |> SpatialIndex.get_players_in_range(pet.x, pet.y, Config.view_range())
      |> Enum.each(fn observer ->
        SpawnView.send_despawn(observer, pet.world_gid)
        SpawnView.send_spawn(observer, pet)
      end)

      Broadcast.to_in_range(pet.map_name, pet.x, pet.y, Config.view_range(), %PetStateChange{
        gid: pet.world_gid,
        type: :PET_STATE_ACCESSORY,
        value: SpawnView.accessory_view(pet.equip)
      })

      LifecycleHandler.send_private_state(session)
      {:ok, session}
    else
      reason ->
        Logger.error("Failed to rename pet #{pet.pet_id}: #{inspect(reason)}")
        {:error, session}
    end
  end

  @doc "Relays an emotion for the active pet."
  @spec emotion(SessionState.t(), non_neg_integer()) :: SessionState.t()
  def emotion(%SessionState{pet: pet} = session, data) do
    Broadcast.to_in_range(pet.map_name, pet.x, pet.y, Config.view_range(), %PetEmotion{
      gid: pet.world_gid,
      data: data
    })

    session
  end
end
