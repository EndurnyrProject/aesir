defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.MysteriousWoman do
  @moduledoc """
  Agent Mitchell recruits the adventurer to investigate Kiel Hyre and Rekenber.

  ## Behavior

  - Questions the adventurer on touch and recruits them to the Schwarzwald investigation.
  - Provides the Juno assignment and offers federal airship travel.
  - Receives the investigation report and sends the adventurer back to confront Kiel Hyre.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf (Script)
    - DZeroX (Timer)
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "kh_mansion",
        x: 25,
        y: 79,
        dir: 4,
        sprite: 727,
        name: "Mysterious Woman",
        scope: :shared,
        unique_name: "Mysterious Woman#kh",
        trigger: {3, 3}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch", ctx) do
    case get_char_var(ctx, :KielHyreQuest, 0) do
      50 ->
        question_adventurer(ctx)

      52 ->
        assign_investigation(ctx)

      54 ->
        offer_airship(ctx)

      64 ->
        receive_report(ctx)

      quest_stage when quest_stage >= 68 ->
        ctx
        |> mes("[Mitchell]")
        |> mes("Shouldn't you be")
        |> mes("leaving about now?")
        |> next()
        |> warp("kh_mansion", 83, 50)

      _ ->
        ctx
    end
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  # rAthena starts a click at the first label, so it runs this body too.
  def on_talk(ctx), do: on_event("OnTouch", ctx)

  defp question_adventurer(ctx) do
    {ctx, answer} =
      ctx
      |> mes("^3355FFYou awaken with your")
      |> mes("head painfully throbbing,")
      |> mes("and a mysterious woman")
      |> mes("standing in front of you.^000000")
      |> next()
      |> mes("[??????]")
      |> mes("Hm? Oh, you're awake")
      |> mes("earlier than I thought.")
      |> mes("You must feel confused,")
      |> mes("but listen carefully. If you")
      |> mes("don't, then I can't guarantee")
      |> mes("your safety, okay? Alright.")
      |> next()
      |> mes("[??????]")
      |> mes("All you need to know it")
      |> mes("that I'm a secret agent for")
      |> mes("the Schwarzwald Republic")
      |> mes("government. We're investigating")
      |> mes("abnormal activity between Kiel")
      |> mes("Hyre and the Rekenber Corporation.")
      |> next()
      |> mes("[??????]")
      |> mes("We saw you enter the")
      |> mes("mansion and speak to")
      |> mes("Kiel Hyre, so basically")
      |> mes("you're here for questioning.")
      |> mes("Now tell me the truth. How")
      |> mes("do you know Kiel Hyre?")
      |> next()
      |> select(["I'll tell you everything!", "I don't know nuthin'!"])

    case answer do
      1 -> request_cooperation(ctx)
      2 -> ctx |> explain_suspicions() |> request_cooperation()
      _ -> ctx
    end
  end

  defp explain_suspicions(ctx) do
    ctx =
      ctx
      |> mes("[??????]")
      |> mes("Don't...know...nuthin'?")
      |> mes("You sure about that? Only")
      |> mes("a select few can even speak")
      |> mes("with Kiel Hyre in person. You")
      |> mes("must have some connection")
      |> mes("to him. I'm right, aren't it?")
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("......")
    |> mes(".........")
    |> mes("............")
    |> next()
    |> mes("[??????]")
    |> mes("Are you trying to protect")
    |> mes("him? I think that you might")
    |> mes("not understand what kind of")
    |> mes("person you're really dealing")
    |> mes("with here. I'll tell you what")
    |> mes("I've learned about him...")
    |> next()
    |> mes("[??????]")
    |> mes("Kiel Hyre. CEO of the")
    |> mes("Kiel Hyre Foundation,")
    |> mes("manufacturer of various")
    |> mes("machinery. His company started")
    |> mes("as a small Einbroch store whose")
    |> mes("technology slowly grew famous.")
    |> next()
    |> mes("[??????]")
    |> mes("Rekenber Corperation offered")
    |> mes("a merger with the Kiel Hyre")
    |> mes("Foundation. We're still not")
    |> mes("sure why they wanted Kiel")
    |> mes("Hyre in particular to repair")
    |> mes("and develop their Guardians...")
    |> next()
    |> mes("[??????]")
    |> mes("We're also not sure why")
    |> mes("they wanted to suddenly")
    |> mes("focus more on Guardian")
    |> mes("development. Then, all")
    |> mes("of a sudden, Kiel Hyre's son")
    |> mes("appears from out of nowehre.")
    |> next()
    |> mes("[??????]")
    |> mes("It's very suspicious.")
    |> mes("There's no records of his")
    |> mes("birth or anything. Still, maybe")
    |> mes("Kiel Hyre really did have him")
    |> mes("with his secretary, Allysia.")
    |> mes("Well, no one is really sure.")
    |> next()
    |> mes("[??????]")
    |> mes("In any case, Kiel Hyre's")
    |> mes("son and heir, Kiehl, helped")
    |> mes("his father establish this")
    |> mes("special academy as their")
    |> mes("way of giving back to society.")
    |> next()
    |> mes("[??????]")
    |> mes("Almost every corporation and")
    |> mes("organization tried to get their")
    |> mes("spies to enter this academy,")
    |> mes("but all of them were rejected.")
    |> mes("it's strange. At least one of")
    |> mes("them should have made it in.")
    |> next()
    |> mes("[??????]")
    |> mes("And recently, Kiehl Hyre")
    |> mes("has held a secret meeting with")
    |> mes("Rekenber executives to announce")
    |> mes("his new project. He intends to")
    |> mes("create advanced humanoid robots")
    |> mes("that will replace guardians!")
    |> next()
    |> mes("[??????]")
    |> mes("Our spies reported that")
    |> mes("Kiel Hyre was nowhere to")
    |> mes("be seen at that meeting,")
    |> mes("as well as his trusted")
    |> mes("secretary, Allysia. He...")
    |> mes("He just disappeared!")
    |> next()
    |> mes("[??????]")
    |> mes("Then, Kiel Hyre pops back")
    |> mes("in his mansion after all")
    |> mes("this time as if nothing")
    |> mes("happened! At the same time,")
    |> mes("Kiehl disappears, under the")
    |> mes("excuse of conducting research.")
    |> next()
    |> mes("[??????]")
    |> mes("Rekenber is sponsoring")
    |> mes("both Kiehl and Kiel, but")
    |> mes("there's some kind of conflict")
    |> mes("going on between father and")
    |> mes("son, I just know it! Now tell")
    |> mes("me, what's going on?")
    |> next()
    |> mes("[??????]")
    |> mes("I'm not sure how well you")
    |> mes("know this country, but the")
    |> mes("fact that Rekenber is invoved")
    |> mes("must tell you that these aren't")
    |> mes("good people. Tell me what")
    |> mes("you know about them!")
    |> next()
  end

  defp request_cooperation(ctx) do
    {ctx, answer} =
      ctx
      |> mes("^3355FFYou tell the woman^000000")
      |> mes("^3355FFeverything you know^000000")
      |> mes("^3355FFabout Kiel Hyre. Your^000000")
      |> mes("^3355FFvoice quivers with sadness^000000")
      |> mes("^3355FFwhenever you mention Elly.^000000")
      |> next()
      |> mes("[??????]")
      |> mes("I see, I see...")
      |> mes("That poor girl... So...")
      |> mes("Your involvement in this")
      |> mes("is a coincidence? In that")
      |> mes("case, I want your help")
      |> mes("in our investigation.")
      |> next()
      |> select(["Okay", "......"])

    case answer do
      1 -> recruit_adventurer(ctx)
      2 -> insist_on_cooperation(ctx)
      _ -> ctx
    end
  end

  defp insist_on_cooperation(ctx) do
    ctx =
      ctx
      |> mes("[??????]")
      |> mes("If you don't cooperate,")
      |> mes("then I can't guarantee")
      |> mes("your safety, adventurer")
      |> next()

    {ctx, _} =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Huh? What...?")
      |> mes("What does that mean?")
      |> mes("Are you threatening me?")
      |> next()
      |> select(["Just do what she says."])

    recruit_adventurer(ctx)
  end

  defp recruit_adventurer(ctx) do
    ctx
    |> mes("[??????]")
    |> mes("Great.")
    |> mes("I'm Agent Mitchell Layla.")
    |> mes("From here on, you're working")
    |> mes("for the Schwarzwald Republic!")
    |> set_char_var(:KielHyreQuest, 52)
    |> close()
  end

  defp assign_investigation(ctx) do
    ctx
    |> mes("[Mitchell]")
    |> mes("I've got some new")
    |> mes("information for you.")
    |> mes("There's an old lady in")
    |> mes("Juno that knew a woman")
    |> mes("named Allysia 30 years ago.")
    |> next()
    |> mes("[Mitchell]")
    |> mes("The clincher is that this")
    |> mes("Allysia from 30 years ago")
    |> mes("commited suicide, and is")
    |> mes("identical to Kiel Hyre's")
    |> mes("secretary, who is also")
    |> mes("named Allysia.")
    |> next()
    |> mes("[Mitchell]")
    |> mes("This is too much of a")
    |> mes("coincidence. I want you to")
    |> mes("go to Juno and investigate.")
    |> mes("When you're done, talk to")
    |> mes("Kiel Hyre's steward, and")
    |> mes("he'll send you over to me.")
    |> next()
    |> mes("[Mitchell]")
    |> mes("Yeah, I know.")
    |> mes("That guy actually")
    |> mes("works for me. Anyway,")
    |> mes("when you're ready to go")
    |> mes("to Juno, let me know, and you")
    |> mes("can board the federal airship.")
    |> set_char_var(:KielHyreQuest, 54)
    |> close()
  end

  defp offer_airship(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Mitchell]")
      |> mes("Are you ready?")
      |> mes("I'll let you board")
      |> mes("the federal Airship so")
      |> mes("you can get to Juno, and")
      |> mes("finish your mission quickly.")
      |> next()
      |> select(["Yes", "No"])

    case choice do
      1 ->
        ctx
        |> mes("[Mitchell]")
        |> mes("Good luck. Once you")
        |> mes("complete your mission,")
        |> mes("make sure that you report")
        |> mes("to Kiel Hyre's steward so")
        |> mes("that he can send you to me.")
        |> close()
        |> warp("yuno", 54, 209)

      2 ->
        ctx
        |> mes("[Mitchell]")
        |> mes("Take your time...")
        |> mes("But keep in mind that")
        |> mes("I'm not a patient woman!")
        |> close()

      _ ->
        ctx
    end
  end

  defp receive_report(ctx) do
    ctx
    |> mes("[Mitchell]")
    |> mes("Ah, you're back.")
    |> mes("What do you have")
    |> mes("to report from your")
    |> mes("investigation?")
    |> next()
    |> mes("[Mitchell]")
    |> mes(".....................")
    |> mes("Ah, I see. Good work.")
    |> mes("Why don't you go speak to Kiel")
    |> mes("Hyre and confront him with")
    |> mes("what you've learned about")
    |> mes("his past? Yeah, grill him.")
    |> next()
    |> mes("[Mitchell]")
    |> mes("Wear this hidden mic,")
    |> mes("so we can send help if")
    |> mes("you're endangered. I want")
    |> mes("you to find out who Kiel")
    |> mes("really is, and what's his")
    |> mes("relationship to Rekenber.")
    |> set_char_var(:KielHyreQuest, 68)
    |> next()
    |> warp("kh_mansion", 83, 50)
  end
end
