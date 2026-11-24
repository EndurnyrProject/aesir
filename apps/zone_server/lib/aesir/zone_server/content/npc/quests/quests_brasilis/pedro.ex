defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsBrasilis.Pedro do
  @moduledoc """
  Pedro and his friends share the museum ghost story.

  ## Behavior

  - Starts the ghost investigation and repeats the magic words afterward.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - og2
    - Euphy
    - Capuche
    - Daegaladh

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "brasilis",
        x: 185,
        y: 246,
        dir: 5,
        sprite: 62,
        name: "Pedro",
        scope: :shared,
        unique_name: "Pedro#bra"
      }
    ]

  @impl true
  def on_event("OnTalk", ctx), do: tell_story(ctx)

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :brazil_ghost, 0) do
      0 ->
        tell_story(ctx)

      1 ->
        repeat_words(ctx)

      _ ->
        ctx
        |> mes("[Pedro]")
        |> mes("I wonder what I need to do to have a statue made of me?")
        |> close()
    end
  end

  defp repeat_words(ctx) do
    ctx
    |> mes("[Pedro]")
    |> mes("Do you wanna hear the magic words again?")
    |> next()
    |> mes("[Pedro]")
    |> mes("'^3131FFMother the door won't open!^000000'")
    |> mes("'^FF0000Turn the key as many times as there are colors in the rainbow.^000000'")
    |> mes("'^3131FFMother the water is flooding!^000000'")
    |> mes("'^FF0000If the moon disappears 3 times, don't worry.^000000'")
    |> mes("'^3131FFMother the drought has started!^000000'")
    |> mes("'^FF0000Don't worry, the waterfall will help it.^000000'")
    |> mes("'^3131FFMother where are my friends?^000000'")
    |> mes("'^FF0000Your 7 friends are sleeping. now it's time to wake them.^000000'")
    |> mes("'^3131FFWhere are you mom?^000000'")
    |> close()
  end

  defp tell_story(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Pedro]")
      |> mes("Wow it's really a great statue!")
      |> next()
      |> mes("[Mariana]")
      |> mes("It is, isn't it?")
      |> mes("This statue is called Verass Monument.")
      |> next()
      |> mes("[Mariana]")
      |> mes(
        "A long time ago there was a really brave adventurer named Verass, thanks to his dedicated exploration, Brasilis was able to develop into this great city."
      )
      |> next()
      |> mes("[Pedro]")
      |> mes("Awesome!!")
      |> mes("i wanna become a real man like Verass.")
      |> next()
      |> mes("[Mariana]")
      |> mes("Pedro, you can become whatever you want.")
      |> next()
      |> mes("[Pedro]")
      |> mes("Mariana is so smart, isn't she? hehe.")
      |> next()
      |> mes("[Fabio]")
      |> mes("Ooooh! You love her don't you!")
      |> next()
      |> mes("[Daniel]")
      |> mes("Wooooaaaa Pedro and Mari sitting in a tree!")
      |> next()
      |> mes("[Fabio]")
      |> mes("Woooo k-i-s-s-i-n-g~!!!")
      |> next()
      |> mes("[Daniel]")
      |> mes("Nya nya nya!")
      |> next()
      |> mes("[Fabio]")
      |> mes("Hahahahaha.")
      |> next()
      |> mes("[Pedro]")
      |> mes("Stop acting like babies!")
      |> next()
      |> mes("[Mariana]")
      |> mes("Boys~!")
      |> next()
      |> mes("[Daniel]")
      |> mes("Yah yah...")
      |> mes("Hey guys, did you hear that something happened a few days ago?")
      |> next()
      |> mes("[Mariana]")
      |> mes("Oh yeah~ I heard that something really scary happened.")
      |> next()
      |> mes("[Fabio]")
      |> mes(
        "Uh, yeah that's why Mariana got scared of going ot the bathroom for 3 days and everything was stinky. Ewwww~"
      )
      |> next()
      |> mes("[Daniel]")
      |> mes("Ha ha ha! Smelly Mari!")
      |> next()
      |> mes("[Mariana]")
      |> mes("I hate you~!")
      |> mes("Stop spreading rumors about me. I'm not scared of the bathroom.")
      |> mes("Pedro, do you think that I stink?")
      |> next()
      |> mes("[Pedro]")
      |> mes("Uh? Uh?")
      |> mes("N......no... no way.")
      |> mes("Hey guys~ be nice to her~")
      |> next()
      |> mes("[Fabio]")
      |> mes("kkkickkkkkkkkick")
      |> next()
      |> mes("[Daniel]")
      |> mes("kkkickkkkkkkk")
      |> next()
      |> select(["Walk by.", "Ask about the gossip."])

    if choice == 1 do
      ctx
      |> mes("[Fabio]")
      |> mes("Mariana~ smells~ Nya nya~")
      |> next()
      |> mes("[Daniel]")
      |> mes("Oh man you stink too~! Nya nya~")
      |> close()
    else
      hear_ghost_story(ctx)
    end
  end

  defp hear_ghost_story(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Fabio]")
      |> mes("Haven't you heard?")
      |> mes("The ghost story in the art museum.")
      |> next()
      |> mes("[Daniel]")
      |> mes("Ooohhhh! Scary~~~!")
      |> next()
      |> select(["Can you tell me more?"])

    ctx =
      ctx
      |> mes("[Fabio]")
      |> mes("A coupla days ago we went to the art museum for a picnic at school.")
      |> mes("You know nothing special, just a ordinary field trip.")
      |> next()
      |> mes("[Fabio]")
      |> mes("Museums are boring so me and some friends snuck away from the group~!")
      |> next()
      |> mes("[Fabio]")
      |> mes("That's when we heard a scream echoing through the whole museum.")
      |> next()
      |> mes("[Daniel]")
      |> mes("kkakkakkaaaah!!")
      |> mes("kkieeeeeeh!")
      |> mes("kehkeh..")
      |> next()
      |> mes("[Mariana]")
      |> mes("I heard the scream too...")
      |> mes("You boys are always making noises where you're not supposed to.")
      |> next()
      |> mes("[Pedro]")
      |> mes("What else are we supposed to do? If we don't do it someone else will.")
      |> next()

    {ctx, _} =
      ctx
      |> emotion(:fret, getnpcid(ctx, "Mariana#bra"))
      |> mes("[Mariana]")
      |> mes("Argh~ Boys are so frustrating sometimes.")
      |> next()
      |> select(["So then what happened?"])

    {ctx, _} =
      ctx
      |> mes("[Fabio]")
      |> mes(
        "Daniel and me guessed something weird was goin' on so we ran to where we thought the screams were comin' from."
      )
      |> next()
      |> mes("[Fabio]")
      |> mes("They were coming from the bathroom.")
      |> mes(
        "Some kids got so scared that they started screaming too and closing their eyes. It got pretty bad."
      )
      |> next()
      |> mes("[Daniel]")
      |> mes("I think you pissed or pooped your pants. It smelled freakin' gross.")
      |> next()
      |> mes("[Fabio]")
      |> mes("Nah uh~ Your mom pissed her pants~ Nyah!")
      |> next()
      |> mes("[Daniel]")
      |> mes("Nah uh~ You~ pissed your pants~")
      |> next()
      |> mes("[Fabio]")
      |> mes("Anyway, so yeah, anyway that's how the rumor of the ghost in the museum started.")
      |> next()
      |> mes("[Daniel]")
      |> mes("Liar, there's no such thing as ghosts~")
      |> next()
      |> select(["So was it a ghost?"])

    {ctx, _} =
      ctx
      |> mes("[Fabio]")
      |> mes("How should I know?")
      |> mes(
        "No one could say they saw one and no one wanted to get in trouble from the teachers."
      )
      |> next()
      |> mes("[Pedro]")
      |> mes("I heard if you say special magic words that the ghost will come out.")
      |> next()
      |> mes("[Daniel]")
      |> mes("Quit butting into our conversation Pedro.")
      |> next()
      |> mes("[Fabio]")
      |> mes("Yah, what are you talking about, Pedro?")
      |> mes("So did you see the ghost?")
      |> next()
      |> mes("[Pedro]")
      |> mes("N... no. I'm scared of ghosts.")
      |> mes("But my friends said they saw one and they're not liars.")
      |> next()
      |> select(["Did anyone tell you the magic words?"])

    {ctx, _} =
      ctx
      |> mes("[Pedro]")
      |> mes("I heard it in a kind of song.")
      |> mes("the special magic words are...")
      |> next()
      |> mes("[Pedro]")
      |> mes("'^3131FFMother the door won't open!^000000'")
      |> mes("'^FF0000Turn the key as many times as there are colors in the rainbow.^000000'")
      |> mes("'^3131FFMother the water is flooding!^000000'")
      |> mes("'^FF0000If the moon disappears 3 times, don't worry.^000000'")
      |> mes("'^3131FFMother the drought has started!^000000'")
      |> mes("'^FF0000Don't worry, the waterfall will help it.^000000'")
      |> mes("'^3131FFMother where are my friends?^000000'")
      |> mes("'^FF0000Your 7 friends are sleeping. now it's time to wake them.^000000'")
      |> mes("'^3131FFWhere are you mom?^000000'")
      |> next()
      |> mes("[Mariana]")
      |> mes("Umm it seems like a riddle.")
      |> next()
      |> select(["Wanna help me find this ghost?"])

    ctx
    |> mes("[Pedro]")
    |> mes("You're on your own pal~.")
    |> next()
    |> mes("[Mariana]")
    |> mes("I don't like scary things!")
    |> next()
    |> mes("[Fabio]")
    |> mes("Pfft, I can't believe you're gonna believe that story.")
    |> next()
    |> mes("[Daniel]")
    |> mes("I'll do whatever Fabio does, as always!")
    |> next()
    |> mes("[Fabio]")
    |> mes("Maybe you're just scared...")
    |> set_char_var(:brazil_ghost, 1)
    |> setquest(2208)
    |> close()
  end
end
