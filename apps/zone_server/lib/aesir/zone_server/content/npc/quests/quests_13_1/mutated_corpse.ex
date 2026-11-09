defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.MutatedCorpse do
  @moduledoc """
  A terribly mutated corpse in the ruined eastern Morocc.

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
        x: 92,
        y: 37,
        dir: 7,
        sprite: 457,
        name: "Mutated Corpse",
        scope: :shared,
        unique_name: "Mutated Corpse#moc2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("You find a terribly mutated corpse.")
    |> mes("R.I.P.")
    |> close()
  end
end
