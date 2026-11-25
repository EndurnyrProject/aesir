defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMorocc.Assistant do
  @moduledoc """
  Sephit reflects on witnessing Satan Morocc.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - Lupus
    - SinSloth
    - Samuray22
    - L0ne_W0lf
    - Gepard
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "morocc_in",
        x: 46,
        y: 125,
        dir: 5,
        sprite: 729,
        name: "Assistant",
        scope: :shared,
        unique_name: "Assistant#moc_ex1"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Sephit]")
    |> mes("I've always believed in Satan..")
    |> mes("Haah... Guess it's good to be living, after all.")
    |> next()
    |> mes("[Sephit]")
    |> mes("Who would've thought to actually see the Satan while alive.....?")
    |> close()
  end
end
