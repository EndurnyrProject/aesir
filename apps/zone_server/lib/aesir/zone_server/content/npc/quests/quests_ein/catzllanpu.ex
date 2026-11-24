defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsEin.Catzllanpu do
  @moduledoc """
  Catzllanpu reflects on the value of a restful life.

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
        x: 216,
        y: 118,
        dir: 3,
        sprite: 854,
        name: "Catzllanpu",
        scope: :shared,
        unique_name: "Catzllanpu#ein"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Catzllanpu]")
    |> mes("^333333*Sigh...*^000000")
    |> mes("Simple pleasures.")
    |> mes("They're what make")
    |> mes("life worth living,")
    |> mes("you know?")
    |> next()
    |> mes("[Catzllanpu]")
    |> mes("It's enough for me just to")
    |> mes("live a normal and happy life,")
    |> mes("but everyone around me wants")
    |> mes("to work harder and harder. If")
    |> mes("you never take a rest, you're")
    |> mes("killing yourself pretty slowly.")
    |> next()
    |> mes("[Catzllanpu]")
    |> mes("I guess you can tell that")
    |> mes("I don't have the worries")
    |> mes("other people have about")
    |> mes("money. It's great, but it's")
    |> mes("not worth sacrificing the")
    |> mes("quality of your life, right?")
    |> close()
  end
end
