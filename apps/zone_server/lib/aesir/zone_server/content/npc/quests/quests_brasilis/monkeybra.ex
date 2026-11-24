defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsBrasilis.Monkeybra do
  @moduledoc """
  This hidden monkey provides scenery for the Guarana Candy quest.

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
        map: "bra_fild01",
        x: 245,
        y: 53,
        dir: 3,
        sprite: 1057,
        name: "",
        scope: :shared,
        unique_name: "#Monkeybra"
      }
    ]

  @impl true
  def on_talk(ctx), do: ctx
end
