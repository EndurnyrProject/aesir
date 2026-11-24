defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsEin.Kesunboss do
  @moduledoc """
  Kesunboss admires Lady Calla and her mansion.

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
        x: 208,
        y: 208,
        dir: 3,
        sprite: 850,
        name: "Kesunboss",
        scope: :shared,
        unique_name: "Kesunboss#ein"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Kesunboss]")
    |> mes("Lady Calla is the")
    |> mes("epitome of elegance,")
    |> mes("a veritable goddess")
    |> mes("of Einbroch.")
    |> next()
    |> mes("[Kesunboss]")
    |> mes("Her gentle voice,")
    |> mes("that angelic smile, her")
    |> mes("kindness and warmth")
    |> mes("towards other people")
    |> mes("and above all...")
    |> next()
    |> mes("[Kesunboss]")
    |> mes("Calla's family")
    |> mes("is wealthy beyond")
    |> mes("imagination! She's")
    |> mes("perfect! I don't know who")
    |> mes("she'll marry, but he'd be")
    |> mes("a lucky gentleman, I'm sure.")
    |> next()
    |> mes("[Kesunboss]")
    |> mes("Lady Calla lives in a magnificent mansion that makes other houses")
    |> mes("look like shacks in comparison.")
    |> mes("Head north and then west from")
    |> mes("here if you wish to marvel in its")
    |> mes("beauty and elegance.")
    |> close()
  end
end
