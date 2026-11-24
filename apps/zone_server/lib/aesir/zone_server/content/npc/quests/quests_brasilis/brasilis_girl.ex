defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsBrasilis.BrasilisGirl do
  @moduledoc """
  Jasira seeks help meeting Jasi during the Water Lily quest.

  ## Behavior

  - Asks the adventurer to visit Jasi and advances the Water Lily quest.
  - Trades the flower for a hat with a random card.

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
        x: 270,
        y: 145,
        dir: 5,
        sprite: 473,
        name: "Brasilis Girl",
        scope: :shared,
        unique_name: "Brasilis Girl#bra",
        trigger: {5, 5}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_event("OnTouch", ctx), do: touch(ctx)

  @impl true
  def on_talk(ctx) do
    if Rathena.truthy?(checkweight(ctx, [{1201, 1}])) do
      talk(ctx, get_char_var(ctx, :brazil_regia, 0))
    else
      overweight(ctx)
    end
  end

  defp talk(ctx, 2), do: introduce(ctx)
  defp talk(ctx, progress) when progress in [3, 4], do: reminder(ctx)
  defp talk(ctx, 5), do: report_on_jasi(ctx)
  defp talk(ctx, progress) when progress in [6, 7], do: recover(ctx)
  defp talk(ctx, 8), do: make_hat(ctx)
  defp talk(ctx, progress) when progress > 8, do: after_hat(ctx)
  defp talk(ctx, _progress), do: greet(ctx)

  defp overweight(ctx) do
    ctx
    |> mes("- wait a second!! -")
    |> mes("- you have too many items -")
    |> mes("- so you can't get any more items. -")
    |> mes("- make your body lighter -")
    |> mes("- then try again. -")
    |> close()
  end

  defp introduce(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Distant Sound]")
      |> mes("Jasira!!!")
      |> mes("Where are you going again?!!")
      |> mes("come back~, please!!")
      |> next()
      |> mes("[Brasilis Girl]")
      |> mes("Mom, I have to go out!!")
      |> next()
      |> mes("[Distant Sound]")
      |> mes("No way~!! You shouldn't!!")
      |> next()
      |> mes("[Brasilis Girl]")
      |> mes("Gosh.. today also failed.")
      |> next()
      |> mes("[Brasilis Girl]")
      |> mes("......")
      |> mes("What's up? Why are you looking at me?")
      |> mes("I don't want to be a showgirl!! Get out!!")
      |> next()
      |> select(["Nothing, sorry.", "What's wrong?"])

    if choice == 1 do
      ctx |> mes("[Brasilis Girl]") |> mes("I am so sad!!!") |> close()
    else
      offer_help(ctx)
    end
  end

  defp offer_help(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Brasilis Girl]")
      |> mes("It's not your business.")
      |> mes("You are just an outsider!")
      |> next()
      |> select(["How rude!", "Just trying to help."])

    if choice == 1 do
      ctx |> mes("[Brasilis Girl]") |> mes("What's it matter to you that I'm rude??!!") |> close()
    else
      hear_story(ctx)
    end
  end

  defp hear_story(ctx) do
    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes(
        "I know that I'm just passing by but I might be able to help you. What do you think?"
      )
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("This kind of meeting could be more than just a coincidence.")
      |> next()
      |> mes("[Brasilis Girl]")
      |> mes("......................")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Hmm can you tell me your name?")
      |> next()
      |> mes("[Brasilis Girl]")
      |> mes("ja...")
      |> mes("Jasira.")
      |> mes("My name is Jasira.")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Nice name~.")
      |> mes("Jasira what's going on?")
      |> next()
      |> mes("[Jasira]")
      |> mes(".............")
      |> next()
      |> mes("[Jasira]")
      |> mes("I have to meet 'Jasi' but I can't go out....")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("who is Jasi?")
      |> mes("Your.... lover?")
      |> next()
      |> emotion(:huk)
      |> mes("[Jasira]")
      |> mes("l...o...v...e...lover??!!")
      |> mes("No way~")
      |> next()
      |> mes("[Jasira]")
      |> mes("If he is my lover, it would be great... but...")
      |> next()
      |> mes("[Jasira]")
      |> mes("Jasi is......")
      |> mes("the great moon.")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("The moon?")
      |> mes("Maybe... are you talking about the moon from the story?")
      |> next()
      |> mes("[Jasira]")
      |> mes("Yeah!")
      |> mes("Dear Jasi is from the moon from the sky!")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Why are you thinking like that?")
      |> next()
      |> mes("[Jasira]")
      |> mes(
        "Cuz' Jasi is really gorgeous and the most important thing is he is taking care of the water lily in Brasilis."
      )
      |> next()

    ctx = emotion(ctx, :huk, playerattached(ctx))

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Brasilis water lily??!!")
      |> mes("Isn't it the uniqe flower?")
      |> next()
      |> mes("[Jasira]")
      |> mes("Right. It's a really mysterious flower and difficult to find.")
      |> mes("But around Jasi there are lots of water lilies.")
      |> mes("That's why I believe Jasi is the moon.")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Where is Jasi?")
      |> next()
      |> mes("[Jasira]")
      |> mes("He is deep inside the Jungle.")
      |> mes(
        "As you can see I am so weak so, I've been staying home. But once, I was strong enough to leave this village."
      )
      |> next()
      |> mes("[Jasira]")
      |> mes("I just wandered the jungle and fell down somewhere and that's where I saw him.")
      |> mes("He was so nice. He helped heal me and guided me back home.")
      |> mes("That was really really great time.")
      |> next()
      |> mes("[Jasira]")
      |> mes("Since I came back home, my parents punished me.")
      |> mes("I can understand why they are worrying but i missed Jasi a lot!")
      |> next()

    {ctx, choice} =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Why don't you meet him after recovering your strength?")
      |> next()
      |> mes("[Jasira]")
      |> mes(".................")
      |> mes("I wanna see him right now...")
      |> next()
      |> select(["Help Jasira.", "Ignore her."])

    if choice == 2 do
      decline(ctx)
    else
      accept(ctx)
    end
  end

  defp decline(ctx) do
    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Sorry I can't help you. Cheer up!")
    |> next()
    |> mes("[Jasira]")
    |> mes("Crying........")
    |> close()
  end

  defp accept(ctx) do
    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Jasira I came here to find the Brasilis water lily.")
      |> mes("Don't you think fate has brought us together?")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("If you tell me how to find Jasi, I can help you.")
      |> next()
      |> mes("[Jasira]")
      |> mes(
        "Really? But I don't know exactly how to get there. I was just wandering around when I met him."
      )
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Can't you remember anything?")
      |> mes("If you know something you've gotta tell me.")
      |> next()
      |> mes("[Jasira]")
      |> mes(
        "Let's see... I was wandering around a waterfall then fell down into the water then I was sucked into somewhere."
      )
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Good, that's better than nothing! I will look for a similar place.")
    |> next()
    |> mes("[Jasira]")
    |> mes("I gave you your information, so can you do me a favor?")
    |> mes("It's really simple...")
    |> next()
    |> mes("[Jasira]")
    |> mes("I'd like to give a delicious fruit.")
    |> mes(
      "The place where Jas seemed cozy but I didn't see any food around... So if he sees a yummy fruit he will be happy!"
    )
    |> next()
    |> mes("[Jasira]")
    |> mes("Give him 10 Banana and tell him that I really miss him.")
    |> mes("Sorry for ignoring you before. Please, only you can help me!")
    |> set_char_var(:brazil_regia, 3)
    |> changequest(2201, 2202)
    |> close()
  end

  defp reminder(ctx) do
    ctx
    |> mes("[Jasira]")
    |> mes("If you meet Jasi, give him 10 Bananas.")
    |> mes(
      "Let's see... I was wandering around a waterfall then fell down into the water then I was sucked into somewhere."
    )
    |> next()
    |> mes("[Jasira]")
    |> mes(
      "If you can't find the way, go up to the waterfall and ask the kids in Brasilis village."
    )
    |> mes(
      "I heard one of the children went to a strange place before. He might've gone to the same place as me!"
    )
    |> close()
  end

  defp report_on_jasi(ctx) do
    ctx =
      ctx
      |> mes("[Jasira]")
      |> mes("Did you meet Jasi?")
      |> mes("Did you talk about me?")
      |> mes("You didn't? Uh? Stupid! Gosh~!")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Hey girl~ you've got a short temper.")
      |> mes("I did see him and I talked about you!")
      |> next()
      |> mes("[Jasira]")
      |> mes("Did you?")
      |> mes("What did he say?")
      |> mes("Does he remember me?")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("That you have a really good heart~")
      |> mes("I told him that you will try to meet him when your condition gets better.")
      |> next()
      |> mes("[Jasira]")
      |> mes("Yeahhhhh!!")
      |> mes("Thank you! You are more reliable than I thought you would be.")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Anyway, I'm looking for a fruit that's brown and has a hard shell.")
      |> mes("It has juice inside and can be used as a cup to drink out of.")
      |> next()
      |> mes("[Jasira]")
      |> mes("Duh! You mean a coconut right?!")
      |> mes("They're everywhere here in Brasilis.")
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Thanks Jasira!")
    |> set_char_var(:brazil_regia, 6)
    |> changequest(2204, 2205)
    |> close()
  end

  defp recover(ctx) do
    ctx
    |> mes("[Jasira]")
    |> mes("I should take care of my strength by myself!")
    |> mes("I can't just lie in my bed forever. Don't you agree?")
    |> close()
  end

  defp make_hat(ctx) do
    ctx =
      ctx
      |> mes("[Jasira]")
      |> mes("Uh? Why have you come back?")
      |> next()
      |> mes("- You tell her what Jasi told you to tell her -")
      |> next()
      |> mes("[Jasira]")
      |> mes("Oh... really?")
      |> mes("Did he say that?")
      |> mes("Gosh! Gosh!!!")
      |> mes("Kkkkkaaaaa - !!")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Thanks to you, I was able to get a flower.")
      |> mes("Thanks a lot!!")
      |> next()
      |> mes("[Jasira]")
      |> mes("Wooow. It's so beautiful.")
      |> next()
      |> mes("[Jasira]")
      |> mes("Ah... can I see it for a second?")
      |> next()
      |> mes("[Jasira]")
      |> mes("Surprise~!!")
      |> mes(
        "I've been working on this hat while you were gone and now it's complete with the water lily flower!"
      )
      |> next()
      |> mes("[Jasira]")
      |> mes("I know, I know! I'm the best...")
      |> delitem(7553, 1)
      |> set_char_var(:brazil_regia, 9)
      |> changequest(2206, 2207)
      |> set_local(:card, [4195, 4177, 4188])

    ctx
    |> getitem2(
      5302,
      1,
      1,
      0,
      0,
      Enum.at(get_local(ctx, :card, []), :rand.uniform(3) - 1, 0),
      0,
      0,
      0
    )
    |> close()
  end

  defp after_hat(ctx) do
    ctx
    |> mes("[Jasira]")
    |> mes("I just need to get a little bit stronger!")
    |> mes("I can't just lie in bed forever. My Jasi is waiting for me~")
    |> close()
  end

  defp greet(ctx) do
    ctx
    |> mes("[Distant Sound]")
    |> mes("Jasira!!!")
    |> mes("Where are you going again?!!")
    |> mes("Come back~, please!!")
    |> next()
    |> mes("[Brasilis Girl]")
    |> mes("Please mom~!")
    |> mes("Please let me go!")
    |> close()
  end

  defp touch(ctx) do
    if get_char_var(ctx, :brazil_regia, 0) == 2 do
      emotion(ctx, :fret)
    else
      ctx
    end
  end
end
