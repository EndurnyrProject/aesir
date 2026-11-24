defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsBrasilis.Pipe do
  @moduledoc """
  The dungeon pipe returns adventurers to the museum sewer.

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
        map: "bra_dun01",
        x: 87,
        y: 43,
        dir: 1,
        sprite: 844,
        name: "Pipe",
        scope: :shared,
        unique_name: "Pipe#bra"
      }
    ]

  @impl true
  def on_talk(ctx), do: warp(ctx, "bra_in01", 206, 185)
end
