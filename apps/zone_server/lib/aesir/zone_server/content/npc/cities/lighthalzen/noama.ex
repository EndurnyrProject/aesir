defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Noama do
  @moduledoc """
  Shares Noama's remarks with visitors to Lighthalzen.

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
        x: 148,
        y: 45,
        dir: 3,
        sprite: 97,
        name: "Noama",
        scope: :shared,
        unique_name: "Noama#amano"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Noama]")
    |> mes("Hee hee~!")
    |> mes("You wanna hear")
    |> mes("something funny?")
    |> mes("I heard there's a bar in")
    |> mes("Prontera where this guy")
    |> mes("sneaks singles into Jawa--")
    |> next()
    |> mes("[Mazwon]")
    |> mes("Noama...!")
    |> mes("These machines are")
    |> mes("acting up again! Get")
    |> mes("over here right now!")
    |> next()
    |> mes("[Noama]")
    |> mes("What?!")
    |> mes("Stop bugging me,")
    |> mes("I didn't do anything!")
    |> close()
  end
end
