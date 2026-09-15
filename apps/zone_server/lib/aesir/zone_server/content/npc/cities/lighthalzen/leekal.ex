defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Leekal do
  @moduledoc """
  Shares Leekal's remarks with visitors to Lighthalzen.

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
        map: "lhz_in01",
        x: 125,
        y: 46,
        dir: 3,
        sprite: 849,
        name: "Leekal",
        scope: :shared,
        unique_name: "Leekal#lackee"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Leekal]")
    |> mes("So... Very broke.")
    |> mes("Why did I spend so much")
    |> mes("money on wine, women and")
    |> mes("song? I regret it all, all the")
    |> mes("pleasure I've had this month.")
    |> mes("Yes, it was too much pleasure.")
    |> next()
    |> mes("[Ninjose]")
    |> mes("That's what happens")
    |> mes("when you're irresponsible")
    |> mes("with your money. You really")
    |> mes("should read this ''Anybody")
    |> mes("Can Be Rich'' book.")
    |> close()
  end
end
