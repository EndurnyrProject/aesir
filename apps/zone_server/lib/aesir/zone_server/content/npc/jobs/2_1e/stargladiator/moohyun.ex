defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21e.Stargladiator.Moohyun do
  @moduledoc """
  Moohyun recruits Taekwon for the Star Gladiator job quest and helps with Beeryu's riddle.

  ## Behavior

  - Calls out to passing Taekwon who have not started the quest and greets Star Gladiators.
  - Recruits Taekwon of job level 40 or higher and refers them to Moogang.
  - Helps candidates stuck on Beeryu's riddle understand the resolve behind patience.
  - Points Novices to Taekwon training and chats with everyone else.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Celestria
    - Samuray22
    - L0ne_W0lf
    - Kisuka

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "payon",
        x: 215,
        y: 102,
        dir: 3,
        sprite: 828,
        name: "Moohyun",
        scope: :shared,
        unique_name: "Moohyun#job_star",
        trigger: {3, 3}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch", ctx) do
    cond do
      Rathena.job_id(class(ctx)) == Rathena.job_id(:taekwon) ->
        if get_char_var(ctx, :STGL_Q, 0) == 0 do
          ctx
          |> mes("[Moohyun]")
          |> mes("Hm...? Oh, you're just")
          |> mes("the kind of person I'm")
          |> mes("looking for. Come, I've")
          |> mes("got an offer for you if")
          |> mes("you're willing to listen...")
          |> close()
        else
          shoo_from_sun(ctx)
        end

      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:star_gladiator) ->
        ctx
        |> mes("[Moohyun]")
        |> mes("How's it going, warrior?")
        |> mes("Please continue to use")
        |> mes("your skills for the right")
        |> mes("causes. Bring pride to all")
        |> mes("Taekwon Masters everywhere!")
        |> close()

      true ->
        shoo_from_sun(ctx)
    end
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      Rathena.job_id(class(ctx)) == Rathena.job_id(:taekwon) ->
        guide_taekwon(ctx, get_char_var(ctx, :STGL_Q, 0))

      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:star_gladiator) ->
        greet_star_gladiator(ctx)

      Rathena.job_id(class(ctx)) == Rathena.job_id(:novice) ->
        point_novice_to_taekwon(ctx)

      true ->
        chat_with_passerby(ctx)
    end
  end

  defp shoo_from_sun(ctx) do
    ctx
    |> mes("[Moohyun]")
    |> mes("Whoa, whoa~")
    |> mes("Step aside, will you?")
    |> mes("You're blocking my sun!")
    |> close()
  end

  defp guide_taekwon(ctx, stage) do
    cond do
      stage == 0 -> pitch_taekwon_master(ctx)
      stage == 1 -> remind_to_visit_moogang(ctx)
      stage == 7 -> offer_riddle_help(ctx)
      stage == 8 -> ctx |> announce_readiness() |> close()
      true -> check_in(ctx)
    end
  end

  defp pitch_taekwon_master(ctx) do
    ctx = mes(ctx, "[Moohyun]")

    ctx =
      if sex(ctx) == get_char_var(ctx, :SEX_MALE, 0) do
        mes(ctx, "Hey, Taekwon Boy!")
      else
        mes(ctx, "Hey, Taekwon Girl!")
      end

    {ctx, choice} =
      ctx
      |> mes("Come here for a minute.")
      |> mes("I've got a proposition")
      |> mes("for you if you'll listen!")
      |> next()
      |> select(["Sure.", "No, thanks!"])

    if choice == 1 do
      introduce_taekwon_master(ctx)
    else
      ctx
      |> mes("[Moohyun]")
      |> mes("Aw, don't be like that.")
      |> mes("It doesn't cost you a zeny")
      |> mes("to listen to my spiel. Come")
      |> mes("on, just hear me out...")
      |> close()
    end
  end

  defp introduce_taekwon_master(ctx) do
    ctx =
      ctx
      |> mes("[Moohyun]")
      |> mes("Alright, kid.")
      |> mes("What's your name?")
      |> next()

    ctx = mes(ctx, "[#{char_name(ctx, 0)}]")

    ctx =
      ctx
      |> mes("#{char_name(ctx, 0)}.")
      |> next()
      |> mes("[Moohyun]")
      |> mes("Geez, you're so direct.")
      |> mes("A little warmth, a little")
      |> mes("friendliness wouldn't kill")
      |> mes("you, now would it? Anyway,")
      |> mes("have you given any thought")
      |> mes("as to what you want to be?")
      |> next()
      |> mes("[Moohyun]")
      |> mes("If your heart isn't already")
      |> mes("set on it, why don't you become")
      |> mes(
        "a ^4D4DFFwarrior of the Sun, the Moon,^FFFFFF ^4D4DFF and the Stars^000000? Just consider it."
      )
      |> next()

    {ctx, choice} =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Warrior of the wha--?")
      |> mes("I've never heard of that")
      |> mes("job. But I do know I can")
      |> mes("change jobs to a Soul")
      |> mes("Linker or Taekwon Master.")
      |> next()
      |> mes("[Moohyun]")
      |> mes("Yeah. Yeah, that's right.")
      |> mes("Taekwon Masters are warriors")
      |> mes("of the Sun, Moon, and Stars, and wield the power of the cosmos!")
      |> mes("Cool, huh? Anyway, interested")
      |> mes("in being a Taekwon Master?")
      |> next()
      |> select(["Yes, I am!", "No, not so much."])

    cond do
      choice != 1 ->
        ctx
        |> mes("[Moohyun]")
        |> mes("Really? Well, I still")
        |> mes("think you're better suited")
        |> mes("to being a Taekwon Master")
        |> mes("than a Soul Linker. But the")
        |> mes("decision is ultimately yours.")
        |> next()
        |> mes("[Moohyun]")
        |> mes("Well, if you change your")
        |> mes("mind, just come back to")
        |> mes("me and let me know. I know")
        |> mes("you'd make a great Taekwon")
        |> mes("Master if you really tried.")
        |> close()

      job_level(ctx) > 39 ->
        offer_job_change(ctx)

      true ->
        ctx
        |> mes("[Moohyun]")
        |> mes("Great, great~")
        |> mes("But first,you")
        |> mes("gotta be at least Job Level 40")
        |> mes("before you can begin Taekwon")
        |> mes("Master training. Otherwise, ")
        |> mes("it'll go over your head.")
        |> next()
        |> mes("[Moohyun]")
        |> mes("I know you can do it,")
        |> mes("and it shouldn't take")
        |> mes("too long. Promise me")
        |> mes("you'll come back so that")
        |> mes("I can help you become")
        |> mes("a great Taekwon Master~")
        |> close()
    end
  end

  defp offer_job_change(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Moohyun]")
      |> mes("Great, great~ I knew you'd")
      |> mes("see things my way. Alright,")
      |> mes("you seem to be ready enough.")
      |> mes("All you need now is someone")
      |> mes("who can train you to become")
      |> mes("a Taekwon Master.")
      |> next()
      |> mes("[Moohyun]")
      |> mes("Would you like to ^4D4dffchange")
      |> mes("your job to Taekwon Master^000000?")
      |> mes("If you do, I'll introduce you to somebody who can help")
      |> mes("you accomplish that goal.")
      |> next()
      |> select(["Yes, I do.", "Let me think about it..."])

    if choice == 1 do
      refer_to_moogang(ctx)
    else
      ctx
      |> mes("[Moohyun]")
      |> mes("That's fine. Changing your")
      |> mes("job is an important decision,")
      |> mes("so you should consider everything carefully. But let me assure you")
      |> mes("that you'll never regret becoming an awesome warrior of the cosmos!")
      |> close()
    end
  end

  defp refer_to_moogang(ctx) do
    ctx
    |> mes("[Moohyun]")
    |> mes("Excellent! Now, as you may")
    |> mes("have guessed, Taekwon Masters")
    |> mes("aren't organized into an official guild. So it's tough for all of us")
    |> mes("to gather, but we also have fewer rules and greater freedom.")
    |> next()
    |> mes("[Moohyun]")
    |> mes("Who's around now...? Umm...")
    |> mes("Ah, you should visit ^4D4DFFMoogang^000000.")
    |> mes("He's one of the few Taekwon")
    |> mes("Masters interested in receiving")
    |> mes("new students, so he'll be sure")
    |> mes("to guide you in your training.")
    |> next()
    |> mes("[Moohyun]")
    |> mes("Alright, you can find Moogang")
    |> mes("in Comodo, supposedly at the")
    |> mes("place that's closest to the sky. In the meantime, I'll write a")
    |> mes("letter of recommendation that")
    |> mes("I'll send to him for you.")
    |> set_char_var(:STGL_Q, 1)
    |> setquest(7007)
    |> close()
  end

  defp remind_to_visit_moogang(ctx) do
    ctx
    |> mes("[Moohyun]")
    |> mes("I've already sent him my")
    |> mes("letter of recommendation")
    |> mes("for you, so go ahead and")
    |> mes("visit Moogang in Comodo.")
    |> mes("He'll start training you to")
    |> mes("become a Taekwon Master.")
    |> close()
  end

  defp offer_riddle_help(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Moohyun]")
      |> mes("So how's the testing")
      |> mes("coming along? Oh hey, you")
      |> mes("look worried. Are you in")
      |> mes("some kind of trouble?")
      |> next()
      |> select(["No, I'm fine.", "About Beeryu's riddle..."])

    if choice == 1 do
      ctx
      |> mes("[Moohyun]")
      |> mes("It's alright to be independent")
      |> mes("and solve problems on your")
      |> mes("own, but you should elicit help")
      |> mes("when you really need it. There")
      |> mes("is no shame in being unable to")
      |> mes("accomplish something alone...")
      |> close()
    else
      explain_riddle(ctx)
    end
  end

  defp explain_riddle(ctx) do
    {ctx, answer} =
      ctx
      |> mes("[Moohyun]")
      |> mes("Ah, that. Beeryu has")
      |> mes("given you that riddle")
      |> mes("to solve. Well, first of")
      |> mes("all, you have to bring him")
      |> mes("something very important,")
      |> mes("but it isn't a material object.")
      |> next()
      |> mes("[Moohyun]")
      |> mes("You have to demonstrate")
      |> mes("something for him. Now tell")
      |> mes("me, when you face difficulty in")
      |> mes("life, obstacles to your goals,")
      |> mes("how do you respond? What")
      |> mes("does your heart feel, man?")
      |> next()
      |> mes("[Moohyun]")
      |> mes("I know that Beeryu asked you")
      |> mes("to prove your patience to him,")
      |> mes("but this is the most important")
      |> mes("factor behind patience. What")
      |> mes("do you say to yourself when")
      |> mes("your life seems hopeless?")
      |> next()
      |> select(["I will not give up!", "I... I don't know?"])

    if answer == 1 do
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("I will not give up!")
      |> mes("I'll make my dreams")
      |> mes("come true, no matter")
      |> mes("how long it may take!")
      |> next()
      |> mes("[Moohyun]")
      |> mes("Yes, that's it!")
      |> mes("When your resolution")
      |> mes("is backed by an iron will,")
      |> mes("you will have the patience")
      |> mes("to weather out all things.")
      |> mes("Show Beeryu your resolve...")
      |> next()
      |> announce_readiness()
      |> set_char_var(:STGL_Q, 8)
      |> close()
    else
      ctx
      |> mes("[Moohyun]")
      |> mes("You... You don't know?")
      |> mes("If you'd face obstacles")
      |> mes("head on and directly confront")
      |> mes("your fears, your enemies, and")
      |> mes("all of life's challenges, then the answer should come naturally.")
      |> next()
      |> mes("[Moohyun]")
      |> mes("Hmm...")
      |> mes("Why don't you contemplate")
      |> mes("the value of courage for")
      |> mes("a little while? Yes, that")
      |> mes("might be useful for now.")
      |> close()
    end
  end

  defp announce_readiness(ctx) do
    ctx
    |> mes("[Moohyun]")
    |> mes("Great, I think you're")
    |> mes("ready now. Please go")
    |> mes("talk to Moogang and head")
    |> mes("back to the Moon Room. Soon,")
    |> mes("maybe we'll be able to greet")
    |> mes("each other as Taekwon Masters!")
  end

  defp check_in(ctx) do
    ctx
    |> mes("[Moohyun]")
    |> mes("So, how have you")
    |> mes("been doing? I got")
    |> mes("faith that you'll become")
    |> mes("a great Taekwon Master, so")
    |> mes("I'm expecting great things.")
    |> close()
  end

  defp greet_star_gladiator(ctx) do
    ctx
    |> mes("[Moohyun]")
    |> mes("Hey, how have you")
    |> mes("been doing? Attuned")
    |> mes("with nature and all")
    |> mes("that, I see. Heh heh,")
    |> mes("isn't the cosmos such")
    |> mes("a wonderful thing?")
    |> close()
  end

  defp point_novice_to_taekwon(ctx) do
    ctx
    |> mes("[Moohyun]")
    |> mes("Hey, kid. Do you want")
    |> mes("to learn Taekwon Do?")
    |> mes("If you learn it, then you're")
    |> mes("guaranteed to become")
    |> mes("much stronger! ")
    |> next()
    |> mes("[Moohyun]")
    |> mes("Let's see...")
    |> mes("There's a man named")
    |> mes("Phoenix who can teach")
    |> mes("you Taekwon Do. He's")
    |> mes("around here somewhere...")
    |> next()
    |> mes("[Moohyun]")
    |> mes("Anyway, once you've")
    |> mes("learned Taekwon Do for")
    |> mes("a while, go ahead and come")
    |> mes("back to me if you really want to advance your studies, to master")
    |> mes("more than your mind and body.")
    |> close()
  end

  defp chat_with_passerby(ctx) do
    ctx = ctx |> mes("[Moohyun]") |> mes("Dude...") |> mes("Whaddya want?")

    ctx =
      if sex(ctx) == get_char_var(ctx, :SEX_MALE, 0) do
        ctx
        |> mes("You wanna join up")
        |> mes("with my martial arts")
        |> mes("school? It's too late")
        |> mes("for you, sorry pal~")
      else
        ctx
        |> mes("Oh, I didn't realize tha--")
        |> mes("Y-you're such a beautiful")
        |> mes("lady! I guess I oughta, you")
        |> mes("know, apologize for bein' rude.")
      end

    ctx
    |> next()
    |> mes("[Moohyun]")
    |> mes("Anyway, if you think I'm")
    |> mes("just some punk, I'll admit")
    |> mes("that I look and act the part.")
    |> mes("But actually, I'm a warrior of")
    |> mes("the Sun, Moon, and Stars.")
    |> next()
    |> mes("[Moohyun]")
    |> mes("It might be a little late")
    |> mes("for you, but if you know ")
    |> mes("anybody that wants to become")
    |> mes("a Taekwon Master, send them")
    |> mes("my way. I'll make sure that")
    |> mes("they meet the right people~")
    |> close()
  end
end
