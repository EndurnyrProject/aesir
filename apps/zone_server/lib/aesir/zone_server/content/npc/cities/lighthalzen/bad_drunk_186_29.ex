defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.BadDrunk18629 do
  @moduledoc """
  Shares Bonse's drunken praise for the local rum.

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
        map: "lhz_in03",
        x: 186,
        y: 29,
        dir: 7,
        sprite: 869,
        name: "Bad Drunk",
        scope: :shared,
        unique_name: "Bad Drunk#12"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Bonse]")
    |> mes("*Hiccup* I loooove")
    |> mes("this rum! I caught a cold")
    |> mes("once and one glass made")
    |> mes("it go away! 'Course, I slept")
    |> mes("for a week too, but that don't")
    |> mes("matter! Pshaw! Science...")
    |> next()
    |> mes("[Bonse]")
    |> mes("Oh, the flavor is just")
    |> mes("so clean, but it's also")
    |> mes("got a bit of a kick. I don't")
    |> mes("know how to describe it.")
    |> mes("Its the taste of happiness?")
    |> mes("I'm too drunk to even tell!")
    |> close()
  end
end
