defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAyothaya.Dusit do
  @moduledoc """
  Dusit tells visitors the legend of the Sa-mhing Tiger.

  ## Behavior

  - Refers interested listeners to Boonthom and starts the quest.
  - Reminds visitors about Boonthom after the quest starts.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Fredzilla
    - MasterOfMuppets
    - Lupus
    - Silent
    - Evera
    - SinSloth
    - L0ne_W0lf
    - Samuray22
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ayothaya",
        x: 83,
        y: 132,
        dir: 0,
        sprite: 843,
        name: "Dusit",
        scope: :shared,
        unique_name: "Dusit#thai"
      }
    ]

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :ayodunquest, 0) do
      0 -> introduction(ctx)
      progress when progress > 0 -> reminder(ctx)
      _ -> ctx
    end
  end

  defp introduction(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Dusit]")
      |> mes("Oh...!")
      |> mes("You must be a traveller.")
      |> mes("I have a tale you may wish to hear if you're interested in listening.")
      |> next()
      |> select(["What is it?", "I know what the story is."])

    if choice == 1, do: tell_story(ctx), else: familiar_story(ctx)
  end

  defp tell_story(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Dusit]")
      |> mes(
        "Ayothaya has a long history. Perhaps it looks calm and peaceful now, but in the past our village was terrorized by a terrible creature."
      )
      |> next()
      |> mes("[Dusit]")
      |> mes("This beast is known to us as")
      |> mes("the ^660000Sa-mhing Tiger^000000, which used")
      |> mes("to dwell deep in the ancient ruins.")
      |> next()
      |> mes("[Dusit]")
      |> mes("The Sa-mhing Tiger is addicted")
      |> mes(
        "to the taste of human flesh. It has been known to transform into the shape of a person it has eaten in order to lure out his family and friends."
      )
      |> next()
      |> mes("[Dusit]")
      |> mes(
        "The local people are still afraid that the creature might transform into someone they know, and sneak into their homes to eat them."
      )
      |> next()
      |> mes("[Dusit]")
      |> mes(
        "However, there is one way you can identify the Sa-mhing Tiger from a human being. Since it's a tiger, it cannot do some of the things"
      )
      |> mes("humans are taught to do,")
      |> mes("such as light a match.")
      |> next()
      |> mes("[Dusit]")
      |> mes("So, if by any chance you see")
      |> mes("a friend acting strangely all")
      |> mes("of a sudden, ask him to strike")
      |> mes("a match. Make sure he is not")
      |> mes("the Sa-mhing Tiger.")
      |> next()
      |> mes("[Dusit]")
      |> mes("However...")
      |> mes(
        "I'm not sure if this actually works or not. I guess the best thing to do is just run for your life if you even suspect someone of being"
      )
      |> mes("the Sa-mhing Tiger.")
      |> next()
      |> mes("[Dusit]")
      |> mes("Do you believe")
      |> mes("in the existance")
      |> mes("of man-eating tigers?")
      |> next()
      |> select(["Well, not really.", "Yes, I do and I think they're scary!"])

    if choice == 1, do: skeptical(ctx), else: referral(ctx)
  end

  defp skeptical(ctx) do
    ctx
    |> mes("[Dusit]")
    |> mes("Umm...")
    |> mes("Oh well. My late grandfather told me about the Sa-mhing Tiger when")
    |> mes("I was a little kid. Of course,")
    |> mes("I haven't seen it.")
    |> next()
    |> mes("[Dusit]")
    |> mes(
      "The closest thing I've seen to the Sa-mhing Tiger was a golden cat with a bell. Somehow, I don't think it ate men."
    )
    |> close()
  end

  defp referral(ctx) do
    ctx
    |> mes("[Dusit]")
    |> mes("Run for your life if you ever encounter the Sa-mhing Tiger!")
    |> mes("It'll eat you alive!")
    |> next()
    |> mes("[Dusit]")
    |> mes("If you're interested in finding")
    |> mes("out more about the story, I can introduce you to someone who")
    |> mes("knows that creature more than")
    |> mes("anyone else.")
    |> next()
    |> mes("[Dusit]")
    |> mes(
      "Why don't you talk to Boonthom? He's a pretty strange person, but there's something about him..."
    )
    |> next()
    |> mes("[Dusit]")
    |> mes("...")
    |> mes("......")
    |> next()
    |> mes("[Dusit]")
    |> mes(
      "Ah well, you'll see what I'm talking about. I hope he'll help you learn more about that evil creature."
    )
    |> set_char_var(:ayodunquest, 1)
    |> setquest(12035)
    |> close()
  end

  defp familiar_story(ctx) do
    ctx
    |> mes("[Dusit]")
    |> mes("You do now?")
    |> mes("Then be careful!")
    |> mes("It'll eat you alive!")
    |> close()
  end

  defp reminder(ctx) do
    ctx
    |> mes("[Dusit]")
    |> mes("How are you?")
    |> mes("If you're interested")
    |> mes("in the Sa-mhing Tiger,")
    |> mes("please go talk to Boonthom.")
    |> next()
    |> mes("[Dusit]")
    |> mes("But beware!")
    |> mes("The Sa-mhing Tiger might be")
    |> mes("closer to you than you expect!")
    |> close()
  end
end
