defmodule Aesir.ZoneServer.Content.Npc.Airports.Airships.Pilot221158 do
  @moduledoc """
  Shares one of several remarks from the international airship cockpit.

  ## Behavior

  - Randomly comments on navigation, weather, Captain Tarlock, or his uniform.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "airplane_01",
        x: 221,
        y: 158,
        dir: 2,
        sprite: 852,
        name: "Pilot",
        scope: :shared,
        unique_name: "Pilot#airplane_01"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    case Enum.random(1..4) do
      1 -> navigation_report(ctx)
      2 -> weather_report(ctx)
      3 -> discuss_captain(ctx)
      _ -> discuss_uniform(ctx)
    end
  end

  defp navigation_report(ctx) do
    ctx
    |> mes("[Pilot]")
    |> mes("Longitude, 131 degrees east.")
    |> mes("Latitude, 37 degrees north.")
    |> mes("We're right on course, captain.")
    |> close()
  end

  defp weather_report(ctx) do
    ctx
    |> mes("[Pilot]")
    |> mes("Looks like a really")
    |> mes("cloudy day. Always hard")
    |> mes("to navigate when the skies")
    |> mes("aren't clear. Guess we'll")
    |> mes("need to amp the radar.")
    |> close()
  end

  defp discuss_captain(ctx) do
    ctx
    |> mes("[Pilot]")
    |> mes("The Captain is a good")
    |> mes("man and I can't think of")
    |> mes("a finer person to command")
    |> mes("this ship. Still, he's pretty")
    |> mes("tough, a real slave driver.")
    |> next()
    |> mes("[^ff0000Tarlock^000000]")
    |> mes("^ff0000Hey...!^000000")
    |> mes("^ff0000Less chit-chat^000000")
    |> mes("^ff0000and more piloting!^000000")
    |> next()
    |> mes("[Pilot]")
    |> mes("R-right away, sir!")
    |> mes("(See what I mean?)")
    |> close()
  end

  defp discuss_uniform(ctx) do
    ctx
    |> mes("[Pilot]")
    |> mes("This uniform is")
    |> mes("really dapper, but")
    |> mes("it's way too thick to")
    |> mes("wear around the Airship.")
    |> next()
    |> mes("[Pilot]")
    |> mes("...")
    |> mes("......")
    |> mes("No one ever really")
    |> mes("comes into this room.")
    |> mes("And the captain IS a reindeer.")
    |> mes("I could just strip to my boxers.")
    |> next()
    |> emotion(:huk)
    |> mes("[Pilot]")
    |> mes("Oh...! Hello there!")
    |> mes("E-e-enjoying your flight?!")
    |> close()
  end
end
