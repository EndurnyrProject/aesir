defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.Torpy do
  @moduledoc """
  Torpy asks adventurers to find his missing parents.

  ## Behavior

  - Begins and advances the Hide and Seek Quest for eligible adventurers.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - SinSloth
    - Samuray22
    - L0ne_W0lf
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [%{map: "hugel", x: 107, y: 67, dir: 3, sprite: 706, name: "Torpy", scope: :shared}]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    if base_level(ctx) > 49 do
      quest = get_char_var(ctx, :hg_ubu01, 0)

      if Rathena.truthy?(quest) do
        ongoing_quest(ctx, quest)
      else
        start_quest(ctx)
      end
    else
      ctx
      |> mes("[Torpy]")
      |> mes("Waaah~!")
      |> mes("I have to find")
      |> mes("my Daddy! Daddy...!")
      |> mes("Where are yooooou?!")
      |> close()
    end
  end

  defp ongoing_quest(ctx, quest) do
    case quest do
      2 ->
        ctx
        |> mes("[Torpy]")
        |> mes("Oh...")
        |> mes("Mommy was just")
        |> mes("outside of town?")
        |> mes("*Sob* Okay, I hope my")
        |> mes("Daddy comes back soon...")
        |> set_char_var(:hg_ubu01, 3)
        |> changequest(12045, 12046)
        |> close()

      6 ->
        ctx =
          ctx
          |> mes("[Torpy]")
          |> mes("Y-you found my Daddy!")
          |> mes("Hooray! I was so worried")
          |> mes("about him! Th-thank you")
          |> mes("so much for your help!")
          |> next()
          |> mes("[Torpy]")
          |> mes("Um, um, where is my")
          |> mes("Daddy hiding anyway?")
          |> mes("Oh? A barrel? Where")
          |> mes("was it again? Heh heh!")
          |> mes("Now I can find him!")
          |> next()
          |> mes("[Torpy]")
          |> mes("Oh, would you go talk")
          |> mes("to my Mom, and tell her")
          |> mes("to come here please? And")
          |> mes("also tell her that Daddy")
          |> mes("is safe! See you later~")
          |> next()

        ctx
        |> emotion(:think, playerattached(ctx))
        |> mes("......")
        |> mes(".........")
        |> mes("............")
        |> next()
        |> mes("[Torpy]")
        |> mes("^333333...............................")
        |> mes("Hee hee~ Once I find")
        |> mes("my Daddy, he has to get me")
        |> mes("a girlfriend! He promised~!^000000")
        |> set_char_var(:hg_ubu01, 7)
        |> close()

      7 ->
        ctx =
          ctx
          |> mes("[Torpy]")
          |> mes("Would you please hurry")
          |> mes("and talk to my Mom? She")
          |> mes("should be just outside of?")
          |> mes("this town, where you last")
          |> mes("saw her. Bye bye for now~")
          |> next()

        ctx
        |> emotion(:think, playerattached(ctx))
        |> mes("......")
        |> mes(".........")
        |> mes("............")
        |> next()
        |> mes("[Torpy]")
        |> mes("^333333...............................")
        |> mes("Oh yeah! Should I have")
        |> mes("Mom help me pick out my")
        |> mes("new girlfriend? Hmm, I dunno.")
        |> mes("Wh-what if they become friends?")
        |> mes("Um, that might not be good...^000000")
        |> close()

      8 ->
        ctx
        |> emotion(:think, playerattached(ctx))
        |> mes("[Torpy]")
        |> mes("Daddy promised to get")
        |> mes("me a girlfriend if I beat him")
        |> mes("at Hide-and-Seek! Hahaha!")
        |> mes("I won, so now he has to do it!")
        |> next()
        |> mes("[Torpy]")
        |> mes("Wait, but should I let")
        |> mes("my Dad pick my girlfriend?")
        |> mes("Maybe I should pick her...")
        |> mes("Yeah, I'll pick the perfectest")
        |> mes("girl that I can find! Yaaay~")
        |> set_char_var(:hg_ubu01, 9)
        |> close()

      9 ->
        ctx
        |> emotion(:think, playerattached(ctx))
        |> mes("[Torpy]")
        |> mes("Maybe I should wait until")
        |> mes("I'm older to have a girlfriend.")
        |> mes("I mean, what if the girl I pick")
        |> mes("now gets uglier when she")
        |> mes("grows up? Or what if she gets really fat? I better be careful...")
        |> next()
        |> mes("^3355FFTorpy is still a young,")
        |> mes("naive child that has much")
        |> mes("to learn about girlfriends,")
        |> mes("or just people, in general.^000000")
        |> close()

      _ ->
        ctx
        |> mes("[Torpy]")
        |> mes("^333333*Sniff*^000000 D-Daddy's gone!")
        |> mes("Will you help me find my")
        |> mes("Daddy please? I h-have")
        |> mes("to find him now! H-Hurry!")
        |> close()
    end
  end

  defp start_quest(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Torpy]")
      |> mes("D-Daddy...!")
      |> mes("Daddy where")
      |> mes("are you?! Wah~!")
      |> next()
      |> select(["What's wrong?", "Ignore"])

    case choice do
      1 ->
        ctx =
          ctx
          |> mes("[Torpy]")
          |> mes("My Daddy hasn't")
          |> mes("been home for a few")
          |> mes("day now. I'm afraid that")
          |> mes("something must have")
          |> mes("happened to him. *Sniff*")
          |> next()

        {ctx, follow_up} =
          ctx
          |> mes("[#{char_name(ctx, 0)}]")
          |> mes("Your Dad is missing?")
          |> mes("Why don't you tell me")
          |> mes("about the last time")
          |> mes("that you saw him?")
          |> next()
          |> mes("[Torpy]")
          |> mes("Well, we were playing")
          |> mes("Hide-and-Seek, and then")
          |> mes("it was his turn to hide,")
          |> mes("and then, a-and then...")
          |> mes("I never found him!")
          |> next()
          |> select(["Really? Tell me more...", "What, is that all...?"])

        case follow_up do
          1 ->
            ctx =
              ctx
              |> mes("[Torpy]")
              |> mes("Th-then my Mom got")
              |> mes("mad at Dad for hiding")
              |> mes("for so long. But when")
              |> mes("she went to find him, she")
              |> mes("disappeared too! I-I'm all")
              |> mes("alone now! Waaaaaah~!")
              |> next()

            ctx = emotion(ctx, :think, playerattached(ctx))

            ctx
            |> mes("[#{char_name(ctx, 0)}]")
            |> mes("Don't worry, I'll look")
            |> mes("for your parents. I'm")
            |> mes("sure that I can find at")
            |> mes("least one of them just")
            |> mes("outside of town.")
            |> set_char_var(:hg_ubu01, 1)
            |> setquest(12044)
            |> close()

          2 ->
            ctx =
              ctx
              |> mes("[#{char_name(ctx, 0)}]")
              |> mes("Don't worry, your")
              |> mes("Dad will probably")
              |> mes("show up sooner")
              |> mes("or later. Well, lots")
              |> mes("of luck, kid.")

            ctx |> emotion(:think, playerattached(ctx)) |> close()

          _ ->
            ctx
        end

      2 ->
        ctx
        |> mes("[Torpy]")
        |> mes("D-Daddy...!")
        |> mes("Mommiiiiiiiiie!")
        |> mes("Where are yoooou?!")
        |> mes("Wuh-Waaaaaaaaaah!")
        |> close()

      _ ->
        ctx
    end
  end
end
