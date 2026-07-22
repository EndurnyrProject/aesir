defmodule Aesir.ZoneServer.Unit.Mob.SpawnView do
  @moduledoc """
  Builds the outbound mob `UnitSpawn` wire message from server-side mob state
  and broadcasts spawn/HP/despawn visibility packets to nearby players.

  Mirrors `Player.SpawnView` for the mob spawn domain.
  """

  alias Aesir.Net.UnitDespawn
  alias Aesir.Net.UnitHp
  alias Aesir.Net.UnitSpawn
  alias Aesir.ZoneServer.Constants.DespawnReason
  alias Aesir.ZoneServer.Constants.ObjectType
  alias Aesir.ZoneServer.Mmo.StatusEffect.StatusDisplay
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobState

  @doc """
  Builds the `UnitSpawn` describing `mob_state`'s mob for a nearby observer.
  """
  @spec build(MobState.t()) :: UnitSpawn.t()
  def build(%MobState{} = mob_state) do
    %{
      body_state: body_state,
      health_state: health_state,
      effect_state: effect_state,
      virtue: virtue
    } =
      StatusDisplay.spawn_state(:mob, mob_state.instance_id)

    %UnitSpawn{
      object_type: ObjectType.mob(),
      aid: mob_state.instance_id,
      gid: mob_state.instance_id,
      speed: mob_state.walk_speed,
      body_state: body_state,
      health_state: health_state,
      effect_state: effect_state,
      virtue: virtue,
      job: mob_state.mob_id,
      sex: 0,
      x: mob_state.x,
      y: mob_state.y,
      dir: mob_state.dir,
      clevel: mob_state.mob_data.level,
      max_hp: mob_state.max_hp,
      hp: mob_state.hp,
      is_boss: MobState.is_boss?(mob_state),
      name: mob_state.mob_data.name,
      moving: false
    }
  end

  @doc """
  Broadcasts a mob spawn packet to nearby players and returns it.
  """
  @spec notify_spawn(MobState.t()) :: {:ok, UnitSpawn.t()}
  def notify_spawn(%MobState{} = mob_state) do
    packet = build(mob_state)
    broadcast_to_nearby_players(mob_state, packet)
    {:ok, packet}
  end

  @doc """
  Broadcasts an HP update packet for `mob_state` to nearby players and returns it.
  """
  @spec notify_hp_update(MobState.t()) :: {:ok, UnitHp.t()}
  def notify_hp_update(%MobState{} = mob_state) do
    packet = %UnitHp{
      id: mob_state.instance_id,
      hp: max(0, mob_state.hp),
      max_hp: max(1, mob_state.max_hp)
    }

    broadcast_to_nearby_players(mob_state, packet)
    {:ok, packet}
  end

  @doc """
  Broadcasts a despawn packet for `mob_state` to nearby players and returns it.
  """
  @spec notify_despawn(MobState.t()) :: {:ok, UnitDespawn.t()}
  def notify_despawn(%MobState{} = mob_state) do
    packet = %UnitDespawn{
      gid: mob_state.instance_id,
      reason: DespawnReason.died()
    }

    broadcast_to_nearby_players(mob_state, packet)
    {:ok, packet}
  end

  defp broadcast_to_nearby_players(%MobState{} = mob_state, packet) do
    Broadcast.to_in_range(
      mob_state.map_name,
      mob_state.x,
      mob_state.y,
      mob_state.view_range,
      packet
    )
  end
end
