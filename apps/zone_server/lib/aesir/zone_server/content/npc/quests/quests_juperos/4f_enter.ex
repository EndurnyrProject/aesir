defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsJuperos.M4fEnter do
  @moduledoc """
  Transfers players from the elevator to the Juperos core.

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
        map: "jupe_ele",
        x: 41,
        y: 33,
        dir: 0,
        sprite: 45,
        name: "4F Enter",
        scope: :shared,
        unique_name: "4F Enter#ufe",
        trigger: {4, 4}
      }
    ]

  @impl true
  def on_talk(ctx) do
    on_event("OnInit", ctx)
  end

  @impl true
  def on_event("OnInit", ctx) do
    disablenpc(ctx, "4F Enter#ufe")
  end

  def on_event("OnTouch_", ctx) do
    warp(ctx, "jupe_core", Enum.random(149..151), 286)
  end
end
