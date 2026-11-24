defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAmatsu.Grandpa do
  @moduledoc """
  Silent Grandpa of the Momotaro event, hidden until the event shows him.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team
    - MasterOfMuppets
    - L0ne_W0lf
    - Gepard
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ama_test",
        x: 49,
        y: 93,
        dir: 4,
        sprite: 766,
        name: "Grandpa",
        scope: :shared,
        unique_name: "Grandpa#ama"
      }
    ]

  @impl true
  def on_event("OnInit", ctx), do: disablenpc(ctx, "Grandpa#ama")

  @impl true
  def on_talk(ctx), do: ctx
end
