defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.DarkLord do
  @moduledoc """
  Controls the Dark Lord's visibility during the Sign quest.

  ## Behavior

  - Responds to enable and disable events.

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
        map: "que_sign01",
        x: 196,
        y: 44,
        dir: 4,
        sprite: 737,
        name: "Dark Lord",
        scope: :shared,
        unique_name: "Dark Lord#serin"
      }
    ]

  @impl true
  def on_event("OnDisable", ctx), do: disablenpc(ctx, "Dark Lord#serin")
  def on_event("OnInit", ctx), do: disablenpc(ctx, "Dark Lord#serin")
  def on_event("OnEnable", ctx), do: enablenpc(ctx, "Dark Lord#serin")

  @impl true
  def on_talk(ctx), do: ctx
end
