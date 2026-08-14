defmodule Aesir.ZoneServer.Npc.Packets do
  @moduledoc """
  Pure builders for the wire packets that make a static NPC placement appear
  or disappear on a client (`UnitSpawn`/`UnitDespawn`), keyed by the
  placement's synthetic `Npc.Registry.entity_id/1`.

  Shared by the per-player visibility diff (`MovementHandler`, which sends to
  one player at a time) and `Npc.Session`'s enable/disable/hide transition
  broadcasts (which push the same packet to every player in range), so both
  build the identical packet for the same placement instead of duplicating
  the field list.
  """

  alias Aesir.Net.UnitDespawn
  alias Aesir.Net.UnitSpawn
  alias Aesir.ZoneServer.Constants.DespawnReason
  alias Aesir.ZoneServer.Constants.ObjectType
  alias Aesir.ZoneServer.Npc.Placement
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Npc.Session, as: NpcSession

  @doc "Builds the spawn packet for a placement, keyed by its entity id."
  @spec spawn_packet(Placement.t()) :: UnitSpawn.t()
  def spawn_packet(%Placement{} = placement) do
    entity_id = NpcRegistry.entity_id(placement)

    {sprite, name, size} =
      case NpcSession.display_override(entity_id) do
        {s, n, sz} -> {s || placement.sprite, n || placement.name, sz}
        nil -> {placement.sprite, placement.name, 0}
      end

    %UnitSpawn{
      object_type: ObjectType.npc(),
      aid: entity_id,
      gid: entity_id,
      speed: 0,
      body_state: 0,
      health_state: 0,
      effect_state: 0,
      job: sprite,
      head: 0,
      weapon: 0,
      shield: 0,
      accessory: 0,
      accessory2: 0,
      accessory3: 0,
      head_palette: 0,
      body_palette: 0,
      head_dir: 0,
      robe: 0,
      guild_id: 0,
      sex: 0,
      x: placement.x,
      y: placement.y,
      dir: placement.dir,
      clevel: 0,
      max_hp: 0,
      hp: 0,
      is_boss: false,
      name: name,
      size: display_size(size),
      moving: false
    }
  end

  # The runtime keeps the display size as rAthena's integer (0/1/2); it is
  # converted to the wire enum at the packet boundary.
  @spec display_size(non_neg_integer()) :: atom()
  defp display_size(0), do: :DISPLAY_SIZE_NORMAL
  defp display_size(1), do: :DISPLAY_SIZE_SMALL
  defp display_size(2), do: :DISPLAY_SIZE_BIG
  defp display_size(_), do: :DISPLAY_SIZE_NORMAL

  @doc "Builds the vanish packet for an NPC's entity id."
  @spec vanish_packet(non_neg_integer()) :: UnitDespawn.t()
  def vanish_packet(entity_id) do
    %UnitDespawn{gid: entity_id, reason: DespawnReason.out_of_sight()}
  end
end
