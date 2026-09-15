defmodule Aesir.ZoneServer.Content.Npc.Airports.Airships.Pilot do
  @moduledoc """
  Shares one of several remarks from the domestic airship cockpit.

  ## Behavior

  - Responds to a Hugel quest inquiry about a passenger named Thierry.
  - Otherwise comments randomly on drinking, weather, the captains, or pilot training.

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
        map: "airplane",
        x: 221,
        y: 158,
        dir: 2,
        sprite: 852,
        name: "Pilot",
        scope: :shared,
        unique_name: "Pilot#airplane"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if get_char_var(ctx, :hg_ma1, 0) == 3 do
      answer_thierry_inquiry(ctx)
    else
      random_remark(ctx)
    end
  end

  defp answer_thierry_inquiry(ctx) do
    {ctx, _choice} =
      ctx
      |> mes("[Pilot]")
      |> mes("I wish that I could go drink a cold fresh beer.")
      |> mes("Drinking is the goal of my life! Drinking gives me energy!")
      |> mes("I am nothing without drinks!")
      |> next()
      |> mes("[Pilot]")
      |> mes("But! Driving under the influence is not good.")
      |> mes("But! That makes me want to drink more and more!")
      |> emotion(:cry)
      |> next()
      |> select(["Do you know a passenger named Thierry?"])

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
    |> mes("And the captain IS a reindeer. I could just strip to my boxers.")
    |> next()
    |> emotion(:huk)
    |> mes("[Pilot]")
    |> mes("Wah!? Who is it!")
    |> next()
    |> mes("- ...He is not listening to you, at all. -")
    |> close()
  end

  defp random_remark(ctx) do
    case Enum.random(1..4) do
      1 -> discuss_drinking(ctx)
      2 -> discuss_weather(ctx)
      3 -> discuss_captains(ctx)
      _ -> discuss_training(ctx)
    end
  end

  defp discuss_drinking(ctx) do
    ctx
    |> mes("[Pilot]")
    |> mes("It's been sooo")
    |> mes("long since I've")
    |> mes("enjoyed a nice, cold")
    |> mes("alcoholic brew. But the")
    |> mes("job requires me to be as")
    |> mes("clear headed as I can!")
    |> next()
    |> mes("[Pilot]")
    |> mes("Always drink responsibly!")
    |> mes("Still, I can't remember the")
    |> mes("last time I had a real vacation")
    |> mes("or even a day off. Yeap, some")
    |> mes("booze, some chips, some TV")
    |> mes("and serious R&R is in order.")
    |> emotion(:cry)
    |> close()
  end

  defp discuss_weather(ctx) do
    ctx
    |> mes("[Pilot]")
    |> mes("Man, the weather")
    |> mes("is really nice today.")
    |> mes("Bright, open skies make")
    |> mes("for some good visibility")
    |> mes("and safe, carefree flying.")
    |> close()
  end

  defp discuss_captains(ctx) do
    ctx
    |> mes("[Pilot]")
    |> mes("You know, our captain's a")
    |> mes("respectable guy. Him and")
    |> mes("his brother are actually well")
    |> mes("known in the aircraft industry.")
    |> mes("Who knew reindeer made")
    |> mes("such good captains?")
    |> next()
    |> mes("[Pilot]")
    |> mes("Just between you")
    |> mes("and me, I gotta tell")
    |> mes("you, that Santa was onto")
    |> mes("something, getting reindeers")
    |> mes("and elves to work for him.")
    |> mes("The man must be a genius!")
    |> close()
  end

  defp discuss_training(ctx) do
    ctx
    |> mes("[Pilot]")
    |> mes("You know, this whole")
    |> mes("piloting thing in the air,")
    |> mes("it's rather new, you know?")
    |> mes("Yeah, they got this Airship")
    |> mes("operation in a hurry.")
    |> next()
    |> emotion(:huk)
    |> mes("[Pilot]")
    |> mes("Still, they were real")
    |> mes("serious, really thought")
    |> mes("ahead. I mean, they had us")
    |> mes("training while the Airships")
    |> mes("were still being invented.")
    |> mes("Isn't that freakin' crazy?!")
    |> close()
  end
end
