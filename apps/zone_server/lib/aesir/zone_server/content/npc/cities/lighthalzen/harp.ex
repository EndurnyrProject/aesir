defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Harp do
  @moduledoc """
  Shares Harp's infatuation with a Kafra employee.

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
        map: "lhz_in02",
        x: 221,
        y: 276,
        dir: 1,
        sprite: 869,
        name: "Harp",
        scope: :shared,
        unique_name: "Harp#zen8"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Harp]")
    |> mes("Oh sweet jiminy...")
    |> mes("That Kafra Lady is so hot.")
    |> mes("What a body. And those glasses.")
    |> mes("I just gotta ask her out somehow.")
    |> next()
    |> mes("[Harp]")
    |> mes("Hm, but what should")
    |> mes("I do? A love letter? Naw,")
    |> mes("that's kind of outdated.")
    |> mes("Argh, I can't think! Just")
    |> mes("looking at her makes me feel")
    |> mes("so happy! Praise be to Kafra!")
    |> close()
  end
end
