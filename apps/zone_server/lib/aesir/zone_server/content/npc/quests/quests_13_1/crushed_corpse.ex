defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.CrushedCorpse do
  @moduledoc """
  A corpse crushed to death in the ruined eastern Morocc.

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
        x: 103,
        y: 24,
        dir: 5,
        sprite: 457,
        name: "Crushed Corpse",
        scope: :shared,
        unique_name: "Crushed Corpse#moc2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("You find a horribly disfigured corpse.")
    |> mes("that appears to have been crushed to death.")
    |> close()
  end
end
