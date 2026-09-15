defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Sigmund do
  @moduledoc """
  Shares Sigmund's remarks with visitors to Lighthalzen.

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
        map: "lighthalzen",
        x: 232,
        y: 156,
        dir: 3,
        sprite: 869,
        name: "Sigmund",
        scope: :shared,
        unique_name: "Sigmund#zen3"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Sigmund Ting]")
    |> mes("You know what I noticed?")
    |> mes("The guards at the border")
    |> mes("to the slum seem distracted")
    |> mes("sometimes. I made use of one")
    |> mes("of their less attentive moments")
    |> mes("and basically jumped the fence!")
    |> next()
    |> mes("[Sigmund Ting]")
    |> mes("But once I was in the ")
    |> mes("slums, I was pretty bored.")
    |> mes("There really isn't much to")
    |> mes("do there. Which makes me")
    |> mes("wonder... Why guard it?")
    |> close()
  end
end
