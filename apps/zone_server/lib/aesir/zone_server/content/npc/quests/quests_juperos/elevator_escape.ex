defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsJuperos.ElevatorEscape do
  @moduledoc """
  Warps remaining players out of the elevator reception.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - SinSloth
    - L0ne_W0lf
    - Zephyrus
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "jupe_ele_r",
        x: 50,
        y: 89,
        dir: 0,
        sprite: -1,
        name: "Elevator Escape",
        scope: :shared,
        unique_name: "Elevator Escape#ufe",
        trigger: {35, 50}
      }
    ]

  @impl true
  def on_talk(ctx) do
    on_event("OnInit", ctx)
  end

  @impl true
  def on_event("OnInit", ctx) do
    disablenpc(ctx, "Elevator Escape#ufe")
  end

  def on_event("OnTouch_", ctx) do
    mapwarp(ctx, "jupe_ele_r", "jupe_gate", 49, 138)
  end
end
