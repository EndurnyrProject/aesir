defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsEin.Calla do
  @moduledoc """
  Calla seeks help seeing her beloved Klitzer.

  ## Behavior

  - Advances the lovers' quest and rewards its completion with healing and experience.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Evera
    - MasterOfMuppets
    - Lupus
    - KarLaeda
    - SinSloth
    - L0ne_W0lf
    - Yommy
    - Paradox924X
    - Kisuka
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ein_in01",
        x: 31,
        y: 138,
        dir: 3,
        sprite: 90,
        name: "Calla",
        scope: :shared,
        unique_name: "Calla#ein"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    cond do
      checkweight(ctx, [{908, 70}]) == 0 ->
        ctx
        |> mes("^3355FFWait a second!")
        |> mes("Right now, you're carrying")
        |> mes("too many things with you.")
        |> mes("Please come back after")
        |> mes("using the Kafra Service")
        |> mes("to store some of your items.^000000")
        |> close()

      base_level(ctx) < 60 ->
        ctx
        |> mes("[Calla]")
        |> mes("Hello adventurer.")
        |> mes("Our city must just be")
        |> mes("another place where")
        |> mes("you'll stay no longer")
        |> mes("than a few days.")
        |> next()
        |> mes("[Calla]")
        |> mes("You must have so much")
        |> mes("freedom. I envy you. I can't")
        |> mes("do what I want to do. I don't")
        |> mes("even have the courage to tell")
        |> mes("my family what I really want,")
        |> mes("much less change things here...")
        |> next()
        |> mes("[Calla]")
        |> mes("How is it like?")
        |> mes("Going wherever you")
        |> mes("please, following your")
        |> mes("heart's true desire?")
        |> mes("What I would give to")
        |> mes("be able to do that...")
        |> close()

      get_char_var(ctx, :EIN_LOVERQ, 0) == 17 ->
        ctx
        |> mes("[Calla]")
        |> mes("Thank you so much!")
        |> mes("I'll try my best to convince")
        |> mes("my parents to accept our")
        |> mes("relationship. It'll be hard,")
        |> mes("but it's a good first step~")
        |> next()
        |> mes("[Calla]")
        |> mes("I hope that we can all")
        |> mes("work together to improve")
        |> mes("relations between Einbech")
        |> mes("and Einbroch. The hatred")
        |> mes("between our towns must end...")
        |> next()
        |> mes("[Calla]")
        |> mes("I really appreciate")
        |> mes("what you've done for")
        |> mes("all of us. I'll be praying")
        |> mes("for your safety, adventurer.")
        |> close()

      get_char_var(ctx, :EIN_LOVERQ, 0) == 16 ->
        ctx =
          ctx
          |> mes("[Calla]")
          |> mes("I just heard from my mother")
          |> mes("that she's planning to have")
          |> mes("tea with Klitzer! I'm sure that")
          |> mes("I have you to thank for this~")
          |> next()
          |> mes("[Calla]")
          |> mes("I never dreamed that")
          |> mes("something as wonderful")
          |> mes("as this could happen.")
          |> mes("I'm so happy, I could cry...")
          |> mes("I'll always be grateful")
          |> mes("for what you've done.")
          |> next()
          |> mes("[Calla]")
          |> mes("I feel like such a fool,")
          |> mes("thinking it was all hopeless.")
          |> mes("I'll be doing my best to have")
          |> mes("my parents accept Klitzer and")
          |> mes("someday we'll be married~")
          |> next()
          |> mes("[Calla]")
          |> mes("There isn't much that I can")
          |> mes("give you, but I can show you")
          |> mes("one of my family's secrets.")
          |> mes("It's an invigorating massage")
          |> mes("technique that makes you a lot")
          |> mes("healthier in only ten seconds.")
          |> next()
          |> mes("[Calla]")
          |> mes("Well, please take")
          |> mes("off your equipment")
          |> mes("and stand still while")
          |> mes("I give the massage. It")
          |> mes("might hurt a bit at first...")
          |> nude()
          |> next()
          |> mes("^3355FF*Rub Rub Rub*")
          |> mes("*Knead Knead Knead*")
          |> mes("*Crrack C-c-c--c-crack*")
          |> mes("*Crack Crack Crrrrrrack*")
          |> mes("*Rub Crrraaaaaaaaaack*^000000")
          |> next()

        ctx =
          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("Ooooooooh...")
          |> mes("I feel sooo")
          |> mes("sore and yet")
          |> mes("soooooo good.")
          |> mes("Wait. Now I just")
          |> mes("feel goooood~")
          |> percent_heal(hp: 100, sp: 0)
          |> set_char_var(:EIN_LOVERQ, 17)

        exp =
          if Rathena.truthy?(checkre(ctx, 3)) do
            cond do
              base_level(ctx) < 41 -> 61
              base_level(ctx) < 61 -> 600
              base_level(ctx) < 81 -> 3_000
              base_level(ctx) < 99 -> 20_000
              true -> 30_000
            end
          else
            cond do
              base_level(ctx) < 41 -> 610
              base_level(ctx) < 61 -> 6_000
              base_level(ctx) < 81 -> 30_000
              true -> 200_000
            end
          end

        ctx = getexp(ctx, exp, 0)

        ctx =
          ctx
          |> next()
          |> mes("[Calla]")
          |> mes("So how was it?")
          |> mes("I hope it was refreshing.")
          |> mes("Please understand that")
          |> mes("it's the best thing I can")
          |> mes("give you to show my gratitude.")
          |> next()
          |> mes("[Calla]")
          |> mes("Once again,")
          |> mes("thank you so")

        ctx
        |> mes(Rathena.concat(Rathena.concat("much, ", char_name(ctx, 0)), "."))
        |> mes("I'll always pray for")
        |> mes("your safety on your")
        |> mes("your adventures~")
        |> completequest(8088)
        |> close()

      get_char_var(ctx, :EIN_LOVERQ, 0) == 5 and count_item(ctx, 712) > 0 ->
        {ctx, name} =
          ctx
          |> mes("[Calla]")
          |> mes("You've spoken")
          |> mes("with Klitzer? How")
          |> mes("is he? What did he say?")
          |> next()
          |> mes("[Calla]")
          |> mes("Oh...?")
          |> mes("He asked you to")
          |> mes("deliver this flower")
          |> mes("to me? How sweet~")
          |> mes("Thank you very much,")
          |> mes("kind adventurer~")
          |> next()
          |> mes("[Calla]")
          |> mes("Ah, I'm so rude!")
          |> mes("I've been calling you")
          |> mes("''adventurer'' this whole")
          |> mes("time you've been helping")
          |> mes("me! Would you please")
          |> mes("tell me your name?")
          |> next()
          |> input(:string)

        if name == char_name(ctx, 0) do
          ctx = mes(ctx, "[Calla]")

          ctx
          |> mes(Rathena.concat(Rathena.concat("Ah, ", char_name(ctx, 0)), "!"))
          |> mes("Such a lovely name~")
          |> mes("I promise that I won't ever")
          |> mes(
            "forget it. Oh, and if you pass by Einbech, would you thank Klitzer for the flower for me please?"
          )
          |> next()
          |> mes("[Calla]")
          |> mes("A-and... And...")
          |> mes("Please tell him that")
          |> mes("I really miss him a lot.")
          |> mes("^333333*Sob Sob...*^000000")
          |> delitem(712, 1)
          |> set_char_var(:EIN_LOVERQ, 6)
          |> changequest(8079, 8080)
          |> close()
        else
          ctx
          |> mes("[Calla]")
          |> mes("I'm sorry...")
          |> mes("I didn't catch that.")
          |> mes("Would you please tell")
          |> mes("me your name again?")
          |> close()
        end

      get_char_var(ctx, :EIN_LOVERQ, 0) == 4 ->
        ctx
        |> mes("[Calla]")
        |> mes("Oh my god...")
        |> mes("Are you alright?")
        |> mes("I just found out that")
        |> mes("you ran into my father!")
        |> next()
        |> mes("[Calla]")
        |> mes("By all means,")
        |> mes("try to avoid my dad!")
        |> mes("He doesn't trust anyone")
        |> mes("who's not considered part")
        |> mes("of the upper class, even")
        |> mes("adventurers like you!")
        |> next()
        |> mes("[Calla]")
        |> mes("Would you please")
        |> mes("take this Violin and")
        |> mes("try to make it to Klitzer")
        |> mes("this time? Thank you")
        |> mes("for your help~")
        |> set_char_var(:EIN_LOVERQ, 3)
        |> changequest(8078, 8077)
        |> give_item(1901, 1)
        |> close()

      get_char_var(ctx, :EIN_LOVERQ, 0) == 3 or get_char_var(ctx, :EIN_LOVERQ, 0) == 5 ->
        ctx
        |> mes("[Calla]")
        |> mes("Oh, please send my")
        |> mes("regards to Klitzer for me.")
        |> mes("I wish I could comfort")
        |> mes("him in person, but this")
        |> mes("is the best I can do for now.")
        |> close()

      get_char_var(ctx, :EIN_LOVERQ, 0) == 2 ->
        ctx
        |> mes("[Calla]")
        |> mes("You're the adventurer")
        |> mes("from before, aren't you?")
        |> mes("Sadly, there isn't much")
        |> mes("to do around here. This")
        |> mes("place is basically like")
        |> mes("a prison to me...")
        |> next()
        |> mes("[Calla]")
        |> mes("Oh, you've met Klitzer?")
        |> mes("Isn't he so kind, and such")
        |> mes("a perfect gentleman?")
        |> next()
        |> mes("[Calla]")
        |> mes("I really wish I could")
        |> mes("see him, but it's almost")
        |> mes("impossible. My parents think")
        |> mes("he's not good enough for me,")
        |> mes("but they're wrong! What am")
        |> mes("I going to do? Oh, Klitzer...")
        |> next()
        |> mes("[Calla]")
        |> mes("Well, maybe I can't see")
        |> mes("him, but would you give")
        |> mes("my violin to Klitzer for me?")
        |> mes("I used to play this for him")
        |> mes("all the time...")
        |> next()
        |> set_char_var(:EIN_LOVERQ, 3)
        |> changequest(8076, 8077)
        |> give_item(1901, 1)
        |> mes("[Calla]")
        |> mes("I'm sorry to trouble you,")
        |> mes("but please understand")
        |> mes("that I want to comfort my")
        |> mes("Klitzer in any way that")
        |> mes("I possibly can. Thank")
        |> mes("you so much, adventurer...")
        |> close()

      true ->
        ctx =
          ctx
          |> mes("[Calla]")
          |> mes("Hello adventurer.")
          |> mes("Our city must just be")
          |> mes("another place where")
          |> mes("you'll stay no longer")
          |> mes("than a few days.")
          |> next()
          |> mes("[Calla]")
          |> mes("You must have so much")
          |> mes("freedom. I envy you. I can't")
          |> mes("do what I want to do. I don't")
          |> mes("even have the courage to tell")
          |> mes("my family what I really want,")
          |> mes("much less change things here...")
          |> next()

        ctx =
          if get_char_var(ctx, :EIN_LOVERQ, 0) == 0 do
            set_char_var(ctx, :EIN_LOVERQ, 1)
          else
            ctx
          end

        ctx
        |> mes("[Calla]")
        |> mes("How is it like?")
        |> mes("Going wherever you")
        |> mes("please, following your")
        |> mes("heart's true desire?")
        |> mes("What I would give to")
        |> mes("be able to do that...")
        |> close()
    end
  end
end
