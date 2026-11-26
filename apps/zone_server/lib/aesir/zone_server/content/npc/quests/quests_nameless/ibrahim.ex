defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.Ibrahim do
  @moduledoc """
  Ibrahim seeks help recovering a cursed diamond and discusses the Unlucky Emerald.

  ## Behavior

  - Recruits adventurers to recover the diamond and rewards its return.
  - Advises the emerald's owner about selling or studying the jewel.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Koca
    - Yommy
    - brianluau
    - Euphy
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  - `BaseClass == Job_Magician` uses the Mage first class instead.
  - `BaseClass == Job_Crusader / Job_Blacksmith / Job_Alchemist / Job_Bard / Job_Dancer`
    checks the second class before its first-class sibling.
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "moc_ruins",
        x: 152,
        y: 147,
        dir: 5,
        sprite: 732,
        name: "Ibrahim",
        scope: :shared,
        trigger: {3, 3}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_event("OnTouch", ctx) do
    ev_ontouch(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    cond do
      checkweight(ctx, [{907, 200}]) == 0 ->
        ctx
        |> mes("[Ibrahim]")
        |> mes("You're carrying too much")
        |> mes("stuff with you. Dump it")
        |> mes("in Kafra Storge, sell it,")
        |> mes("drop it, whatever, before")
        |> mes("you come talk to me, okay?")
        |> close()

      get_char_var(ctx, :diamond_edq, 0) < 14 ->
        ctx
        |> mes("[Ibrahim]")
        |> mes("Have you heard of the")
        |> mes("Four Cursed Jewels?")
        |> mes("I hear that one of them,")
        |> mes("the Diamond of Destruction,")
        |> mes("just appeared recently.")
        |> mes("What I'd do to find it...")
        |> close()

      get_char_var(ctx, :diamond_edq, 0) == 14 and base_level(ctx) > 65 ->
        ctx = mes(ctx, "[Ibrahim]")

        ctx
        |> mes(Rathena.concat(Rathena.concat("", char_name(ctx, 0)), ", right?"))
        |> mes("Don't be too suprised.")
        |> mes("I've heard of you here")
        |> mes("and there. Heh heh~!")
        |> next()
        |> discuss_diamond()

      get_char_var(ctx, :diamond_edq, 0) == 15 ->
        ctx
        |> mes("[Ibrahim]")
        |> mes("Find ^0000FFJhonnita^000000 in Alberta,")
        |> mes("^0000FFKimeunbang^000000 in Payon, and")
        |> mes("^0000FFLeblo^000000 in Geffen. They wanted ")
        |> mes("that diamond badly too, so")
        |> mes("they'll remember if they")
        |> mes("heard any clues about it.")
        |> next()
        |> mes("[Ibrahim]")
        |> mes("Please don't let them")
        |> mes("know I've hired you to")
        |> mes("investigate that diamond.")
        |> mes("They won't speak to you")
        |> mes("if they figure out that")
        |> mes("I've sent you to them.")
        |> close()

      get_char_var(ctx, :diamond_edq, 0) > 15 and get_char_var(ctx, :diamond_edq, 0) < 25 ->
        ctx
        |> mes("[Ibrahim]")
        |> mes("Are you still investigating")
        |> mes("the diamond's whereabouts?")
        |> mes("Well, I hope you can bring")
        |> mes("me back good news soon.")
        |> close()

      get_char_var(ctx, :diamond_edq, 0) == 25 ->
        receive_diamond(ctx)

      get_char_var(ctx, :diamond_edq, 0) == 26 ->
        discuss_emerald(ctx)

      true ->
        ctx
        |> mes("[Ibrahim]")
        |> mes("Have you heard of")
        |> mes("the Four Cursed Jewels?")
        |> mes("I wish to retrieve my")
        |> mes("Diamond of Destruction,")
        |> mes("but whoever has it has")
        |> mes("kept it well hidden...")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def ev_ontouch(ctx) do
    if get_char_var(ctx, :diamond_edq, 0) == 14 and base_level(ctx) > 65 do
      ctx = ctx |> mes("[Ibrahim]") |> mes("Psst, adventurer!")

      ctx
      |> mes(Rathena.concat(Rathena.concat("You're ", char_name(ctx, 0)), ", right?"))
      |> mes("There's something")
      |> mes("I'd like to discuss")
      |> mes("with you in private!")
      |> close()
    else
      ctx
    end
  end

  defp receive_diamond(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Ibrahim]")
      |> mes("Oh, you're back.")
      |> mes("Made any headway in")
      |> mes("your investigation of the")
      |> mes("Diamond of Destruction?")
      |> next()
      |> select(["Explain What You Learned"])

    {ctx, _} =
      ctx
      |> mes("[Ibrahim]")
      |> mes("What?! The Z Gang stole")
      |> mes("my diamond? No wonder!")
      |> mes("I bet they wanted to use its")
      |> mes("curse for something evil.")
      |> mes("How about the jewel?")
      |> mes("Did you retrieve it?")
      |> next()
      |> select(["Give Diamond of Destruction"])

    ctx
    |> mes("[Ibrahim]")
    |> mes("Oh! Great! So it was")
    |> mes("in the Z Gang's hideout?")
    |> mes("Wow, even after hearing so")
    |> mes("much about you, you still")
    |> mes("exceeded my expectations!")
    |> next()
    |> delitem(7723, 1)
    |> mes("[Ibrahim]")
    |> mes("Thank God, I finally")
    |> mes("have this back! Ah, and")
    |> mes("as for your payment...")
    |> mes("Well, I don't know if")
    |> mes("it's enough for what you")
    |> mes("did, but I hope you like it.")
    |> completequest(3118)
    |> set_char_var(:diamond_edq, 26)
    |> give_item(732, 2)
    |> give_item(603, 1)
    |> next()
    |> mes("[Ibrahim]")
    |> mes("Now that I have the")
    |> mes("Diamond of Destruction")
    |> mes("again, I can research")
    |> mes("more about its strange")
    |> mes("properties. I'll contact you")
    |> mes("again if I need your help.")
    |> close()
  end

  defp discuss_emerald(ctx) do
    cond do
      get_char_var(ctx, :jewel_nd, 0) == 0 ->
        emerald_introduction(ctx)

      get_char_var(ctx, :jewel_nd, 0) == 1 ->
        ctx
        |> mes("[Ibrahim]")
        |> mes("I don't have the funds")
        |> mes("to buy your emerald at")
        |> mes("a fair price, but why don't")
        |> mes("you ask the other jewelers?")
        |> mes("They might be interested")
        |> mes("in buying your jewel.")
        |> close()

      get_char_var(ctx, :jewel_nd, 0) == 2 ->
        emerald_sale_report(ctx)

      get_char_var(ctx, :jewel_nd, 0) == 9 or get_char_var(ctx, :jewel_nd, 0) == 10 ->
        ctx
        |> mes("[Ibrahim]")
        |> mes("Why don't you visit my")
        |> mes("scholar friend in Comodo,")
        |> mes("and ask him to examine your")
        |> mes("Unlucky Emerald? The more")
        |> mes("you learn about that so-called")
        |> mes("curse, the better. Good luck!")
        |> close()

      true ->
        ctx
        |> mes("[Ibrahim]")
        |> mes("Oh, so what have you")
        |> mes("learned about the Unlucky")
        |> mes("Emerald so far? Hmmm. Yes,")
        |> mes("very intriguing. Good luck")
        |> mes("with your research efforts~")
        |> close()
    end
  end

  defp emerald_introduction(ctx) do
    cond do
      get_char_var(ctx, :treasure_nd, 0) > 10 and base_level(ctx) > 65 ->
        offer_emerald(ctx)

      get_char_var(ctx, :treasure_nd, 0) > 10 and base_level(ctx) < 66 ->
        ctx
        |> mes("[Ibrahim]")
        |> mes("I heard that you obtained")
        |> mes("the Unlucky Emerald from")
        |> mes("a friend in Morocc. Let me")
        |> mes("warn you that you might not")
        |> mes("be strong enough to handle")
        |> mes("its power. Be careful.")
        |> next()
        |> mes("[Ibrahim]")
        |> mes("If you're not wary,")
        |> mes("its curse might destroy")
        |> mes("you. Understand?")
        |> close()

      true ->
        ctx
        |> mes("[Ibrahim]")
        |> mes("Thank you for all")
        |> mes("you've done for me. I'll")
        |> mes("continue my research in the")
        |> mes("cursed jewel's powers, and")
        |> mes("I'll contact you if I need your")
        |> mes("help again. Take care~")
        |> close()
    end
  end

  defp emerald_sale_report(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Ibrahim]")
      |> mes("Ah, you're back~")
      |> mes("So were you able to")
      |> mes("sell the Unlucky Emerald?")
      |> next()
      |> select(["Everyone seems scared!"])

    ctx
    |> mes("[Ibrahim]")
    |> mes("Ah, I see now. They")
    |> mes("must be too afraid of")
    |> mes("that particular jewel's")
    |> mes("curse. Huh. Weird.")
    |> next()
    |> mes("[Ibrahim]")
    |> mes("I guess the Diamond of")
    |> mes("Destruction is considered")
    |> mes("pretty safe since it's been")
    |> mes("around for a while without")
    |> mes("any strange incidents.")
    |> next()
    |> mes("[Ibrahim]")
    |> mes("You just dug up the")
    |> mes("emerald? I suppose it")
    |> mes("might be too soon to sell it.")
    |> mes("Not too many people will")
    |> mes("test their luck with that gem,")
    |> mes("now that I think about it.")
    |> next()
    |> mes("[Ibrahim]")
    |> mes("Ah, here's an idea.")
    |> mes("Why don't you ask my")
    |> mes("scholar friend in Comodo")
    |> mes("to examine it? Maybe you")
    |> mes("can learn more about the")
    |> mes("emerald's so-called curse.")
    |> next()
    |> mes("[Ibrahim]")
    |> mes("I'll go ahead and send")
    |> mes("him a message ahead of")
    |> mes("time so that he'll know to")
    |> mes("expect your arrival, okay?")
    |> set_char_var(:jewel_nd, 9)
    |> close()
  end

  defp offer_emerald(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Ibrahim]")
      |> mes("Ah, I hear from a friend")
      |> mes("in Morocc that you happened")
      |> mes("to obtain the Unlucky Emerald.")
      |> mes("I'm sure it's one of the Four")
      |> mes("Cursed Jewels. You wouldn't")
      |> mes("mind if I look at it, do you?")
      |> next()
      |> select(["No!", "Sure, why not?"])

    case choice do
      1 ->
        ctx
        |> mes("[Ibrahim]")
        |> mes("No? Well, I'm sure you")
        |> mes("have your reasons. Still,")
        |> mes("maybe I can learn something")
        |> mes("that would benefit both of")
        |> mes("us if I examined it.")
        |> close()

      2 ->
        ctx =
          ctx
          |> mes("[Ibrahim]")
          |> mes("Ah, I appreciate it!")
          |> mes("Now, let's see here...")
          |> next()

        if count_item(ctx, 7725) > 0 do
          ctx
          |> mes("[Ibrahim]")
          |> mes("Yes, judging from its")
          |> mes("characteristic shape, this")
          |> mes("is the cursed emerald.")
          |> mes("Like me, you now possess")
          |> mes("one of the Four Cursed Jewels.")
          |> next()
          |> ask_emerald_plans()
        else
          ctx
          |> mes("[Ibrahim]")
          |> mes("Hm? Did you happen to")
          |> mes("misplace your emerald?")
          |> mes("I mean, it's not with you...")
          |> close()
        end

      _ ->
        ctx
    end
  end

  defp ask_emerald_plans(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Ibrahim]")
      |> mes("Tell me, what were")
      |> mes("you planning to do with")
      |> mes("the Unlucky Emerald?")
      |> next()
      |> select(["I'm going to sell it.", "I'm going to study it."])

    case choice do
      1 ->
        ctx
        |> mes("[Ibrahim]")
        |> mes("Oh, you weren't going")
        |> mes("to keep it? I wish I could")
        |> mes("afford to buy it from you...")
        |> mes("But I've had enough trouble")
        |> mes("buying the Diamond of")
        |> mes("Destruction.")
        |> next()
        |> mes("[Ibrahim]")
        |> mes("You already met several")
        |> mes("renown jewelers while")
        |> mes("you were looking for the")
        |> mes("dimaond. Why don't you ask")
        |> mes("them if they'll buy that")
        |> mes("Unlucky Emerald from you?")
        |> set_char_var(:jewel_nd, 1)
        |> close()

      2 ->
        ctx
        |> mes("[Ibrahim]")
        |> mes("Ah, I applaud your")
        |> mes("thirst for knowledge,")
        |> mes("your quest to seek truth.")
        |> mes("If you really want an expert")
        |> mes("to look at the emerald, talk")
        |> mes("to this scholar in Comodo.")
        |> next()
        |> mes("[Ibrahim]")
        |> mes("This man is an antique")
        |> mes("appraiser, an specialist in")
        |> mes("ancient artifacts and treasure.")
        |> mes("I highly recommend consulting")
        |> mes("him since he's been invaluable")
        |> mes("in my own jewel research.")
        |> set_char_var(:jewel_nd, 10)
        |> close()

      _ ->
        ctx
    end
  end

  defp discuss_diamond(ctx) do
    {ctx, choice} = select(ctx, ["How can I help you?", "What'd you hear?", "Bye!"])

    case choice do
      1 -> diamond_job(ctx)
      2 -> reputation(ctx)
      3 -> farewell(ctx)
      _ -> ctx
    end
  end

  defp diamond_job(ctx) do
    ctx =
      ctx
      |> mes("[Ibrahim]")
      |> mes("I wanted to ask you about")
      |> mes("the Four Cursed Jewels.")
      |> mes("All the merchants in the")
      |> mes("area are talking about them.")
      |> mes("Anyway, I was able to obtain")
      |> mes("the Diamond of Destruction!")
      |> next()

    {ctx, choice} =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("(^666666Hmm... He might")
      |> mes("be talking about that")
      |> mes("jewel Muff gave to Belder")
      |> mes("as collateral for his debt.^000000)")
      |> next()
      |> mes("[Ibrahim]")
      |> mes("I paid a hefty sum for it,")
      |> mes("but then I lost it after")
      |> mes("just a few days. I kept it")
      |> mes("under high security, but")
      |> mes("that didn't stop the thief...")
      |> next()
      |> mes("[Ibrahim]")
      |> mes("It's a risky job, but")
      |> mes("I want to employ you to")
      |> mes("find where my diamond went.")
      |> mes("It'd be best if you could get")
      |> mes("it back, but I can understand")
      |> mes("if you can't. You up for it?")
      |> next()
      |> select(["Sure, I'll help you.", "No, sorry."])

    case choice do
      1 ->
        ctx
        |> mes("[Ibrahim]")
        |> mes("Great! I knew it was")
        |> mes("a good idea to find you.")
        |> mes("The thief didn't leave any")
        |> mes("clues, but he should have")
        |> mes("some problems selling the gem.")
        |> mes("It's one of a kind, you know.")
        |> next()
        |> mes("[Ibrahim]")
        |> mes("Visiting the large")
        |> mes("jewelry shops in the")
        |> mes("Rune-Midgarts Kingdom")
        |> mes("would be a good start.")
        |> mes("Their merchants know the")
        |> mes("most about those jewels.")
        |> next()
        |> mes("[Ibrahim]")
        |> mes("The thief will also have")
        |> mes("to sell the jewel to a jeweler")
        |> mes("that can afford astronomical")
        |> mes("prices. There are three big")
        |> mes("locations you should check.")
        |> next()
        |> mes("[Ibrahim]")
        |> mes("Find ^0000FFJhonnita^000000 in Alberta,")
        |> mes("^0000FFKimeunbang^000000 in Payon, and")
        |> mes("^0000FFLeblo^000000 in Geffen. They wanted ")
        |> mes("that diamond badly too, so")
        |> mes("they'll remember if they")
        |> mes("heard any clues about it.")
        |> next()
        |> mes("[Ibrahim]")
        |> mes("Please don't let them")
        |> mes("know I've hired you to")
        |> mes("investigate that diamond.")
        |> mes("They won't speak to you")
        |> mes("if they figure out that")
        |> mes("I've sent you to them.")
        |> next()
        |> mes("[Ibrahim]")
        |> mes("Well, I'll be right")
        |> mes("here. I hope you come")
        |> mes("back with some good news.")
        |> setquest(3110)
        |> set_char_var(:diamond_edq, 15)
        |> close()

      2 ->
        ctx
        |> mes("[Ibrahim]")
        |> mes("Really? I went through")
        |> mes("a lot of trouble to find")
        |> mes("you, but... I understand.")
        |> mes("If you have a change of")
        |> mes("heart, I'll be willing to")
        |> mes("hire you for your expertise.")
        |> close()

      _ ->
        ctx
    end
  end

  defp reputation(ctx) do
    cond do
      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:novice) or
          Rathena.job_id(base_job(ctx)) == Rathena.job_id(:super_novice) ->
        ctx
        |> mes("[Ibrahim]")
        |> mes("So it's true...")
        |> mes("People say you're")
        |> mes("just a Novice, but")
        |> mes("you still help them")
        |> mes("out with their problems.")
        |> close()

      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:crusader) ->
        ctx
        |> mes("[Ibrahim]")
        |> mes("Heh, so you really")
        |> mes("are one of those holy")
        |> mes("knights. I'm glad to")
        |> mes("have met you for myself.")
        |> close()

      Rathena.job_id(base_class(ctx)) == Rathena.job_id(:swordman) ->
        ctx
        |> mes("[Ibrahim]")
        |> mes("I've got a few buddies")
        |> mes("in the Swordman Association.")
        |> mes("They dropped your name when")
        |> mes("I mentioned I was looking")
        |> mes("for someone smart and strong.")
        |> close()

      Rathena.job_id(base_class(ctx)) == Rathena.job_id(:acolyte) ->
        ctx
        |> mes("[Ibrahim]")
        |> mes("I didn't think a member")
        |> mes("of the clergy would be so")
        |> mes("strong, but you know, your")
        |> mes("reputation precedes you.")
        |> close()

      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:blacksmith) ->
        ctx
        |> mes("[Ibrahim]")
        |> mes("We have a mutual friend,")
        |> mes("you know that? Aragham")
        |> mes("really spoke highly of you.")
        |> close()

      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:alchemist) ->
        ctx
        |> mes("[Ibrahim]")
        |> mes("I know a guy who knows")
        |> mes("a guy in the Alchemist Guild.")
        |> mes("Around their parts, it sounds")
        |> mes("like you're pretty hot stuff.")
        |> close()

      Rathena.job_id(base_class(ctx)) == Rathena.job_id(:merchant) ->
        ctx
        |> mes("[Ibrahim]")
        |> mes("Hey, if I didn't know")
        |> mes("your name, how could I call")
        |> mes("myself a Merchant? You set")
        |> mes("an example for us all~")
        |> close()

      Rathena.job_id(base_class(ctx)) == Rathena.job_id(:mage) ->
        ctx
        |> mes("[Ibrahim]")
        |> mes("Magic is totally beyond")
        |> mes("my understanding, but")
        |> mes("if it gets the job done,")
        |> mes("it can't be all bad.")
        |> mes("I hear you're really")
        |> mes("good at that stuff.")
        |> close()

      Rathena.job_id(base_class(ctx)) == Rathena.job_id(:thief) ->
        ctx
        |> mes("[Ibrahim]")
        |> mes("Heh, it sounds like almost")
        |> mes("anyone who's anyone in")
        |> mes("Morocc knows who you are.")
        |> mes("Pleasure to make your")
        |> mes("acquaintance~")
        |> close()

      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:bard) ->
        ctx
        |> mes("[Ibrahim]")
        |> mes("Is it really true?")
        |> mes("I hear you sing")
        |> mes("like an angel...")
        |> close()

      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:dancer) ->
        ctx
        |> mes("[Ibrahim]")
        |> mes("Is it really true?")
        |> mes("I hear you dance")
        |> mes("like the devil...")
        |> close()

      Rathena.job_id(base_class(ctx)) == Rathena.job_id(:archer) ->
        ctx
        |> mes("[Ibrahim]")
        |> mes("Anyone who's used")
        |> mes("a bow seems to drop")
        |> mes("your name when it comes")
        |> mes("to accuracy and heroism.")
        |> mes("Hard to believe that I'm")
        |> mes("actually talking to you~")
        |> close()

      Rathena.job_id(class(ctx)) == Rathena.job_id(:star_gladiator) or
          Rathena.job_id(class(ctx)) == Rathena.job_id(:star_gladiator2) ->
        ctx
        |> mes("[Ibrahim]")
        |> mes("Me and your old master,")
        |> mes("Phoenix, we go way back.")
        |> mes("He had nothing but pride")
        |> mes("when he talked about you~")
        |> close()

      Rathena.job_id(class(ctx)) == Rathena.job_id(:soul_linker) ->
        ctx
        |> mes("[Ibrahim]")
        |> mes("I heard your name from")
        |> mes("this spiritual message")
        |> mes("I got from a dream. That")
        |> mes("doesn't sound crazy to")
        |> mes("you, does it?")
        |> close()

      true ->
        farewell(ctx)
    end
  end

  defp farewell(ctx) do
    ctx
    |> mes("[Ibrahim]")
    |> mes("Aren't you the least")
    |> mes("bit curious how I know")
    |> mes("about you? Wait, come back!")
    |> mes("I'm not really that suspicious!")
    |> close()
  end
end
