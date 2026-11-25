defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.SecretarySlierre do
  @moduledoc """
  Secretary Slierre handles inquiries and investigates allegations against Wolfchev.

  ## Behavior

  - Answers questions about the corporation and laboratory.
  - Reviews evidence, investigates the claims, and rewards the player.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Samuray22
    - Gepard
    - Euphy
    - Joseph
    - Capuche
    - JohnnyPlayy
    - Persian
    - Vicious_Pucca
    - aoa00
    - Evera
    - MasterOfMuppets
    - Lupus
    - Lord Gywall
    - DeNy
    - Vicious
    - Playtester
    - Silent
    - SinSloth

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lhz_in01",
        x: 286,
        y: 226,
        dir: 3,
        sprite: 831,
        name: "Secretary Slierre",
        scope: :shared,
        unique_name: "Secretary Slierre#li"
      }
    ]

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :lhz_curse, 0) do
      26 -> slums_inquiry(ctx)
      27 -> laboratory_inquiry(ctx)
      28 -> research_inquiry(ctx)
      29 -> return_with_evidence(ctx)
      30 -> investigation(ctx)
      stage when stage > 30 -> completed(ctx)
      _ -> greeting(ctx)
    end
  end

  defp slums_inquiry(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Sueii Slierre]")
      |> mes("Excuse me, but you are")
      |> mes("not allowed to be in here.")
      |> mes("If you have questions regarding")
      |> mes("the Rekenber Corporation, I can")
      |> mes("direct you to someone qualified")
      |> mes("to give you an answer.")
      |> next()
      |> select(["About the Slums", "About Secretary Slierre"])

    case choice do
      1 ->
        ctx
        |> mes("[Sueii Slierre]")
        |> mes("The slums? All I know")
        |> mes("is that this corporation")
        |> mes("specifically targeted that")
        |> mes("area in order to provide ample")
        |> mes("opportunity for employment.")
        |> set_char_var(:lhz_curse, 27)
        |> close()

      2 ->
        ctx
        |> mes("[Sueii Slierre]")
        |> mes("I'm Sueii Slierre,")
        |> mes("the personal secretary")
        |> mes("for the chairman of the")
        |> mes("Rekenber Corporation.")
        |> close()

      _ ->
        ctx
    end
  end

  defp laboratory_inquiry(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Sueii Slierre]")
      |> mes("Did you have something")
      |> mes("else to ask? I can only")
      |> mes("divulge information that is")
      |> mes("public knowledge, but I can")
      |> mes("tell you who to contact for")
      |> mes("more specific inquiries.")
      |> next()
      |> select(["About the Laboratory", "About the Corporation"])

    case choice do
      1 ->
        ctx
        |> mes("[Sueii Slierre]")
        |> mes("Rekenber is perhaps the")
        |> mes("biggest contributer of the")
        |> mes("Regenschirm Laboratory.")
        |> mes("Their work will benefit the")
        |> mes("entire Midgard continent, hence our highly involved support.")
        |> next()
        |> mes("[Sueii Slierre]")
        |> mes("A representative at the")
        |> mes("Help Desk will be happy")
        |> mes("to assist you if you have")
        |> mes("more inquiries regarding")
        |> mes("the Regenschirm Laboratory.")
        |> set_char_var(:lhz_curse, 28)
        |> close()

      2 ->
        ctx
        |> mes("[Sueii Slierre]")
        |> mes("I'm sorry, but I don't have")
        |> mes("any special information")
        |> mes("regarding our corporation.")
        |> mes("Why don't you ask one of")
        |> mes("our representatives at the")
        |> mes("Help Desk to learn more?")
        |> close()

      _ ->
        ctx
    end
  end

  defp research_inquiry(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Sueii Slierre]")
      |> mes("You're back? I really")
      |> mes("doubt that I can be of")
      |> mes("any assistance to you.")
      |> next()
      |> select(["Wolfchev's Research"])

    case choice do
      1 -> relationship(ctx)
      _ -> ctx
    end
  end

  defp relationship(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Sueii Slierre]")
      |> mes(".............!")
      |> emotion(:surprise)
      |> next()
      |> mes("[Sueii Slierre]")
      |> mes("How do you know")
      |> mes("Wolfchev? Are you an")
      |> mes("acquaintance of his or...?")
      |> next()
      |> select([
        "I'm a friend of his.",
        "Oh, we're family, you know...",
        "I've heard about him before, so..."
      ])

    case choice do
      1 ->
        ctx
        |> mes("[Sueii Slierre]")
        |> mes("Well, Wolfchev is not")
        |> mes("only brilliant, he's also")
        |> mes("a respected professional.")
        |> mes("He should be doing just fine.")
        |> next()
        |> request_time()

      2 ->
        ctx
        |> mes("[Sueii Slierre]")
        |> mes("Ah, you should be")
        |> mes("very proud of Wolfchev.")
        |> mes("In addition to being a")
        |> mes("genius, Wolfchev is also")
        |> mes("quite the professional,")
        |> mes("truly a model scientist.")
        |> next()
        |> request_time()

      3 ->
        ctx
        |> mes("[Sueii Slierre]")
        |> mes("Ah yes, Wolfchev has")
        |> mes("quite the reputation. In")
        |> mes("fact, he's in such high")
        |> mes("demand that Regenschirm")
        |> mes("wants him on their staff.")
        |> close()

      _ ->
        ctx
    end
  end

  defp request_time(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Sueii Slierre]")
      |> mes("Now if you'll excuse me,")
      |> mes("I have many task to perform,")
      |> mes("so please visit our Help Desk")
      |> mes("if you have further inquiries.")
      |> next()
      |> select(["W-Wait!", "Alright, I understand."])

    case choice do
      1 ->
        ctx
        |> mes("[Sueii Slierre]")
        |> mes("...")
        |> mes("......")
        |> next()
        |> ask_about_research()

      2 ->
        ctx
        |> mes("[Sueii Slierre]")
        |> mes("Thank you for your")
        |> mes("cooperation. As you well")
        |> mes("know, the Help Desk is there")
        |> mes("to answer any of your questions regarding the Rekenber Corporation.")
        |> close()

      _ ->
        ctx
    end
  end

  defp ask_about_research(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Sueii Slierre]")
      |> mes("I'm sorry, but please")
      |> mes("understand that my office")
      |> mes("isn't the place for visitors to")
      |> mes("submit their general inquiries.")
      |> mes("Please visit the Help Desk if")
      |> mes("you have any more questions.")
      |> next()
      |> select(["About Wolfchev's Research"])

    {ctx, choice} =
      ctx
      |> emotion(:think)
      |> mes("[Sueii Slierre]")
      |> mes("I couldn't tell you any")
      |> mes("more about Wolfchev.")
      |> mes("But is there anything you")
      |> mes("need to tell me about him?")
      |> mes("Well, if you have something")
      |> mes("to ask, be quick about it.")
      |> next()
      |> select(["Wolfchev's Past", "Wolfchev's Test Subjects"])

    case choice do
      1 ->
        ctx
        |> mes("[Sueii Slierre]")
        |> mes("I remember hearing that he")
        |> mes("received a high recommendation")
        |> mes("to work here, but specifics elude me since I don't work in Human")
        |> mes("Resources. There's a rumor that")
        |> mes("he had a troubled love life...")
        |> next()
        |> mes("[Sueii Slierre]")
        |> mes("But aside from a few")
        |> mes("rumors, we really don't")
        |> mes("know much about Wolfchev's")
        |> mes("personal life. But then again,")
        |> mes("it may be unethical to pry too")
        |> mes("much into our employee's lives.")
        |> close()

      2 ->
        test_subjects(ctx)

      _ ->
        ctx
    end
  end

  defp test_subjects(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Sueii Slierre]")
      |> mes("Wolfchev's test subjects?")
      |> mes("Well, I know we have a policy")
      |> mes("of using the most humane")
      |> mes("methods depending on the")
      |> mes("experiment. And of course, he should only be testing on animals.")
      |> next()
      |> select(["Wolfchev's research is great!", "His experiments are suspicious..."])

    case choice do
      1 ->
        ctx
        |> mes("[Sueii Slierre]")
        |> mes("Yes, yes, I'd agree if")
        |> mes("I understood science a")
        |> mes("little bit better. Now, you'll")
        |> mes("have to excuse me. I've been distracted long enough as it is...")
        |> close2()
        |> warp("lhz_in01", 228, 226)

      2 ->
        request_evidence(ctx)

      _ ->
        ctx
    end
  end

  defp request_evidence(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Sueii Slierre]")
      |> mes("What exactly do you mean?")
      |> mes("Are you sure that you haven't")
      |> mes("misunderstood anything about")
      |> mes("Wolfchev's work? You'll need")
      |> mes("to illustrate your claim for us")
      |> mes("to be on the same page...")
      |> next()
      |> select(["Show Evidence", "Cancel"])

    case choice do
      1 ->
        if count_item(ctx, 7345) > 0 do
          show_evidence(ctx)
        else
          ctx
          |> mes("[Sueii Slierre]")
          |> mes("Evidence...?")
          |> mes("I'm sorry, but you don't")
          |> mes("seem to be carrying anything")
          |> mes("that can be construed as proof.")
          |> mes("I suggest you bring something that actually supports your claim.")
          |> set_char_var(:lhz_curse, 29)
          |> close()
        end

      2 ->
        ctx
        |> mes("[Sueii Slierre]")
        |> mes("If you're finished,")
        |> mes("I'd like to get back on")
        |> mes("task. Please excuse me.")
        |> close2()
        |> set_char_var(:lhz_curse, 30)

      _ ->
        ctx
    end
  end

  defp return_with_evidence(ctx) do
    ctx =
      ctx
      |> mes("[Sueii Slierre]")
      |> mes("Hmm, have you come back")
      |> mes("to address your claim about")
      |> mes("Wolfchev's work? If you don't")
      |> mes("have any evidence, then you")
      |> mes("shouldn't be making rumors...")
      |> next()

    if count_item(ctx, 7345) > 0 do
      show_evidence(ctx)
    else
      ctx
      |> mes("[Sueii Slierre]")
      |> mes("Hmm. I can't consider")
      |> mes("whatever you brought this")
      |> mes("time as evidence that would")
      |> mes("allay my doubts about your")
      |> mes("claim. Now, if you'll excuse")
      |> mes("me, I need to get back on task.")
      |> set_char_var(:lhz_curse, 29)
      |> close2()
      |> warp("lhz_in01", 228, 226)
    end
  end

  defp show_evidence(ctx) do
    {ctx, _} =
      ctx
      |> mes("^3355FFYou reveal the Handcuffs")
      |> mes("you found in the laboratory,")
      |> mes("and Secretary Slierre's face")
      |> mes("is instantly shadowed by a")
      |> mes("deeply troubled look.^000000")
      |> next()
      |> mes("[Sueii Slierre]")
      |> mes("...")
      |> mes("......")
      |> next()
      |> select(["What's Regenschirm up to?", "What's Wolfchev up to?"])

    {ctx, choice} =
      ctx
      |> mes("[Sueii Slierre]")
      |> mes("...")
      |> mes("......")
      |> emotion(:aha)
      |> next()
      |> mes("[Sueii Slierre]")
      |> mes("So... You're")
      |> mes("suspicious about")
      |> mes("Wolfchev's research in")
      |> mes("the Regenschirm Laboratory?")
      |> next()
      |> select(["Yes", "No"])

    case choice do
      1 -> start_investigation(ctx)
      2 -> clarify_suspicion(ctx)
      _ -> ctx
    end
  end

  defp clarify_suspicion(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Sueii Slierre]")
      |> mes("Wait, what exactly")
      |> mes("do you feel suspicious")
      |> mes("about? Basically, which")
      |> mes("party do you feel is most")
      |> mes("at fault in this situation?")
      |> next()
      |> select(["Regenschirm", "Mr. Wolfchev"])

    case choice do
      1 -> corporate_suspicion(ctx)
      2 -> start_investigation(ctx)
      _ -> ctx
    end
  end

  defp corporate_suspicion(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Sueii Slierre]")
      |> mes("Let me assure you that")
      |> mes("Regenschirm has a strict set")
      |> mes("of protocals and procedures")
      |> mes("to ensure safety and the")
      |> mes("prevention of unnecessary")
      |> mes("cruelty in experimentation.")
      |> next()
      |> select(["What about the creatures in Regenschirm?"])

    case choice do
      1 ->
        ctx
        |> mes("[Sueii Slierre]")
        |> mes("Creatures? I would")
        |> mes("guess that they're the")
        |> mes("result of experimentation.")
        |> mes("But I wouldn't know for sure.")
        |> next()
        |> start_investigation()

      _ ->
        ctx
    end
  end

  defp start_investigation(ctx) do
    ctx
    |> mes("[Sueii Slierre]")
    |> mes("I can't be sure right")
    |> mes("now, but this looks like")
    |> mes("fairly concrete evidence.")
    |> mes("We'll send some people over")
    |> mes("to Regenschirm right away!")
    |> next()
    |> mes("[Sueii Slierre]")
    |> mes("For now, your claim")
    |> mes("merits an investigation.")
    |> mes("I'll let you know if we")
    |> mes("find anything significant...")
    |> set_char_var(:lhz_curse, 30)
    |> close()
  end

  defp investigation(ctx) do
    ctx = set_local(ctx, :li_keka, Enum.random(1..10))

    cond do
      get_local(ctx, :li_keka, 0) <= 7 ->
        ctx
        |> mes("[Sueii Slierre]")
        |> mes("Oh, our investigation")
        |> mes("of your claim is still in")
        |> mes("progress. However, we")
        |> mes("will let you know when any")
        |> mes("new developments arise.")
        |> close()

      checkweight(ctx, [{1201, 1}]) == 0 ->
        ctx
        |> mes("[Sueii Slierre]")
        |> mes("Oh, I'd like to have")
        |> mes("a word with you. Would")
        |> mes("you please come back after")
        |> mes("reducing the weight of the")
        |> mes("items you are carrying please?")
        |> close()

      true ->
        reward(ctx)
    end
  end

  defp reward(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Sueii Slierre]")
      |> mes("Oh good, you're here.")
      |> mes("You were right all along.")
      |> mes("In our investigation, we found")
      |> mes("that Wolfchev was conducting")
      |> mes("unauthorized and very dangerous")
      |> mes("research. I owe you our thanks.")
      |> next()
      |> select(["What was he doing...?"])

    ctx
    |> mes("[Sueii Slierre]")
    |> mes("It turns out that Wolfchev")
    |> mes("was kidnapping weak and sick")
    |> mes("people from the slums and")
    |> mes("using them as his guinea pigs.")
    |> mes("Rest assured, he'll be punished")
    |> mes("for his behavior, if not fired.")
    |> next()
    |> mes("[Sueii Slierre]")
    |> mes("I think you deserve an")
    |> mes("apology. Without your")
    |> mes("report, our corporation's")
    |> mes("reputation could have been")
    |> mes("potentially damaged. Thank you.")
    |> next()
    |> mes("[Sueii Slierre]")
    |> mes("Yes, there's nothing so")
    |> mes("taboo as trying to perform")
    |> mes("Homunculus experiments")
    |> mes("on people! Anyway, please")
    |> mes("accept this as a token of")
    |> mes("our gratitude, adventurer.")
    |> set_char_var(:lhz_curse, 31)
    |> changequest(2094, 2095)
    |> give_item(603, 1)
    |> give_item(12_016, 10)
    |> next()
    |> mes("[Sueii Slierre]")
    |> mes("Let me promise you")
    |> mes("that Rekenber will ensure")
    |> mes("that this kind of incident")
    |> mes("will not be repeated and")
    |> mes("we'll do everything in our")
    |> mes("power to compensate for this...")
    |> close()
  end

  defp completed(ctx) do
    ctx
    |> mes("[Sueii Slierre]")
    |> mes("I'm glad to know that")
    |> mes("we have such proactive")
    |> mes("and concerned customers")
    |> mes("such as yourself to support")
    |> mes("the Rekenber Corporation.")
    |> close()
  end

  defp greeting(ctx) do
    ctx
    |> mes("[Sueii Slierre]")
    |> mes("Excuse me, but you are")
    |> mes("not allowed to be in here.")
    |> mes("Please visit the Help Desk")
    |> mes("if you have any questions about")
    |> mes("the Rekenber Corporation.")
    |> mes("Thank you for cooperating.")
    |> close()
  end
end
