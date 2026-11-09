defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.MutilatedCorpse do
  @moduledoc """
  A terribly mutilated corpse in the ruined eastern Morocc.

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
        x: 99,
        y: 36,
        dir: 0,
        sprite: 457,
        name: "Mutilated Corpse",
        scope: :shared,
        unique_name: "Mutilated Corpse#moc2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("You find a terribly mutilated corpse.")
    |> mes("Rest in peace.")
    |> close()
  end
end
