defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.VictorPerfecto do
  @moduledoc """
  Shares Victor Perfecto's remarks with visitors to Lighthalzen.

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
        x: 77,
        y: 203,
        dir: 3,
        sprite: 869,
        name: "Victor Perfecto",
        scope: :shared,
        unique_name: "Victor Perfecto#zen9"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Victor Perfecto]")
    |> mes("I've heard that the")
    |> mes("Rekenber Corporation")
    |> mes("actually created the")
    |> mes("environment in Lighthalzen")
    |> mes("through artificial means.")
    |> next()
    |> mes("[Victor Perfecto]")
    |> mes("It seems like it'd take")
    |> mes("a lot of investment, but")
    |> mes("artificially creating an")
    |> mes("environment isn't impossible")
    |> mes("with the means available to")
    |> mes("the Rekenber Corporation.")
    |> next()
    |> mes("[Victor Perfecto]")
    |> mes("^333333*Sigh...*^000000")
    |> mes("Still, it's pretty")
    |> mes("depressing to think")
    |> mes("that the beauty of nature")
    |> mes("can be man-made and")
    |> mes("equated to zeny, you know?")
    |> close()
  end
end
