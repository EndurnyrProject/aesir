defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Mazwon do
  @moduledoc """
  Shares Mazwon's remarks with visitors to Lighthalzen.

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
        x: 147,
        y: 40,
        dir: 1,
        sprite: 828,
        name: "Mazwon",
        scope: :shared,
        unique_name: "Mazwon#minus1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Mazwon]")
    |> mes("Crap. Crap! Crap")
    |> mes("crap crap crap crap!")
    |> mes("These desk machines aren't")
    |> mes("supposed to work like this!")
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
