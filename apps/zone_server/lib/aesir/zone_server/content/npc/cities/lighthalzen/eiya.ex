defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Eiya do
  @moduledoc """
  Shares Eiya's concern for Jorje and enthusiasm for doll collecting.

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
        x: 164,
        y: 45,
        dir: 3,
        sprite: 91,
        name: "Eiya",
        scope: :shared,
        unique_name: "Eiya#iaiai"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Eiya]")
    |> mes("Jorje seems so cranky")
    |> mes("recently. He's usually")
    |> mes("more laid back than this.")
    |> mes("Oh well, I hope that he")
    |> mes("feels better.")
    |> next()
    |> mes("[Eiya]")
    |> mes("Ooh, would you like")
    |> mes("to look at my miniature")
    |> mes("doll collection? I love")
    |> mes("collecting cute dolls!")
    |> close()
  end
end
