defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.Music do
  @moduledoc """
  Plays a sound effect when an adventurer walks into the Prontera maze clearing.

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
        x: 25,
        y: 161,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#music",
        trigger: {7, 7}
      }
    ]

  @impl true
  def on_event("OnTouch_", ctx), do: ev_ontouch(ctx)

  @impl true
  def on_talk(ctx), do: ev_ontouch(ctx)

  def ev_ontouch(ctx) do
    soundeffect(ctx, "effect\\?????? ???Ø½?.wav", 1)
  end
end
