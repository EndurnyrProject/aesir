defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests132.CapturedLaphine do
  @moduledoc """
  Tells the captured Laphine's story as she recovers.

  ## Behavior

  - Changes dialogue with quest progress and access to the local language.
  - Advances Terra's rescue story after the conversation.

  ## Credits

  - Original from rAthena, authors and contributors:
    - L0ne_W0lf
    - Gepard
    - Masao
    - Euphy
    - Joseph
    - Jeybla
    - Mazvi

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "man_in01",
        x: 22,
        y: 126,
        dir: 3,
        sprite: 441,
        name: "Captured Laphine",
        scope: :shared,
        unique_name: "Captured Laphine#ep13md"
      }
    ]

  @impl true
  def on_talk(ctx) do
    progress = get_char_var(ctx, :ep13_mdrama, 0)

    cond do
      checkweight(ctx, [{1201, 2}]) == 0 -> overweight(ctx)
      is_equipped(ctx, 2782) == 1 -> translated_talk(ctx, progress)
      progress < 19 -> unconscious(ctx)
      true -> untranslated_talk(ctx)
    end
  end

  defp overweight(ctx) do
    ctx
    |> mes("Wait a moment!!")
    |> mes("You have too many items.")
    |> mes("You can't receive this.")
    |> mes("Lighten your weight and")
    |> mes("try again.")
    |> close()
  end

  defp unconscious(ctx) do
    ctx
    |> mes("She's unconscious.")
    |> mes("I can see a bandage to stop the bleeding...")
    |> mes("Looks like Luik did it.")
    |> close()
  end

  defp untranslated_talk(ctx) do
    ctx
    |> mes("[Luik]")
    |> mes("Ier er ee ras d?")
    |> mes("Ye ada sd?")
    |> mes("Nffd..?")
    |> next()
    |> mes("[Wounded Laphine]")
    |> mes("...Riveh...AshIman Or mah...")
    |> mes("..ah..Thor..ThorOsa Yee Lu..ung...")
    |> close()
  end

  defp translated_talk(ctx, progress) when progress < 19, do: unconscious(ctx)
  defp translated_talk(ctx, 19), do: wake_terra(ctx)

  defp translated_talk(ctx, 20) do
    ctx
    |> mes("[Luik]")
    |> mes("Let that Fairy rest for a while, now tell me what you were talking about.")
    |> close()
  end

  defp translated_talk(ctx, progress) when progress > 20 and progress < 24 do
    ctx
    |> mes("[Luik]")
    |> mes("She's just too exhausted and fell asleep...")
    |> mes("Leave her alone.")
    |> close()
  end

  defp translated_talk(ctx, _progress) do
    ctx
    |> mes("[Luik]")
    |> mes("She can leave any time she likes.")
    |> mes("It feels so dry in here.")
    |> mes("Oh well, that's normal.")
    |> close()
  end

  defp wake_terra(ctx) do
    ctx =
      ctx
      |> mes("Luik and Snorren did everything to extract juice out of a Yggdrasilberry")
      |> mes("chopped and stuffed it into a mouth and paste them on the body...")
      |> next()
      |> mes("[Wounded Laphine]")
      |> mes("Hmm...")
      |> next()
      |> mes("[Luik]")
      |> mes("Finally she's coming to.")

    {ctx, choice} =
      ctx
      |> mes("Ok, #{char_name(ctx, 0)}, it's up to you now.")
      |> mes("And you better not fake any of the words she's saying.")
      |> next()
      |> mes("- I nod to Luik and began talking to the Laphine. -")
      |> next()
      |> mes(
        "- After the Laphine gained her full consciousness, she gazed around and spoke in shaky voice. -"
      )
      |> next()
      |> mes("[Wounded Laphine]")
      |> mes("Where... am I?")
      |> mes("Oh My! That's right! I need Bradium!")
      |> mes("Get me out of here!")
      |> next()
      |> mes("[Wounded Laphine]")
      |> mes("If I don't go back to him quickly, he... he is going to die!!")
      |> next()
      |> select(["Who is HE?", "Is your name Terra?"])

    case choice do
      1 -> ask_about_him(ctx)
      2 -> ask_her_name(ctx)
      _ -> ctx
    end
  end

  defp ask_about_him(ctx) do
    {ctx, _} =
      ctx
      |> plea("[Wounded Laphine]")
      |> select(["You are Terra. Right?"])

    ctx
    |> terra_asks_who()
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Arc asked me to find you. So I came here.")
    |> mes("By the way.. You were saying about a giant, do you mean a Sapha?")
    |> next()
    |> finish_conversation()
  end

  defp ask_her_name(ctx) do
    ctx
    |> terra_asks_who()
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("I came looking for you on behalf of Arc.")
    |> mes("Just how did you end up here?")
    |> next()
    |> mes("[Terra]")
    |> mes("To find a... Bra.. dium.")
    |> mes("That's right. Bradium! Give me a bradium!!")
    |> next()
    |> plea("[Terra]")
    |> finish_conversation()
  end

  defp terra_asks_who(ctx) do
    ctx
    |> mes("[Terra]")
    |> mes("How...How do you know my name?")
    |> mes("Who are you?")
    |> next()
  end

  defp plea(ctx, speaker) do
    ctx
    |> mes(speaker)
    |> mes("A giant... a giant in a cave...")
    |> mes("He...He got hurt trying to protect me...")
    |> mes("He wouldn't move!")
    |> mes("His body was getting cold.")
    |> next()
    |> mes(speaker)
    |> mes("We were each other's enemy......")
    |> mes("but he saved me...")
    |> mes("I heard they need a bradium to live!")
    |> next()
    |> mes(speaker)
    |> mes("Give me some bradium. Hurry!")
    |> mes("I can't be late!")
    |> next()
  end

  defp finish_conversation(ctx) do
    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("The Sapha in the cave...")
    |> mes("His body was already petrified when I got there.")
    |> next()
    |> mes("[Terra]")
    |> mes("Giants.. It is said that the Sapha people are cursed to be petrified.")
    |> mes("And that the Bradium is what prevents them from becoming petrified.")
    |> next()
    |> mes("[Terra]")
    |> mes("So I tried to bring a bradium to him... ...")
    |> mes("But he... Sob...")
    |> next()
    |> mes(
      "- Terra couldn't continue to talk as she was agonizing in the pain from her wounds. -"
    )
    |> next()
    |> mes("[Luik]")
    |> mes("Why did she break down like that? What did she say?")
    |> mes("Tell me what she said!!!")
    |> set_char_var(:ep13_mdrama, 20)
    |> close()
  end
end
