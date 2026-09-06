defmodule Aesir.ZoneServer.Content.Npc.Woe.Controller do
  @moduledoc """
  Hidden controller NPC reserved for WoE lifecycle hooks.

  Emperium capture is driven by attributed unit lifecycle events. The hidden
  placement remains registered for future controller events and is hidden on
  initialization so it never renders to clients.
  """

  use Aesir.ZoneServer.Npc,
    spawn: [
      %{map: "prontera", x: 143, y: 94, sprite: 0, name: "WoeController"}
    ]

  @impl true
  def on_talk(ctx), do: ctx

  @impl true
  def on_event("OnInit", ctx), do: hideonnpc(ctx)
end
