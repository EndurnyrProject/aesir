defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.BadDrunk do
  @moduledoc """
  Lets Garry struggle to remember a joke while drunk.

  ## Credits

  - Original from rAthena, authors and Contributors
    - erKURITA
    - Au{R}oN (Translated by Alan)
    - $ephiroth

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lhz_in03",
        x: 185,
        y: 20,
        dir: 6,
        sprite: 869,
        name: "Bad Drunk",
        scope: :shared,
        unique_name: "Bad Drunk#amano06",
        trigger: {2, 2}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Garry]")
    |> mes("Hey! Hey you...!")
    |> mes("D'you wanna, you")
    |> mes("wanna hear me tell")
    |> mes("you a joke?! It goes...")
    |> mes("Um, it goes like this...")
    |> next()
    |> mes("[Garry]")
    |> mes("Hey riddle middle,")
    |> mes("the cat and th--")
    |> mes("No! No, damn it!")
    |> mes("That's a song!")
    |> mes("No, wait, that's")
    |> mes("not a song either...")
    |> close()
  end
end
