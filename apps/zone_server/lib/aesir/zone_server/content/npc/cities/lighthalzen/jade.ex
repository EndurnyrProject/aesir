defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Jade do
  @moduledoc """
  Discusses Jade's curiosity about Rune-Midgarts and its adventurers.

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
        x: 239,
        y: 64,
        dir: 5,
        sprite: 862,
        name: "Jade",
        scope: :shared,
        unique_name: "Jade#zen2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Jade]")
    |> mes("I've heard that there's a")
    |> mes("strange kingdom out there")
    |> mes("that's basically ruled by")
    |> mes("magic and swords, where")
    |> mes("adventurers are enlisted")
    |> mes("for the greater good.")
    |> next()
    |> mes("[Jade]")
    |> mes("So are you from")
    |> mes("Rune-Midgarts?")
    |> mes("What do you think")
    |> mes("of our city with its")
    |> mes("advanced technology")
    |> mes("and economy? Huh...")
    |> next()
    |> mes("[Jade]")
    |> mes("Someday, I'd like")
    |> mes("to go visit the land")
    |> mes("where you came from.")
    |> mes("It sounds so fantastic")
    |> mes("and romantic in a way...")
    |> close()
  end
end
