defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.DisfiguredCorpse do
  @moduledoc """
  A horribly disfigured corpse lying in the ruined eastern Morocc.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script quests/quests_13_1.txt
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "que_dan02",
        x: 102,
        y: 42,
        dir: 3,
        sprite: 457,
        name: "Disfigured Corpse",
        scope: :shared,
        unique_name: "Disfigured Corpse#moc2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("You find a horribly disfigured corpse.")
    |> mes("... . . . . . !!!")
    |> close()
  end
end
