defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAyothaya.PowerfulLookingWoman do
  @moduledoc """
  Shuda asks adventurers to find her engagement ring and her fiancé Annon.

  ## Behavior

  - Starts the ring quest and follows its progress.
  - Takes the recovered ring and asks the player to find Annon.

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
        x: 233,
        y: 105,
        dir: 3,
        sprite: 838,
        name: "Powerful-Looking Woman",
        scope: :shared,
        trigger: {2, 2}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @engagement_ring 7288

  @impl true
  def on_event("OnTouch_", ctx), do: approach(ctx)

  @impl true
  def on_talk(ctx) do
    stage = get_char_var(ctx, :thai_find, 0)

    cond do
      stage == 14 -> completed(ctx)
      stage > 2 and stage < 14 -> seeking_annon(ctx)
      stage == 2 -> ring_status(ctx)
      stage == 1 -> seeking_ring(ctx)
      true -> introduction(ctx)
    end
  end

  defp completed(ctx) do
    ctx
    |> mes("[Shuda]")
    |> mes("Have you")
    |> mes("found Annon?")
    |> next()
    |> mes("[Shuda]")
    |> mes("You haven't")
    |> mes("found him yet?")
    |> mes("Then where the")
    |> mes("is he, then?!")
    |> next()
    |> mes("[Shuda]")
    |> mes("Oh well...")
    |> mes(
      "I'm not sure if I can believe everything you said, but since you found the ring for me, that's good enough. Thank you for your help."
    )
    |> next()
    |> mes("[Shuda]")
    |> mes(
      "If you happen to meet Annon during your travels, tell him to come back right away. You can go ahead and continue your adventures now~"
    )
    |> next()
    |> mes("[Shuda]")
    |> mes("If I ever")
    |> mes("see him again...")
    |> mes("He will be ^660000punished^000000...")
    |> mes("^666666*grinds teeth*^000000")
    |> close()
  end

  defp seeking_annon(ctx) do
    ctx
    |> mes("[Shuda]")
    |> mes("^666666*Sigh...*^000000")
    |> mes("You haven't")
    |> mes("found Annon yet?")
    |> mes("I see. Oh well, it's alright.")
    |> mes("Time isn't an issue for us.")
    |> next()
    |> mes("[Shuda]")
    |> mes(
      "And by 'us,' I mean '^660000you^000000.' I don't care about your plans or whatever else you may have scheduled, because you're going to make"
    )
    |> mes("time for me! Oho ho ho ho ho!")
    |> close()
  end

  defp ring_status(ctx) do
    if Rathena.truthy?(count_item(ctx, @engagement_ring)) do
      found_ring(ctx)
    else
      missing_ring(ctx)
    end
  end

  defp found_ring(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Shuda]")
      |> mes("Ah... Is it...?!!")
      |> mes("Yes, that's it!")
      |> mes("My engagement ring that was")
      |> mes("thrown into the water by that stupid Annon!")
      |> next()
      |> mes("[Shuda]")
      |> mes(
        "Thank you so much! In your honor, our first seven kids will be named after you! Oho ho ho ho ho ho ho~"
      )
      |> next()
      |> mes("[Shuda]")
      |> mes("Now...")
      |> mes("All I gotta do")
      |> mes("is find Annon.")
      |> mes("Where the hell")
      |> mes("did that moron go?!")
      |> next()
      |> mes("[Shuda]")
      |> mes("^666666*Ahem*^000000")
      |> mes("I-I didn't mean")
      |> mes("to scare him, all I wanted was")
      |> mes("my engagement ring back.")
      |> next()
      |> mes("[Shuda]")
      |> mes("^666666*Sigh*^000000")
      |> mes("I guess the days")
      |> mes("of being a happy bride")
      |> mes("are still far away from me...")
      |> next()
      |> mes("^3355FFShuda gazes directly")
      |> mes("at you with a puppy eyed look.^000000")
      |> next()
      |> select(["D-Don't look at me that way!", "Alright, alright."])

    case choice do
      1 -> ctx |> reluctant_help() |> accept_ring()
      2 -> ctx |> willing_help() |> accept_ring()
      _ -> ctx
    end
  end

  defp reluctant_help(ctx) do
    ctx =
      ctx
      |> mes("[Shuda]")
      |> mes(
        "Oh come on, you know everything that happened, and I know you're gonna continue adventuring"
      )
      |> mes("around this area.")
      |> next()
      |> mes("[Shuda]")
      |> mes(
        "I was just asking you to find Annon while you do that. Now, isn't that such a small favor? Thank you for doing this for me~"
      )
      |> next()
      |> mes("[Shuda]")
      |> mes(
        "In the meantime, I'll think of how I'm gonna pay back Annon for leaving me in misery! So hurry and find Annon! Hoo ho ho ho ho!"
      )
      |> emotion(:smile)
      |> next()

    ctx = emotion(ctx, :think, playerattached(ctx))

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("(She's so scary!")
      |> mes("Making me do stuff")
      |> mes("for her again...)")
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("(Why am I always")
    |> mes("doing things for other")
    |> mes("people anyway?!)")
  end

  defp willing_help(ctx) do
    ctx
    |> mes("[Shuda]")
    |> mes(
      "Yes, I knew I could count on you! So find Annon! It's my destiny to make him ^660000mine^000000. Hoo ho ho ho ho!"
    )
    |> next()
    |> mes("[Shuda]")
    |> mes(
      "I haven't seen him around the village for a while. And I don't think he jumped into the water to find my ring, since he's too sissy for that. He probably doesn't have the guts to see me without it."
    )
    |> next()
    |> mes("[Shuda]")
    |> mes("Will you please tell Annon that")
    |> mes(
      "I got my ring back so he can come back to me now? I hope you'll remember that for me, adventurer."
    )
  end

  defp accept_ring(ctx) do
    ctx
    |> delitem(@engagement_ring, 1)
    |> changequest(12030, 12031)
    |> set_char_var(:thai_find, 3)
    |> close()
  end

  defp missing_ring(ctx) do
    ctx
    |> mes("[Shuda]")
    |> mes("Huh...?")
    |> mes("Did you find my ring?")
    |> mes("Show me, show it to me!")
    |> next()
    |> mes("[Shuda]")
    |> mes("What the...")
    |> mes("You got nothing!")
    |> mes("Don't lie to me,")
    |> mes("bring me my ring!")
    |> next()
    |> mes("[Shuda]")
    |> mes("Hurry up and find")
    |> mes("my ring. I'll be waiting")
    |> mes("here for the good news.")
    |> mes("Oho ho ho ho ho~!")
    |> start_ring_quest()
    |> close()
  end

  defp seeking_ring(ctx) do
    ctx
    |> mes("[Shuda]")
    |> mes("I feel a little bad asking you this, especially since you're")
    |> mes("an outsider.")
    |> next()
    |> mes("[Shuda]")
    |> mes(
      "But that ring is really important to me. If you could find it for me, I'd be the happiest woman in the whole world."
    )
    |> next()
    |> mes("[Shuda]")
    |> mes("So please, I beg you.")
    |> mes("Please bring my ring back to me.")
    |> mes("I want to live with Annon as a happy couple forever. Can't you understand that?!")
    |> close()
  end

  defp introduction(ctx) do
    ctx =
      ctx
      |> mes("[Powerful-Looking Woman]")
      |> mes("Umm...?")
      |> mes(
        "Ah, you must be one of the tourists. I'd guide you around and listen to your stories about the outside world, but..."
      )
      |> next()

    if Rathena.truthy?(Enum.random(0..1)) do
      busy_conversation(ctx)
    else
      dismiss_tourist(ctx)
    end
  end

  defp busy_conversation(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Powerful-Looking Woman]")
      |> mes("I'm reeeally")
      |> mes("busy right now.")
      |> mes("So very busy.")
      |> next()
      |> mes("[Powerful-Looking Woman]")
      |> mes("Huh...?")
      |> mes(
        "You don't think I look busy just because I'm standing on one spot and not moving at all?! Oh. My. God. You're so rude!"
      )
      |> next()
      |> mes("[Powerful-Looking Woman]")
      |> mes("Now, I've got to find my")
      |> mes("engagement ring. If only")
      |> mes("my fiancee hadn't")
      |> mes("thrown it...")
      |> next()
      |> select(["What...?", "Lies~!"])

    case choice do
      1 -> offended(ctx)
      2 -> explain_ring(ctx)
      _ -> ctx
    end
  end

  defp offended(ctx) do
    ctx =
      ctx
      |> mes("[Powerful-Looking Woman]")
      |> mes("What 'what?'")
      |> mes("You still think I'm")
      |> mes("standing around for my")
      |> mes("own amusement or something?!")
      |> next()

    ctx = emotion(ctx, :kik, playerattached(ctx))

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("No no no no...")
    |> mes("I meant, I can't")
    |> mes("believe that you're")
    |> mes("engaged to someone!")
    |> next()
    |> mes("[Powerful-Looking Woman]")
    |> mes("Wwwwaaaaaahhhhh!")
    |> mes("Wh-who are you to say")
    |> mes(
      "something so rude to such a nice lady like myself. Go away, I don't wanna talk to you!"
    )
    |> close()
  end

  defp explain_ring(ctx) do
    ctx =
      ctx
      |> mes("[Powerful-Looking Woman]")
      |> mes("What lies?")
      |> mes("I'm not gonna put up with crap")
      |> mes("if you're gonna say something like 'I can't believe you're engaged to someone!'")
      |> next()

    {ctx, choice} =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Whoa whoa whoa~")
      |> mes("Calm down, lady.")
      |> mes("Hear me out first.")
      |> mes("What I'm wondering is...")
      |> next()
      |> mes("[Powerful-Looking Woman]")
      |> mes("I know, I know.")
      |> mes("You're wondering why I'm")
      |> mes(
        "standing near the water, right? Well, it's because my ring was thrown there and I've gotta"
      )
      |> mes("get it back.")
      |> next()
      |> mes("[Powerful-Looking Woman]")
      |> mes(
        "What am I doing, talking to a tourist like this? ^666666*Sigh...*^000000 Well, you learned what you wanted to know. I hope you're satisfied now."
      )
      |> next()
      |> mes("[Powerful-Looking Woman]")
      |> mes("...")
      |> next()
      |> mes("[Powerful-Looking Woman]")
      |> mes("...")
      |> mes("......")
      |> next()
      |> mes("[Powerful-Looking Woman]")
      |> mes("...")
      |> mes("......")
      |> mes("........Hey.")
      |> next()
      |> mes("[Powerful-Looking Woman]")
      |> mes("Why are you staring at me?")
      |> mes("Don't you have anything to do?")
      |> next()
      |> select(["No.", "No~ and you are an interesting girl."])

    case choice do
      1 -> ask_help(ctx)
      2 -> persuade(ctx)
      _ -> ctx
    end
  end

  defp ask_help(ctx) do
    ctx =
      ctx
      |> mes("[Powerful-Looking Woman]")
      |> mes("I see. Hmmm...")
      |> mes("You're kind of my type.")

    ctx =
      if sex(ctx) == 1 do
        ctx
        |> mes("No no, that doesn't mean I'm interested in you. Plus I'm")
        |> mes("already engaged.")
      else
        mes(
          ctx,
          "Before you think of anything weird, I meant that I think you and me are a lot alike."
        )
      end

    ctx =
      ctx
      |> next()
      |> mes("[Powerful-Looking Woman]")
      |> mes("Let me introduce myself.")
      |> mes(
        "My name is Shuda, I've lived in Ayothaya all my life. Since you don't have anything to do, I have"
      )
      |> mes("a favor to ask of you.")
      |> next()
      |> mes("[Shuda]")
      |> mes(
        "My fiance Annon is always interested in things other than me. I don't understand why, and I don't think I deserve to be ignored!"
      )
      |> next()
      |> mes("[Shuda]")
      |> mes("^666666*Sigh...*^000000")
      |> mes("Anyways, we're engaged")
      |> mes("and we got rings for each other...")
      |> next()
      |> mes("[Shuda]")
      |> mes(
        "I thought being engaged would improve our relationship. But he just took my ring and threw it into the water."
      )
      |> next()
      |> mes("[Shuda]")
      |> mes("I got upset and yelled at him to get my ring back for me, and then")
      |> mes("I never saw him after that.")
      |> mes("So what I want to ask is...")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("You want me")
      |> mes("to find your")
      |> mes("ring, don't you?")
      |> next()
      |> mes("[Shuda]")
      |> mes("Ah...")
      |> mes("So you know")
      |> mes("what I want.")
      |> mes("That makes it")
      |> mes("much simpler.")
      |> next()
      |> mes("[Shuda]")
      |> mes("And once I retrieve")
      |> mes("the ring, I'll make")
      |> mes("him treat me to a much")
      |> mes("deserved vacation in Jawaii...")
      |> next()
      |> mes("[Shuda]")
      |> mes("...Where I will")
      |> mes("^660000enslave^000000 him.")
      |> mes("^666666*Grinds teeth*^000000")
      |> next()

    ctx = emotion(ctx, :surprise, playerattached(ctx))

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("(...H-Horrifying!)")
    |> next()
    |> mes("[Shuda]")
    |> mes(
      "So anyway, I want you to go out and find my engagement ring. Since the water is calm and still around here, the ring is probably still under the water, and hasn't been swept away yet."
    )
    |> next()
    |> mes("[Shuda]")
    |> mes(
      "And so, that is my quest for you. It should keep you entertained for a while. So get into the water, and I'll supervise from here."
    )
    |> mes("Oho ho ho ho ho!")
    |> emotion(:smile)
    |> start_ring_quest()
    |> set_char_var(:thai_find, 1)
    |> close()
  end

  defp persuade(ctx) do
    ctx =
      ctx
      |> mes("[Powerful-Looking Woman]")
      |> mes("^666666*Sigh...*^000000")
      |> mes("Are you gonna just stare and")
      |> mes("not help at all? I thought the word adventurer was synonymous")
      |> mes("with 'hero,' not 'lazy.'")
      |> next()
      |> mes("[Powerful-Looking Woman]")
      |> mes("Oh I see...")
      |> mes("Don't help strangers, do you?")
      |> mes(
        "Well, my name is Shuda, a beautiful damsel waiting for her engagement ring to rise up from the water."
      )
      |> next()
      |> mes("[Powerful-Looking Woman]")
      |> mes("There...!")
      |> mes("We're not")
      |> mes("strangers anymore!")
      |> mes("Oho ho ho ho ho!")
      |> next()
      |> mes("[Shuda]")
      |> mes(
        "Don't you pity me, and my tragic situation? If someone were to help this precious maiden find her ring, she'd be the happiest bride in the whole world."
      )
      |> next()
      |> mes("[Shuda]")
      |> mes("And her savior")
      |> mes("would be known as")
      |> mes("the hero of Ayothaya.")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes(" ...Say what?!")
      |> next()
      |> mes("[Shuda]")
      |> mes(
        "Basically, you're gonna find my engagement ring, and I'll be the happiest bride in the whole world and I'll live happily ever after. What's so hard to understand"
      )
      |> mes("about that?")
      |> next()
      |> mes("[Shuda]")
      |> mes("Sure, Annon, he's my fiancee, is spineless and disappears whenever")
      |> mes(
        "I say something a little too harsh. What a little girl! Can't he see I'm trying to make him a better man?!"
      )
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("He ran away")
      |> mes("from you, didn't he?")
      |> next()
      |> mes("[Shuda]")
      |> mes("Eh...?")
      |> mes("What was that?")
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("^666666*Ahem*^000000")
    |> mes("You're way")
    |> mes("too good for him.")
    |> mes("(I'd have run away myself!)")
    |> next()
    |> mes("[Shuda]")
    |> mes("Yes, yes, I know.")
    |> mes("But what's important")
    |> mes(
      "is that once I get my ring back, Annon will be permanently mine. Till ^660000death do we part^000000."
    )
    |> next()
    |> mes("[Shuda]")
    |> mes("So, are you")
    |> mes("gonna help me or what?!")
    |> mes("If you do, me and Annon are gonna name our first seven children after you.")
    |> next()
    |> mes("[Shuda]")
    |> mes(
      "So go and look under the water! There's no water current, so I'm sure it's still there! What are you waiting for, it's should be an easy swim for you! Oho ho ho ho ho!"
    )
    |> start_ring_quest()
    |> set_char_var(:thai_find, 1)
    |> close()
  end

  defp start_ring_quest(ctx) do
    if checkquest(ctx, 12029) == -1, do: setquest(ctx, 12029), else: ctx
  end

  defp dismiss_tourist(ctx) do
    ctx
    |> mes("[Powerful-Looking Woman]")
    |> mes("^666666*Sigh...*^000000")
    |> mes(
      "Why isn't it coming up from the water? Maybe if I stirred around with a wooden stick...?"
    )
    |> next()
    |> mes("[Powerful-Looking Woman]")
    |> mes("...?!")
    |> mes("What are you")
    |> mes("looking at?!")
    |> mes("I'm busy, so if you")
    |> mes("want something")
    |> mes("I can't help you!")
    |> next()
    |> mes("[Powerful-Looking Woman]")
    |> mes("^666666Stupid tourists, running")
    |> mes("around all over Ayothaya,")
    |> mes("pestering and bothering")
    |> mes("beautiful girls like me...^000000")
    |> close()
  end

  defp approach(ctx) do
    if get_char_var(ctx, :thai_find, 0) == 0 do
      ctx
      |> mes("[Powerful-Looking Woman]")
      |> mes("^666666*Sigh...*^000000")
      |> mes("Where the")
      |> mes("hell is it!?")
      |> next()
      |> mes("[Powerful-Looking Woman]")
      |> mes("What are")
      |> mes("you looking at?")
      |> mes("Haven't you ever seen a delicate damsel sigh before? Leave me the hell alone!")
      |> close()
    else
      ctx
    end
  end
end
