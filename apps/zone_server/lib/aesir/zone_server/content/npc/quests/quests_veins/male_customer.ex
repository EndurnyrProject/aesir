defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.MaleCustomer do
  @moduledoc """
  A disgruntled customer drinks away his troubles.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Toms
    - Euphy
    - Joseph
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ve_in",
        x: 239,
        y: 107,
        dir: 1,
        sprite: 943,
        name: "Male Customer",
        scope: :shared,
        unique_name: "Male Customer#ve2"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Male Customer]")
    |> mes("How can that ugly old")
    |> mes("man have girls hanging")
    |> mes("off his arms when I just")
    |> mes("got dumped by my girlfriend")
    |> mes("and ditched by all my friends?!")
    |> next()
    |> mes("[Male Customer]")
    |> mes("Oh, alcohol...")
    |> mes("Right now, you're")
    |> mes("my only friend in")
    |> mes("all the world...")
    |> mes("A toast... To drinking!")
    |> specialeffect(:aspersio)
    |> close()
  end
end
