defmodule Aesir.ZoneServer.Content.Npc.Cities.Payon.Waitress do
  @moduledoc """
  Complains about pub work and answers questions about Payon before lamenting her love life.

  ## Behavior

  - Tailors her romantic complaint to the visitor's sex.
  - Discusses zombies, the fortune teller, or the pub's lack of alcohol.
  - Ends every topic with the same tearful farewell.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Muad Dib
    - Darkchild
    - DracoRPG
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "payon_in01",
        x: 180,
        y: 7,
        dir: 2,
        sprite: 90,
        name: "Waitress",
        scope: :shared,
        unique_name: "Waitress#payon"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx =
      ctx
      |> mes("[Pub Lady]")
      |> mes(
        "This place is always bustling with busy people. Little Novices come and go to become Archers, and everyone else is buying arrows while I have to stay here in this small shop."
      )
      |> next()
      |> mes("[Pub Lady]")
      |> mes(
        "And I'm sick and tired of making this noodle soup. I have to shower all the time so I can get rid of the smell. And it's not so easy"
      )
      |> mes("to get rid of.")
      |> next()
      |> mes("[Pub Lady]")
      |> mes("I feel so...")
      |> mes("Bored.")
      |> mes("And lonely...")
      |> next()
      |> mes("[Pub Lady]")
      |> lament_loneliness()

    {ctx, choice} =
      ctx
      |> next()
      |> mes("[Pub Lady]")
      |> mes(
        "The old fortune teller told me that I'd have great luck in the near future! But what's wrong with me? I'm just living day to day. Maybe I'm just dumb and wishy-washy."
      )
      |> next()
      |> mes("[Pub Lady]")
      |> mes("I'm so sorry,")
      |> mes("I've said too much.")
      |> mes("Now I'm just acting stupid.")
      |> mes("I'm sorry you had to listen")
      |> mes("to all that.")
      |> next()
      |> mes("[Pub Lady]")
      |> mes("So...")
      |> mes("How may I help you? ")
      |> next()
      |> select(["Have you ever heard of Zombies?", "Fortune Teller...?", "I needs some booze."])

    ctx
    |> answer_topic(choice)
    |> farewell()
  end

  defp lament_loneliness(ctx) do
    if sex(ctx) == get_char_var(ctx, :SEX_MALE, 0) do
      mes(
        ctx,
        "Where I can find the right person, a hot and Sexy hunk who can take me away from here? Um, hey mister, are you listening?"
      )
    else
      ctx
      |> mes(
        "Where I can find the right person, a cute, yet hard-bodied hunk who can take me away from here?"
      )
      |> mes("Um, hey lady, are")
      |> mes("you listening?")
    end
  end

  defp answer_topic(ctx, 1) do
    ctx
    |> mes("[Pub Lady]")
    |> mes("Of course I've")
    |> mes("heard of Zombies!")
    |> mes("This is Payon, after all.")
    |> mes("Zombies are the walking")
    |> mes("Undead, and you can easily")
    |> mes("find them around here.")
    |> next()
    |> mes("[Pub Lady]")
    |> mes(
      "I hear that they fear holiness, so Archers prefer to use arrow made out of silver, a holy metal, against them."
    )
    |> next()
    |> mes("[Pub Lady]")
    |> mes(
      "Legend says that the chief of this town used silver arrows against Zombies that used to be his brethren in order to release their souls so that they may rest in peace."
    )
    |> next()
    |> mes("[Pub Lady]")
    |> mes("We believe that exorcising")
    |> mes(
      "Zombies in this way will lead them peacefully to the afterlife. Their souls no longer need to anguish."
    )
    |> next()
    |> mes("[Pub Lady]")
    |> mes(
      "You might not share our beliefs, but my grandfather was one of the Undead. I appreciate that the chief was able to free him from being bound to the world of the living."
    )
  end

  defp answer_topic(ctx, 2) do
    ctx
    |> mes("[Pub Lady]")
    |> mes(
      "Oh! Our fortune teller is a really extraordinary person. Well, she doesn't hang around here as"
    )
    |> mes("much as she used to do. ")
    |> next()
    |> mes("[Pub Lady]")
    |> mes(
      "She used to stay here to tell fortunes for our patrons, but ever since the chief recognized her talents, she now stays in the Central Palace. So you'd better go there if you want to see her."
    )
  end

  defp answer_topic(ctx, 3) do
    ctx
    |> mes("[Pub Lady]")
    |> mes("You...")
    |> mes("needs some")
    |> mes("booze, eh?")
    |> mes("Don't we all?")
    |> next()
    |> mes("[Pub Lady]")
    |> mes("But I'm so sorry, we sold out.")
    |> mes(
      "And we can't afford to prepare alcohol anymore because of the hostile creatures out there. But please come again later. I'm sorry for the inconvenience."
    )
  end

  defp answer_topic(ctx, _choice), do: ctx

  defp farewell(ctx) do
    ctx
    |> next()
    |> mes("[Pub Lady]")
    |> mes("Have a nice")
    |> mes("day, dearie.")
    |> next()
    |> mes("[Pub Lady]")
    |> mes("^666666*Sob*^000000")
    |> mes("When will I be romanced")
    |> mes("by my perfectly formed,")
    |> mes("yet well read man?")
    |> close()
  end
end
