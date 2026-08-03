defmodule Aesir.ZoneServer.Unit.Homunculus.SpawnView do
  @moduledoc """
  Builds the public Homunculus spawn view and delivers visibility changes.
  """

  alias Aesir.Net.UnitDespawn
  alias Aesir.Net.UnitSpawn
  alias Aesir.ZoneServer.Constants.DespawnReason
  alias Aesir.ZoneServer.Constants.ObjectType
  alias Aesir.ZoneServer.Mmo.StatusEffect.StatusDisplay
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @doc "Builds the public spawn packet for an active Homunculus."
  @spec build(HomunculusState.t()) :: UnitSpawn.t()
  def build(%HomunculusState{world_gid: gid} = state) when is_integer(gid) do
    %{body_state: body, health_state: health, effect_state: effect, virtue: virtue} =
      StatusDisplay.spawn_state(:homunculus, gid)

    %UnitSpawn{
      gid: gid,
      aid: gid,
      object_type: ObjectType.homunculus(),
      job: state.class_id,
      x: state.x,
      y: state.y,
      dir: state.dir,
      hp: state.hp,
      max_hp: state.max_hp,
      clevel: state.level,
      body_state: body,
      health_state: health,
      effect_state: effect,
      virtue: virtue,
      name: state.name,
      moving: state.movement_state == :moving
    }
  end

  @doc "Sends a Homunculus spawn and its public status icons to one observer."
  @spec send_spawn(non_neg_integer(), HomunculusState.t()) :: :ok
  def send_spawn(observer_id, %HomunculusState{} = state) do
    Broadcast.to_player(observer_id, build(state))

    :homunculus
    |> StatusDisplay.active_icons(state.world_gid)
    |> Enum.each(&Broadcast.to_player(observer_id, &1))
  end

  @doc "Sends an out-of-sight despawn to one observer."
  @spec send_despawn(non_neg_integer(), pos_integer()) :: :ok
  def send_despawn(observer_id, gid) do
    Broadcast.to_player(observer_id, %UnitDespawn{
      gid: gid,
      reason: DespawnReason.out_of_sight()
    })
  end

  @doc "Notifies stationary observers that a Homunculus entered their view."
  @spec notify_entered(Enumerable.t(), pos_integer()) :: :ok
  def notify_entered(observer_ids, gid) do
    Enum.each(observer_ids, fn observer_id ->
      with {:ok, pid} <- UnitRegistry.get_player_pid(observer_id) do
        PlayerSession.notify_homunculus_entered_view(pid, gid)
      end
    end)
  end

  @doc "Notifies stationary observers that a Homunculus left their view."
  @spec notify_left(Enumerable.t(), pos_integer()) :: :ok
  def notify_left(observer_ids, gid) do
    Enum.each(observer_ids, fn observer_id ->
      with {:ok, pid} <- UnitRegistry.get_player_pid(observer_id) do
        PlayerSession.notify_homunculus_left_view(pid, gid)
      end
    end)
  end
end
