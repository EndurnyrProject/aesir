defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsBrasilis.Poring do
  @moduledoc """
  Poring is the target of Mage Paje’s transformation magic.

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
        map: "brasilis",
        x: 59,
        y: 226,
        dir: 3,
        sprite: 909,
        name: "Poring",
        scope: :shared,
        unique_name: "Poring#bra"
      }
    ]

  @impl true
  def on_talk(ctx), do: ctx
end
