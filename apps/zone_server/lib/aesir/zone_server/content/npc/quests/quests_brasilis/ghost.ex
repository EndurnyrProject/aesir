defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsBrasilis.Ghost do
  @moduledoc """
  A ghost appears during the museum bathroom quest.

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
        x: 136,
        y: 180,
        dir: 5,
        sprite: 1867,
        name: "Ghost",
        scope: :shared,
        unique_name: "Ghost#bra"
      }
    ]

  @impl true
  def on_event("OnInit", ctx), do: disablenpc(ctx, "Ghost#bra")

  @impl true
  def on_talk(ctx), do: ctx
end
