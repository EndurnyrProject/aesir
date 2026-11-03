defmodule Aesir.ZoneServer.Content.Npc.Quests.Skills.BlacksmithSkills.Akkie do
  @moduledoc """
  Akkie, a clumsy Blacksmith Guild representative in Geffen, teaches the Dubious Salesmanship
  quest skill.

  ## Behavior

  - Talks shop only with Blacksmiths and Master Smiths at Job Level 30 or higher.
  - Asks for 1 Steel, 5 Coal, 1 Iron Hammer, 1 Detrimindexta, and 500 zeny to forge a
    counterfeit zeny sample.
  - After botching the sample, asks for 1 Steel and 3 Coal, then a replacement Iron Hammer.
  - Teaches Dubious Salesmanship once the sample is finished.
  - Restores the skill to transcended smiths who completed the quest before rebirth, and to any
    finished smith who lacks it, sometimes pointing them to Goodman for Greed.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Lupus
    - Reddozen
    - Samuray22
    - DracoRPG
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "geffen",
        x: 178,
        y: 72,
        dir: 3,
        sprite: 726,
        name: "Akkie",
        scope: :shared,
        unique_name: "Akkie#qsk_bs"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @dubious_salesmanship 1012
  @steel 999
  @coal 1003
  @detrimindexta 971
  @iron_hammer 613

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if Rathena.job_id(base_job(ctx)) != Rathena.job_id(:blacksmith) do
      not_blacksmith(ctx)
    else
      master? = upper(ctx) == 1
      step = get_char_var(ctx, :BLACK_SK, 0)

      cond do
        master? and step == 7 ->
          remind_transcended(ctx)

        master? and step == 8 ->
          hi_again(ctx, "to Blacksmiths and Master Smiths, but somebody from our guild has")

        job_level(ctx) < 30 ->
          job_level_too_low(ctx, master?)

        true ->
          quest_step(ctx, step, master?)
      end
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp quest_step(ctx, 0, _master?), do: offer_quest(ctx)
  defp quest_step(ctx, 1, _master?), do: check_materials(ctx)
  defp quest_step(ctx, 2, _master?), do: first_mistake(ctx)
  defp quest_step(ctx, 3, _master?), do: check_retry_materials(ctx)
  defp quest_step(ctx, 4, _master?), do: broken_hammer(ctx)
  defp quest_step(ctx, 5, _master?), do: check_new_hammer(ctx)
  defp quest_step(ctx, 6, master?), do: teach(ctx, master?)

  defp quest_step(ctx, _step, _master?) do
    if Enum.random(1..2) == 1 do
      mention_goodman(ctx)
    else
      hi_again(
        ctx,
        "to Blacksmiths, Master Smiths and Mechanics, but somebody from our guild has"
      )
    end
  end

  defp not_blacksmith(ctx) do
    ctx
    |> mes("[Akkie]")
    |> mes("Ah, today seems like")
    |> mes("a perfect day for forging.")
    |> mes("I just feel like going behind")
    |> mes("a beautiful waterfall, getting")
    |> mes("some high quality materials,")
    |> mes("and just hammering things.")
    |> close()
  end

  defp remind_transcended(ctx) do
    ctx
    |> mes("[Akkie]")
    |> mes("I see that you've")
    |> mes("transcended since the")
    |> mes("last time we've met. Oh...")
    |> mes("You must have forgotten")
    |> mes("everything I've taught you.")
    |> mes("Well, let me teach you again~")
    |> next()
    |> mes("[Akkie]")
    |> mes("Actually, let me jog your")
    |> mes("memory with this counterfeit")
    |> mes("zeny that we made the last time. Do you remember how to perform")
    |> mes("Dubious Salesmanship? You")
    |> mes("should be able to use it now...")
    |> set_char_var(:BLACK_SK, 8)
    |> ensure_skill()
    |> close()
  end

  defp hi_again(ctx, audience_line) do
    ctx
    |> mes("[Akkie]")
    |> mes("Hi again~")
    |> mes("How has the smithing")
    |> mes("been coming along? Anyway,")
    |> mes("it was really nice of you to")
    |> mes("drop by and talk to me~")
    |> next()
    |> mes("[Akkie]")
    |> mes("It can get a little boring")
    |> mes("teaching Dubious Salesmanship")
    |> mes(audience_line)
    |> mes("to do this job. Anyway, farewell and be safe in your travels, okay?")
    |> ensure_skill()
    |> close()
  end

  defp job_level_too_low(ctx, true) do
    ctx
    |> mes("[Akkie]")
    |> mes("Hello, #{char_name(ctx, 0)},")
    |> mes("I'm here on behalf of the")
    |> mes("Blacksmith Guild to teach you")
    |> mes("a new skill. However, your Job")
    |> mes("Level is a little low right now")
    |> mes("for me to teach you anything...")
    |> next()
    |> mes("[Akkie]")
    |> mes("But practice smithing")
    |> mes("a little bit more, and")
    |> mes("once you qualify, I'll be")
    |> mes("sure to teach you my skill!")
    |> mes("Goodbye and good luck~")
    |> close()
  end

  defp job_level_too_low(ctx, false) do
    ctx
    |> mes("[Akkie]")
    |> mes("Hello, I'm Akkie from")
    |> mes("the Blacksmith Guild. I'm")
    |> mes("here to teach this new skill")
    |> mes("to all interested Blacksmiths")
    |> mes("and Master Smiths, but it looks")
    |> mes("like your Job Level is too low...")
    |> next()
    |> mes("[Akkie]")
    |> mes("I'm sorry, #{char_name(ctx, 0)},")
    |> mes("But you'll qualify for the")
    |> mes("skill I teach after you")
    |> mes("raise your Job Level.")
    |> mes("In the meantime, keep")
    |> mes("training, alright?")
    |> close()
  end

  defp offer_quest(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Akkie]")
      |> mes("Hello there~")
      |> mes("Isn't it such a")
      |> mes("wonderful day today?")
      |> mes("It's perfect for hunting!")
      |> next()
      |> mes("[Akkie]")
      |> mes("Um, let me introduce myself.")
      |> mes("I'm Akkie, a representative of")
      |> mes("the Blacksmith Guild that has")
      |> mes("been dispatched to teach the")
      |> mes("Dubious Salesmanship skill to")
      |> mes("Blacksmiths and Master Smiths.")
      |> next()
      |> mes("[Akkie]")
      |> mes("This additional class")
      |> mes("skill enables you to reduce")
      |> mes("the amount of zeny spent to")
      |> mes("cast Mammonite by 10%. This")
      |> mes("Passive skill might come in")
      |> mes("handy for you, #{char_name(ctx, 0)}.")
      |> next()
      |> mes("[Akkie]")
      |> mes("Although I'm new at")
      |> mes("this, would you like")
      |> mes("for me to teach you")
      |> mes("Dubious Salesmanship?")
      |> next()
      |> select(["Sure.", "No, thanks."])

    if choice == 1, do: start_quest(ctx), else: plead(ctx)
  end

  defp start_quest(ctx) do
    ctx
    |> mes(player_tag(ctx))
    |> mes("Sure. I'll try learning this")
    |> mes("new skill. Who knows?")
    |> mes("It might be really useful.")
    |> next()
    |> mes("[Akkie]")
    |> mes("Oh, that's great!")
    |> mes("You won't regret this!")
    |> mes("Now, let me explain how")
    |> mes("this skill works. Um, now")
    |> mes("where did I put that-- Ah.")
    |> mes("Let me read these guidelines.")
    |> next()
    |> mes("[Akkie]")
    |> mes("Using Dubious Salesmanship,")
    |> mes("we can reduce Mammonite's")
    |> mes("zeny cost by 10% by forging")
    |> mes("fake zeny to use in the skill.")
    |> mes("Since it's against enemies,")
    |> mes("we can let the forgery slide.")
    |> next()
    |> mes("[Akkie]")
    |> mes("Now, I need you to bring")
    |> mes("some materials so that I can")
    |> mes("demonstrate the forging of")
    |> mes("counterfeit zeny. Please")
    |> mes("bring me 1 Steel, 5 Coal,")
    |> mes("1 Iron Hammer and... and...")
    |> next()
    |> mes("[Akkie]")
    |> mes("Um, would you give")
    |> mes("me a minute to look")
    |> mes("up the information?")
    |> mes("I'm sorry about th-this...")
    |> mes("^333333(I thought I highlighted this")
    |> mes("in the manual. Where is it?)^000000")
    |> next()
    |> mes("[Akkie]")
    |> mes("Oh! Oh, I found it!")
    |> mes("L-let me start all")
    |> mes("over again. Uh...")
    |> next()
    |> mes(player_tag(ctx))
    |> mes("............")
    |> next()
    |> mes("[Akkie]")
    |> mes("^0000FF1 Steel^000000,")
    |> mes("^0000FF5 Coal^000000,")
    |> mes("^0000FF1 Iron Hammer^000000,")
    |> mes("^0000FF500 zeny^000000 and")
    |> mes("^0000FF1 Detrimindexta^000000. Would")
    |> mes("you bring those, please?")
    |> next()
    |> mes(player_tag(ctx))
    |> mes("Sure, sure.")
    |> mes("But are you actually")
    |> mes("able to teach me this")
    |> mes("skill? I mean...")
    |> next()
    |> mes("[Akkie]")
    |> mes("Oh no, I knew this was going to")
    |> mes("happen! I mean, um, it should")
    |> mes("be fine! I've been working here")
    |> mes("for 3 months a-and-- Just bring")
    |> mes("me the materials and I'll prove")
    |> mes("you can learn it e-easily!")
    |> next()
    |> mes("[Akkie]")
    |> mes("You've gotta trust me!")
    |> mes("You won't be disappointed,")
    |> mes("I promise! This skill is sooo")
    |> mes("useful! So just bring me those")
    |> mes("materials soon, alright?")
    |> set_char_var(:BLACK_SK, 1)
    |> close()
  end

  defp plead(ctx) do
    ctx
    |> mes("[Akkie]")
    |> mes("Wh-what?! But why not?")
    |> mes("A-am I not good enough")
    |> mes("for you? Please, I promise")
    |> mes("to do my best to teach you.")
    |> mes("Besides, I've got to reach")
    |> mes("my quota for the guild...")
    |> close()
  end

  defp check_materials(ctx) do
    cond do
      count_item(ctx, @steel) < 1 or count_item(ctx, @coal) < 5 or
        count_item(ctx, @detrimindexta) < 1 or count_item(ctx, @iron_hammer) < 1 ->
        missing_materials(ctx)

      zeny(ctx) < 500 ->
        missing_zeny(ctx)

      true ->
        take_materials(ctx)
    end
  end

  defp missing_materials(ctx) do
    ctx
    |> came_back()
    |> mes("[Akkie]")
    |> mes("Hmm, you're still")
    |> mes("missing a few things.")
    |> mes("Let me tell you what you")
    |> mes("need to bring me once again")
    |> mes("so that we can start training")
    |> mes("you in the skill right away.")
    |> next()
    |> mes("[Akkie]")
    |> mes("^0000FF1 Steel^000000,")
    |> mes("^0000FF5 Coal^000000,")
    |> mes("^0000FF1 Iron Hammer^000000,")
    |> mes("^0000FF500 zeny^000000 and")
    |> mes("^0000FF1 Detrimindexta^000000.")
    |> mes("Don't forget, okay?")
    |> close()
  end

  defp missing_zeny(ctx) do
    ctx
    |> mes("[Akkie]")
    |> mes("Hmm, you have all the")
    |> mes("forging materials, but")
    |> mes("I still need 500 zeny.")
    |> mes("We need that zeny to copy,")
    |> mes("or we won't be able to make")
    |> mes("convincing counterfeit money.")
    |> close()
  end

  defp take_materials(ctx) do
    ctx
    |> came_back()
    |> mes("[Akkie]")
    |> mes("Good job, it looks like")
    |> mes("you've got what we need.")
    |> mes("Alright, now please wait")
    |> mes("while I get these materials")
    |> mes("ready for forging, okay?")
    |> delitem(@coal, 5)
    |> delitem(@steel, 1)
    |> delitem(@detrimindexta, 1)
    |> delitem(@iron_hammer, 1)
    |> pay_zeny(500)
    |> set_char_var(:BLACK_SK, 2)
    |> close()
  end

  defp came_back(ctx) do
    ctx
    |> mes("[Akkie]")
    |> mes("Oh, you came back~")
    |> mes("Now let me see if you")
    |> mes("brought everything we")
    |> mes("need to make counterfeit")
    |> mes("zeny so that I can teach")
    |> mes("you Dubious Salesmanship.")
    |> next()
  end

  defp first_mistake(ctx) do
    ctx
    |> mes("[Akkie]")
    |> mes("A-ah! You came")
    |> mes("back sooner than")
    |> mes("I thought. Um, gee.")
    |> mes("Hmm. How should")
    |> mes("I tell you this?")
    |> next()
    |> mes(player_tag(ctx))
    |> mes("...")
    |> mes("......")
    |> mes(".........")
    |> next()
    |> mes("[Akkie]")
    |> mes("I'm so sorry! I messed")
    |> mes("something up while I was")
    |> mes("making a counterfeit sample!")
    |> mes("I'm so sorry, please d-don't")
    |> mes("report me to the Blacksmith")
    |> mes("Guild! Give me one more chance!")
    |> next()
    |> mes("[Akkie]")
    |> mes("I promise that next time")
    |> mes("I won't mess up! All I need")
    |> mes("is 1 Steel and 3 more Coals!")
    |> mes("Please d-don't be angry with")
    |> mes("me, it was just an accident!")
    |> next()
    |> mes(player_tag(ctx))
    |> mes("Okay, okay...")
    |> mes("Are you sure that's")
    |> mes("all you need me to get?")
    |> next()
    |> mes("[Akkie]")
    |> mes("Yes, yes! Oh, thank")
    |> mes("you for being so generous!")
    |> mes("Just bring me ^FF00001 Steel^000000 and")
    |> mes("^FF00003 Coals^000000 and we'll try again!")
    |> set_char_var(:BLACK_SK, 3)
    |> close()
  end

  defp check_retry_materials(ctx) do
    if count_item(ctx, @steel) < 1 or count_item(ctx, @coal) < 3 do
      ctx
      |> mes("[Akkie]")
      |> mes("All I need you to do")
      |> mes("is bring me 1 Steel and")
      |> mes("3 Coals. Then I should")
      |> mes("be able to teach you the")
      |> mes("Dubious Salesmanship skill~")
      |> close()
    else
      ctx
      |> mes("[Akkie]")
      |> mes("Oh, thank you so")
      |> mes("much for bringing these")
      |> mes("materials. Alright, I'll try")
      |> mes("really hard to succeed")
      |> mes("this time. Just give me")
      |> mes("a minute to prepare...")
      |> delitem(@steel, 1)
      |> delitem(@coal, 3)
      |> set_char_var(:BLACK_SK, 4)
      |> close()
    end
  end

  defp broken_hammer(ctx) do
    ctx
    |> mes("[Akkie]")
    |> mes("......")
    |> mes(".........")
    |> mes("............")
    |> next()
    |> mes(player_tag(ctx))
    |> mes("...?")
    |> next()
    |> mes(player_tag(ctx))
    |> mes("Oh no...")
    |> mes("Did... Did you...")
    |> mes("Did something happen?")
    |> next()
    |> mes("[Akkie]")
    |> mes("*Sniff* I b-broke the")
    |> mes("Iron Hammer you gave")
    |> mes("me! I c-can't finish forging")
    |> mes("this without one! Waaah~")
    |> next()
    |> mes(player_tag(ctx))
    |> mes("^333333(I guess I should")
    |> mes("really bring her a new")
    |> mes("^FF0000Iron Hammer^333333, or else")
    |> mes("I'll never learn this skill!)^000000")
    |> set_char_var(:BLACK_SK, 5)
    |> close()
  end

  defp check_new_hammer(ctx) do
    if count_item(ctx, @iron_hammer) < 1 do
      ctx
      |> mes("[Akkie]")
      |> mes("Waah~! I can't believe")
      |> mes("I broke the Iron Hammer!")
      |> mes("Would you please bring me")
      |> mes("another one so that I can")
      |> mes("finish this counterfeit zeny and teach you Dubious Salesmanship?")
      |> close()
    else
      ctx
      |> mes("[Akkie]")
      |> mes("^333333*Sniff*^000000 Did you")
      |> mes("r-really bring this")
      |> mes("Iron Hammer for me?")
      |> mes("Th-thank you for being so")
      |> mes("patient with my screwups...")
      |> next()
      |> mes("[Akkie]")
      |> mes("Okay, would you")
      |> mes("give me a moment?")
      |> mes("I'm going to try")
      |> mes("one more time.")
      |> delitem(@iron_hammer, 1)
      |> set_char_var(:BLACK_SK, 6)
      |> close()
    end
  end

  defp teach(ctx, master?) do
    ctx
    |> mes("[Akkie]")
    |> mes("Oh, you're back!")
    |> mes("Yaaaay, I finally did it!")
    |> mes("I finished making a sample")
    |> mes("of counterfeit zeny and even")
    |> mes("tested it with Mammonite!")
    |> next()
    |> mes("[Akkie]")
    |> mes("Oh, before you learn my")
    |> mes("skill, I'm supposed to tell you")
    |> mes("that my colleague, Goodman,")
    |> mes("can teach you another additional skill known as Greed. So you")
    |> mes("may want to look for him later.")
    |> next()
    |> mes("[Akkie]")
    |> mes("Okay, now the first part to")
    |> mes("learning Dubious Salesmanship")
    |> mes("is making this fake zeny. Watch")
    |> mes("this... Isn't it easy? Of course, you can only use this in battle to")
    |> mes("reduce Mammonite's zeny cost...")
    |> set_char_var(:BLACK_SK, if(master?, do: 9, else: 7))
    |> skill(@dubious_salesmanship, 1, :permanent)
    |> next()
    |> mes("[Akkie]")
    |> mes("Also, 90% of the cost of")
    |> mes("Mammonite has to be real")
    |> mes("zeny or the skill will begin")
    |> mes("to lose effectiveness. Well,")
    |> mes("that's all for the lesson. Now you can use Dubious Salesmanship!")
    |> next()
    |> mes("[Akkie]")
    |> mes("Thanks once again for")
    |> mes("putting up with my mistakes,")
    |> mes("I know it must have been really")
    |> mes("annoying. Anyway, I hope this")
    |> mes("skill is really useful for you.")
    |> mes("Drop again sometime, okay?")
    |> close()
  end

  defp mention_goodman(ctx) do
    ctx
    |> mes("[Akkie]")
    |> mes("Oh, have you spoken with")
    |> mes("Goodman in Einbroch yet?")
    |> mes("He's the representative of")
    |> mes("the Blacksmith Guild that")
    |> mes("teaches the Greed skill.")
    |> next()
    |> mes("[Akkie]")
    |> mes("If you're serious about")
    |> mes("smithing goods, the Greed")
    |> mes("skill might be very convenient.")
    |> mes("Though, I have to say that the")
    |> mes("skill's name is a little... Um.")
    |> mes("Hmm... It sounds pretty bad~")
    |> ensure_skill()
    |> close()
  end

  defp ensure_skill(ctx) do
    if getskilllv(ctx, @dubious_salesmanship) == 0,
      do: skill(ctx, @dubious_salesmanship, 1, :permanent),
      else: ctx
  end

  defp player_tag(ctx), do: "[#{char_name(ctx, 0)}]"
end
