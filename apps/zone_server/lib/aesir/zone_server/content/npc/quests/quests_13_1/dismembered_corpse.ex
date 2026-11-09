defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.DismemberedCorpse do
  @moduledoc """
  A dismembered body in the ruined eastern Morocc.

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
        x: 108,
        y: 17,
        dir: 3,
        sprite: 457,
        name: "Dismembered Corpse",
        scope: :shared,
        unique_name: "Dismembered Corpse#moc2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("You find a horribly dismembered dead body.")
    |> mes("It is disgusting to decribe the status of the Corpse!.")
    |> close()
  end
end
