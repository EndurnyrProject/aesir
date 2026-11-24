defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsEin.Supineque do
  @moduledoc """
  Supineque worries about running out of food.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Evera
    - MasterOfMuppets
    - Lupus
    - KarLaeda
    - SinSloth
    - L0ne_W0lf
    - Yommy
    - Paradox924X
    - Kisuka
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ein_in01",
        x: 192,
        y: 90,
        dir: 3,
        sprite: 849,
        name: "Supineque",
        scope: :shared,
        unique_name: "Supineque#ein"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Supineque]")
    |> mes("Ugh...")
    |> mes("I'm starving!")
    |> next()
    |> mes("[Supineque]")
    |> mes("I haven't had food for so")
    |> mes("long that my stomach is")
    |> mes("beginning to digest itself!")
    |> mes("This is horrible...")
    |> next()
    |> mes("[Supineque]")
    |> mes("I mean, I have")
    |> mes("food that I can")
    |> mes("eat today. But if")
    |> mes("I finish it, what am")
    |> mes("I gonna eat tomorrow?")
    |> close()
  end
end
