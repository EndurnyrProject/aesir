defmodule Aesir.ZoneServer.Content.Npc.Cities.Geffen.Orwalk do
  @moduledoc """
  Shares theories about Yggdrasil and another miraculous tree near Comodo.

  ## Credits

  - Original from rAthena, authors and Contributors
    - massdriller
    - Nexon
    - MasterOfMuppets
    - Silent
    - Musashiden
    - Evera
    - L0ne_W0lf
    - Lesbian
    - Lupus
    - Samuray22
    - DeadlySilence

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [%{map: "geffen", x: 156, y: 190, dir: 0, sprite: 82, name: "Orwalk", scope: :shared}]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Orwalk]")
    |> mes("...Interesting.")
    |> mes("Most intriguing.")
    |> mes("Oh! Let me tell you")
    |> mes("this marvelous story~")
    |> next()
    |> mes("[Orwalk]")
    |> mes(
      "While I was researching magic, I discovered this mysterious scroll. It describes this tree named Yggdrasil."
    )
    |> next()
    |> mes("[Orwalk]")
    |> mes(
      "The leaves, seeds and fruit of Yggdrasil link every living thing in this world. According to this scroll, Yggdrasil is also involved in the creation of the world."
    )
    |> next()
    |> mes("[Orwalk]")
    |> mes(
      "Speaking of which, I've also heard of a rumor about a miraculous tree in some land near Comodo. They must be connected, I'm sure of it!"
    )
    |> close()
  end
end
