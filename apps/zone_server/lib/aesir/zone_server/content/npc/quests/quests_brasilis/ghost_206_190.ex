defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsBrasilis.Ghost206190 do
  @moduledoc """
  A ghost appears at the end of the museum bathroom quest.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - og2
    - Euphy
    - Capuche
    - Daegaladh

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "bra_in01",
        x: 206,
        y: 190,
        dir: 3,
        sprite: 1867,
        name: "Ghost",
        scope: :shared,
        unique_name: "Ghost#bra_end"
      }
    ]

  @impl true
  def on_event("OnInit", ctx), do: disablenpc(ctx, "Ghost#bra_end")

  @impl true
  def on_talk(ctx), do: ctx
end
