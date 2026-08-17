defmodule Aesir.ZoneServer.Content.Npc.Woe.Controller do
  @moduledoc """
  Hidden controller NPC for the WoE Emperium owner-event.

  The Emperium (mob 1288) is summoned with the owner-event
  `WoeController::OnEmperiumBreak`; when it dies to a player, the map
  coordinator dispatches that event onto the killer's session. This module's
  `OnEmperiumBreak` handler reads the killer's guild (`getcharid(ctx, 2)`),
  resolves the castle from the killer's current map, and delegates the atomic
  claim to `Woe.Server.capture/4`. A guildless killer is a no-op — the
  Emperium still respawns on the server's timer, mirroring the reference
  behavior of logging the break and saving nothing.

  The single placement exists only so the registry resolves the NPC name to a
  stable entity id for the event dispatch; `OnInit` hides it so it never
  renders to clients.
  """

  use Aesir.ZoneServer.Npc,
    spawn: [
      %{map: "prontera", x: 143, y: 94, sprite: 0, name: "WoeController"}
    ]

  alias Aesir.ZoneServer.Mmo.Woe.CastleDb
  alias Aesir.ZoneServer.Mmo.Woe.CastleStore
  alias Aesir.ZoneServer.Mmo.Woe.Server

  @impl true
  def on_talk(ctx), do: ctx

  @impl true
  def on_event("OnInit", ctx), do: hideonnpc(ctx)

  @impl true
  def on_event("OnEmperiumBreak", ctx) do
    case getcharid(ctx, 2) do
      0 ->
        ctx

      guild_id ->
        {:ok, castle} = CastleDb.by_map(ctx.game_state.map_name)
        Server.capture(castle.id, CastleStore.get(castle.id).epoch, guild_id, getcharid(ctx, 0))
        ctx
    end
  end
end
