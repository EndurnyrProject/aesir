defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.PubGranny do
  @moduledoc """
  A pub granny welcomes her busy business.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - SinSloth
    - Samuray22
    - L0ne_W0lf
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "hu_in01", x: 377, y: 106, dir: 3, sprite: 892, name: "Pub Granny", scope: :shared}
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Pub Granny]")
    |> mes("Recently we have many tourists visiting our town.")
    |> mes("They make me pretty busy, but I am so happy to see them enjoying my food. Hohoho!")
    |> close()
  end
end
