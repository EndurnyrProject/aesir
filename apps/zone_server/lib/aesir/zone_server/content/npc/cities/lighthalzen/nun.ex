defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Nun do
  @moduledoc """
  Shares Nun's remarks with visitors to Lighthalzen.

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
        x: 330,
        y: 276,
        dir: 3,
        sprite: 79,
        name: "Nun",
        scope: :shared,
        unique_name: "Nun#light"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Angela]")
    |> mes("Greetings, adventurer.")
    |> mes("I'm Angela, a social")
    |> mes("worker for the Poor")
    |> mes("Relief Organization.")
    |> next()
    |> mes("[Angela]")
    |> mes("I've noticed that the")
    |> mes("people living here have")
    |> mes("extremely bad health and")
    |> mes("it's not just because of")
    |> mes("their circumstances.")
    |> next()
    |> mes("[Angela]")
    |> mes("I've filed a report")
    |> mes("to my superiors, but")
    |> mes("they haven't sent me")
    |> mes("a response yet for some")
    |> mes("reason. I'm starting to get")
    |> mes("a little worried about this...")
    |> close()
  end
end
