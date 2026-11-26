defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.Mazewarp do
  @moduledoc """
  Sends anyone who steps on it to another spot in the Prontera maze.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Kargha
    - L0ne_W0lf
    - Kazukin
    - Kisuka
    - CalciumKid
    - tr0n
    - Euphy
    - Joseph
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prt_maze02",
        x: 18,
        y: 126,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#mazewarp",
        trigger: {3, 3}
      }
    ]

  @impl true
  def on_event("OnTouch_", ctx), do: ev_ontouch(ctx)

  @impl true
  def on_talk(ctx), do: ev_ontouch(ctx)

  def ev_ontouch(ctx) do
    warp(ctx, "prt_maze02", 90, 170)
  end
end
