defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsEin.Ellhenje do
  @moduledoc """
  Ellhenje talks about Klitzer and life in Einbech.

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
        map: "einbech",
        x: 176,
        y: 125,
        dir: 3,
        sprite: 850,
        name: "Ellhenje",
        scope: :shared,
        unique_name: "Ellhenje#ein"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Ellhenje]")
    |> mes("Things might be")
    |> mes("bad in this town")
    |> mes("with the pollution")
    |> mes("and the bullying")
    |> mes("from Einbroch...")
    |> next()
    |> mes("[Ellhenje]")
    |> mes("But somehow, people")
    |> mes("are able to get by. That's")
    |> mes("because there's a guy")
    |> mes("that everyone here likes...")
    |> next()
    |> mes("[Ellhenje]")
    |> mes("I'm talking about Klitzer!")
    |> mes("He's almost too honest and")
    |> mes("almost too diligent. But most")
    |> mes("of all, he's the nicest guy~")
    |> next()
    |> mes("[Ellhenje]")
    |> mes("Klitzer was born in one of")
    |> mes("Einbech's poorest families,")
    |> mes(
      "but he's usually happy and always thinks about others. I guess that's why people like to think of him"
    )
    |> mes("as representing all of Einbech.")
    |> next()
    |> mes("[Ellhenje]")
    |> mes("Recently, something's")
    |> mes("been bothering him. I'm")
    |> mes("not sure, but I think only")
    |> mes("woman troubles could make")
    |> mes("a guy feel so glum. I hope he")
    |> mes("feels better soon...")
    |> close()
  end
end
