defmodule Aesir.ZoneServer.Unit.Pet.SpawnView do
  @moduledoc """
  Builds the public pet spawn view and delivers its visibility changes.
  """

  alias Aesir.Net.UnitDespawn
  alias Aesir.Net.UnitSpawn
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Constants.DespawnReason
  alias Aesir.ZoneServer.Constants.ObjectType
  alias Aesir.ZoneServer.Mmo.ItemManagement.Items
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Pet.PetState
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @doc """
  Builds the spawn packet of a pet in the world. The accessory shows the
  equipped item's view id, or the item id when it has none (`status.cpp:9482`).
  """
  @spec build(PetState.t()) :: UnitSpawn.t()
  def build(%PetState{world_gid: gid} = pet) when is_integer(gid) do
    %UnitSpawn{
      gid: gid,
      aid: gid,
      object_type: ObjectType.pet(),
      job: pet.class_id,
      x: pet.x,
      y: pet.y,
      dir: pet.dir,
      speed: pet.walk_speed,
      clevel: pet.level,
      accessory: accessory_view(pet.equip),
      name: pet.name,
      moving: pet.movement_state == :moving
    }
  end

  defp accessory_view(0), do: 0

  defp accessory_view(item_id) do
    case Items.by_id(item_id) do
      {:ok, %{view: view}} when view != 0 -> view
      _no_view -> item_id
    end
  end

  @doc "Sends a pet's spawn to one observer."
  @spec send_spawn(non_neg_integer(), PetState.t()) :: :ok
  def send_spawn(observer_id, %PetState{} = pet), do: Broadcast.to_player(observer_id, build(pet))

  @doc "Sends an out-of-sight despawn of a pet to one observer."
  @spec send_despawn(non_neg_integer(), pos_integer()) :: :ok
  def send_despawn(observer_id, gid) do
    Broadcast.to_player(observer_id, %UnitDespawn{gid: gid, reason: DespawnReason.out_of_sight()})
  end

  @doc "Vanishes a pet with `reason` for every player in view of its cell."
  @spec notify_despawn(PetState.t(), non_neg_integer()) :: :ok
  def notify_despawn(%PetState{world_gid: gid, map_name: map_name, x: x, y: y}, reason) do
    map_name
    |> SpatialIndex.get_players_in_range(x, y, Config.view_range())
    |> notify_vanished(gid, reason)
  end

  @doc "Vanishes a pet with `reason` for the given observers that see it."
  @spec notify_vanished(Enumerable.t(), pos_integer(), non_neg_integer()) :: :ok
  def notify_vanished(observer_ids, gid, reason),
    do: each_observer(observer_ids, &PlayerSession.notify_pet_vanished(&1, gid, reason))

  @doc "Notifies stationary observers that a pet entered their view."
  @spec notify_entered(Enumerable.t(), pos_integer()) :: :ok
  def notify_entered(observer_ids, gid),
    do: each_observer(observer_ids, &PlayerSession.notify_pet_entered_view(&1, gid))

  @doc "Notifies stationary observers that a pet left their view."
  @spec notify_left(Enumerable.t(), pos_integer()) :: :ok
  def notify_left(observer_ids, gid),
    do: each_observer(observer_ids, &PlayerSession.notify_pet_left_view(&1, gid))

  defp each_observer(observer_ids, notify) do
    Enum.each(observer_ids, fn observer_id ->
      with {:ok, pid} <- UnitRegistry.get_player_pid(observer_id), do: notify.(pid)
    end)
  end
end
