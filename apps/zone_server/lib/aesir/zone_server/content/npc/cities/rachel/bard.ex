defmodule Aesir.ZoneServer.Content.Npc.Cities.Rachel.Bard do
  @moduledoc """
  Sings an ill-advised song about Rachel's pope.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Tsuyuki and Harp
    - L0ne_W0lf
    - Lupus
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "rachel",
        x: 197,
        y: 137,
        dir: 3,
        sprite: 51,
        name: "Bard",
        scope: :shared,
        unique_name: "Bard#aru"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx =
      ctx
      |> mes("[Bard]")
      |> mes("I've wandered this")
      |> mes("land, singing my songs~")
      |> mes("Searching for someone")
      |> mes("for my heart longs~")
      |> next()
      |> mes("[Bard]")
      |> mes("Can I fulfill this hope~?")
      |> mes("Meeting the girl with")
      |> mes("skin as white as lilies,")
      |> mes("eyes sparkling like stars~")
      |> mes("Yes, I'm talking about the pope~")
      |> mes("Pope, yeah~ Pope, yeah~")
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("You must be off your")
    |> mes("rocker singing that")
    |> mes("kind of song here")
    |> mes("in Arunafeltz!")
    |> next()
    |> mes(".........")
    |> mes(".........")
    |> mes(".........")
    |> emotion(:cry)
    |> close()
  end
end
