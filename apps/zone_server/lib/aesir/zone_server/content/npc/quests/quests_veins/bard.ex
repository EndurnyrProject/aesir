defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.Bard do
  @moduledoc """
  Lasda advances the prison escape investigation and rewards its completion.

  ## Behavior

  - Responds to the investigation stage and sends the player to help Vitre.
  - Reveals the sting and grants the final reward.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Toms
    - Euphy
    - Joseph
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prt_church",
        x: 89,
        y: 108,
        dir: 6,
        sprite: 741,
        name: "Bard",
        scope: :shared,
        unique_name: "Bard#sch"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    cond do
      max_weight(ctx) - weight(ctx) < 2000 or checkweight(ctx, [{1201, 1}]) == 0 ->
        ctx
        |> mes("^3355FFWait a second!")
        |> mes("Right now, you're carrying")
        |> mes("too many things with you.")
        |> mes("Please come back after")
        |> mes("using the Kafra Service")
        |> mes("to store some of your items.^000000")
        |> close()

      get_char_var(ctx, :que_sch, 0) < 1 ->
        ctx
        |> mes("[Lasda]")
        |> mes("Hello there, isn't today")
        |> mes("such a wonderful day?")
        |> mes("Nice weather always")
        |> mes("inspires the poet in me,")
        |> mes("and I can't seem to stop")
        |> mes("singing my heart out~")
        |> close()

      get_char_var(ctx, :que_sch, 0) == 1 ->
        deliver_letter(ctx)

      get_char_var(ctx, :que_sch, 0) == 2 ->
        ctx
        |> mes("^3355FFLasda seems to be")
        |> mes("lost in deep thought.^000000")
        |> close()

      get_char_var(ctx, :que_sch, 0) == 3 ->
        request_help(ctx)

      get_char_var(ctx, :que_sch, 0) < 8 ->
        ctx
        |> mes("[Lasda]")
        |> mes("I still can't believe")
        |> mes("Vitre is being held")
        |> mes("in prison in Morocc. I mean,")
        |> mes("what could have happened?")
        |> mes("I hope you can help him...")
        |> close()

      get_char_var(ctx, :que_sch, 0) == 8 ->
        {ctx, _} =
          ctx
          |> mes("[Lasda]")
          |> mes("He was arrested because")
          |> mes("he's suspected of espionage?")
          |> mes("That doesn't make any sense.")
          |> mes("What could be going on?")
          |> next()
          |> select(["^ff0000Krieg^000000 told me that."])

        ctx
        |> mes("[Lasda]")
        |> mes("Krieg? Do you mean Krieg")
        |> mes("Laje Mandi? I know him quite")
        |> mes("well, actually. Let me write")
        |> mes("you a letter or recommendation.")
        |> mes("Hopefully, it'll be enough to")
        |> mes("let you enter the prison.")
        |> set_char_var(:que_sch, 9)
        |> close()

      get_char_var(ctx, :que_sch, 0) == 9 ->
        ctx
        |> mes("[Lasda]")
        |> mes("Hurry and go bring")
        |> mes("my letter to Krieg.")
        |> mes("I wonder what happened...")
        |> mes("There must be some kind")
        |> mes("of weird misunderstanding.")
        |> close()

      get_char_var(ctx, :que_sch, 0) < 19 ->
        ctx
        |> mes("[Lasda]")
        |> mes("He really asked you")
        |> mes("to break him out of jail?")
        |> mes("Well, I know that's a morally")
        |> mes("hazy area, but I hope that")
        |> mes("you do your best to help Vitre.")
        |> close()

      get_char_var(ctx, :que_sch, 0) < 25 ->
        ctx
        |> mes("[Lasda]")
        |> mes("Thanks for offering")
        |> mes("to help me out. I still")
        |> mes("can't believe Vitre had")
        |> mes("the gall to just break")
        |> mes("out of prison, though...")
        |> next()
        |> mes("[Lasda]")
        |> mes("I still can't do")
        |> mes("anything to help him,")
        |> mes("so please do what you")
        |> mes("can to take care of him")
        |> mes("for me. I really appreciate it.")
        |> close()

      get_char_var(ctx, :que_sch, 0) == 25 ->
        finish_investigation(ctx)

      true ->
        ctx
        |> mes("[Lasda]")
        |> mes("We're having too many")
        |> mes("cases involving spies")
        |> mes("like Vitre lately. This")
        |> mes("might be a sign that")
        |> mes("Arunafeltz is planning")
        |> mes("to move against us...")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp deliver_letter(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Lasda]")
      |> mes("Why, what a glorious")
      |> mes("day! I should sing a song")
      |> mes("in praise of its wonder!")
      |> mes("Ooooh... La la la-la~")
      |> mes("Girls, girls, giiiirls...")
      |> next()
      |> select(["Excuse me...", "......"])

    if choice == 1 do
      ctx
      |> mes("[Lasda]")
      |> mes("Why, what a glorious")
      |> mes("day! I should sing a song")
      |> mes("in praise of its wonder!")
      |> mes("Ooooh... La la la-la~")
      |> mes("Girls, girls, giiiirls...")
      |> close()
    else
      ask_about_lasda(ctx)
    end
  end

  defp ask_about_lasda(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Lasda]")
      |> mes("Girls, girls, giiiirls...")
      |> mes("Making my heart")
      |> mes("beat like... Like it's")
      |> mes("going too fast. My heart's")
      |> mes("racing... And you're at the")
      |> mes("finish line--Love Champion!")
      |> next()
      |> mes("[Lasda]")
      |> mes("Oh? Don't stare at me")
      |> mes("like that, you're making")
      |> mes("me blush. Did you need to")
      |> mes("talk to me or something?.")
      |> next()
      |> select(["I'm sorry.", "Are you ^ff0000Lasda Midar^000000?"])

    if choice == 1 do
      ctx
      |> mes("[Lasda]")
      |> mes("Oh, that's alright.")
      |> mes("...............................")
      |> mes("Girl, I'll laugh at all your")
      |> mes("jokes, and agree with yourv")
      |> mes("politics~ You're hot! But")
      |> mes("baby, you're dumb as bricks~")
      |> close()
    else
      accept_letter(ctx)
    end
  end

  defp accept_letter(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Lasda]")
      |> mes("Oh? Oh, yes, that's me.")
      |> mes("How can I help you?")
      |> next()
      |> select(["I'm here to deliver this to you."])

    ctx
    |> mes("[Lasda]")
    |> mes("Ah! He must have finally")
    |> mes("sent it. Would you please")
    |> mes("give me a second? Let's see...")
    |> next()
    |> mes("^3355FFLasda opened the letter")
    |> mes("and started reading it.^000000")
    |> next()
    |> mes("[Lasda]")
    |> mes("Umm...")
    |> mes("Oh, no...")
    |> next()
    |> mes("[Lasda]")
    |> mes("Ah, I'm sorry for")
    |> mes("making you wait.")
    |> mes("Here, please give")
    |> mes("this money to that")
    |> mes("kid that was supposed")
    |> mes("to come find me here.")
    |> set_char_var(:que_sch, 2)
    |> credit_zeny(100)
    |> next()
    |> mes("[Lasda]")
    |> mes("I'd like you to come")
    |> mes("talk to me again later")
    |> mes("if you have the time")
    |> mes("See you around~")
    |> close()
  end

  defp request_help(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Lasda]")
      |> mes("Oh good, you came back!")
      |> mes("Thanks for delivering that")
      |> mes("letter for me. Listen, you")
      |> mes("mind listening to me for")
      |> mes("a bit? I want to ask you")
      |> mes("for your help with something.")
      |> next()
      |> select(["Sure.", "No."])

    if choice == 1 do
      explain_request(ctx)
    else
      ctx
      |> mes("[Lasda]")
      |> mes("I suppose that you")
      |> mes("must already be busy")
      |> mes("doing something else.")
      |> mes("Well, I understand...")
      |> close()
    end
  end

  defp explain_request(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Lasda]")
      |> mes("You see, the letter you")
      |> mes("brought me was from my old")
      |> mes("best friend. I haven't heard")
      |> mes("from him for a while, so")
      |> mes("I was pretty worried...")
      |> next()
      |> mes("[Lasda]")
      |> mes("Vitre said in his letter")
      |> mes("that he's in jail under")
      |> mes("false charges so he wants")
      |> mes("me to help him out. However,")
      |> mes("there isn't much I can do.")
      |> mes("Do you think you can help him?")
      |> next()
      |> select(["Sure.", "No."])

    if choice == 1 do
      ctx
      |> mes("[Lasda]")
      |> mes("Thank you so much!")
      |> mes("I guess the best thing")
      |> mes("to do for now is to find")
      |> mes("my friend in a prison in")
      |> mes("^FF0000Morocc^000000, and see what")
      |> mes("you can do to help him..")
      |> set_char_var(:que_sch, 4)
      |> close()
    else
      ctx
      |> mes("[Lasda]")
      |> mes("I... I guess...")
      |> mes("You must not be")
      |> mes("able to help him too...")
      |> close()
    end
  end

  defp finish_investigation(ctx) do
    ctx =
      ctx
      |> mes("[Lasda]")
      |> mes("Ah, you're back. I'm sure")
      |> mes("you have a lot to ask me")
      |> mes("right now. You deserve to")
      |> mes("know that everything I asked")
      |> mes("you to do was part of a plan")
      |> mes("to confirm Vitre's guilt.")
      |> next()
      |> mes("[Lasda]")
      |> mes("We arrested him once")
      |> mes("we learned that he was")
      |> mes("an Arunafeltz spy, but we")
      |> mes("couldn't punish him since")
      |> mes("we lacked concrete proof.")
      |> next()
      |> mes("[Lasda]")
      |> mes("That's why we allowed")
      |> mes("him to escape: we planned")
      |> mes("on following him to get the")
      |> mes("proof that we needed. Our")
      |> mes("sting was even able to round")
      |> mes("up all of his compatriots!")
      |> next()
      |> mes("[Lasda]")
      |> mes("I'm sorry for keeping")
      |> mes("you in the dark, but it was")
      |> mes("essential to the plan. We")
      |> mes("couldn't have done it without")
      |> mes("your help. Please take this")
      |> mes("reward with our sincere thanks.")
      |> set_char_var(:que_sch, 26)
      |> give_item(12106, 1)

    ctx
    |> getexp(
      if(Rathena.truthy?(checkre(ctx, 3)), do: 60_000, else: 600_000),
      0
    )
    |> close()
  end
end
