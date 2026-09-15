defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Samnang do
  @moduledoc """
  Shares Samnang's remarks with visitors to Lighthalzen.

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
        x: 220,
        y: 244,
        dir: 3,
        sprite: 863,
        name: "Samnang",
        scope: :shared,
        unique_name: "Samnang#zen2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Samnang]")
    |> mes("^333333*Sigh...*^000000")
    |> mes("It gets harder for me")
    |> mes("to move around as I get")
    |> mes("older. That's understandable")
    |> mes("for an elderly person, right?")
    |> next()
    |> mes("[Samnang]")
    |> mes("Just the other day, these")
    |> mes("hoodlums in black suits")
    |> mes("were yelling at me to get out")
    |> mes("of their way. But of course,")
    |> mes("I didn't move quickly enough.")
    |> mes("So what did they do to me?")
    |> next()
    |> mes("[Samnang]")
    |> mes("They punched me.")
    |> mes("Right in the womb!")
    |> mes("I know that I'm not")
    |> mes("pregnant, but that's")
    |> mes("besides the point. Never hit")
    |> mes("a lady, especially an old one!")
    |> close()
  end
end
