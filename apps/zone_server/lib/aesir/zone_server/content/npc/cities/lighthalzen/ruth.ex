defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Ruth do
  @moduledoc """
  Shares Ruth's remarks with visitors to Lighthalzen.

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
        x: 261,
        y: 112,
        dir: 3,
        sprite: 862,
        name: "Ruth",
        scope: :shared,
        unique_name: "Ruth#zen4"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx =
      ctx
      |> mes("[Ruth]")
      |> mes("Sweety, isn't it")
      |> mes("nice to be together")
      |> mes("under this beautiful")
      |> mes("sunlight? It's perfect")
      |> mes("for our date. Ahhhh~")
      |> next()
      |> mes("[Ruth]")
      |> mes("I'm so happy to be")
      |> mes("with you. I feel like")
      |> mes("I'm just melting with")
      |> mes("happiness. Oh, I love")
      |> mes("you so much, Oyoung.")
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Whoa...")
    |> mes("This couple is")
    |> mes("really headed for")
    |> mes("Cloud 9, aren't they?")
    |> close()
  end
end
