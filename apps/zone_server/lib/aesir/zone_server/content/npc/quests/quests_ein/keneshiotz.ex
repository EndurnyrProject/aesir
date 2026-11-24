defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsEin.Keneshiotz do
  @moduledoc """
  Keneshiotz praises the wealth and comfort of Einbroch.

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
        map: "einbroch",
        x: 188,
        y: 72,
        dir: 3,
        sprite: 855,
        name: "Keneshiotz",
        scope: :shared,
        unique_name: "Keneshiotz#ein"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Keneshiotz]")
    |> mes("This city is full of sky")
    |> mes("high smokestacks and")
    |> mes("the droning hum of machines.")
    |> next()
    |> mes("[Keneshiotz]")
    |> mes("Sure, the air is polluted,")
    |> mes("but I think it's a fair price")
    |> mes("to pay for wealth and a")
    |> mes("modern life of comfort.")
    |> mes("Screw the environment!")
    |> next()
    |> mes("[Keneshiotz]")
    |> mes("I'd much rather live like")
    |> mes("this than end up like those")
    |> mes("backwards vagrants in that")
    |> mes("filthy Einbech. Don't they")
    |> mes("know that money makes")
    |> mes("the world go 'round?")
    |> close()
  end
end
