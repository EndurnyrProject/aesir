defmodule Aesir.ZoneServer.Content.Npc.Quests.Skills.WizardSkills.Meow do
  @moduledoc """
  Meow, a Wizard turned into a cat, teaches the Wizard Sight Blaster skill quest.

  ## Behavior

  - Greets non-Wizards and sleepy Wizards with a short chat about being a cat.
  - Sends a Wizard to the Prontera Chivalry to learn push-back theory.
  - Asks for 10 each of Crystal Blue, Green Live, Red Blood and Wind of Verdure as tuition.
  - Takes the stones and teaches Sight Blaster permanently.
  - Re-teaches Sight Blaster to a Wizard who completed the quest but lost the skill.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Lupus
    - Reddozen
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
    quests/skills/wizard_skills.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "gef_tower",
        x: 115,
        y: 36,
        dir: 4,
        sprite: 876,
        name: "Meow",
        scope: :shared,
        unique_name: "Meow#q_wiz"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @sight_blaster 1006

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if Rathena.job_id(base_job(ctx)) == Rathena.job_id(:wizard) do
      wizard_talk(ctx, get_char_var(ctx, :WIZ_SK, 0))
    else
      {ctx, choice} = yawn_greeting(ctx)
      if choice == 1, do: cat_story(ctx), else: stranger_nap(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp wizard_talk(ctx, 100) do
    if getskilllv(ctx, @sight_blaster) == 0 do
      reteach_sight_blaster(ctx)
    else
      sleep_talk(ctx)
    end
  end

  defp wizard_talk(ctx, 0) do
    {ctx, choice} = yawn_greeting(ctx)
    if choice == 1, do: cat_story(ctx), else: offer_lesson(ctx)
  end

  defp wizard_talk(ctx, 1) do
    ctx
    |> mes("[Meow]")
    |> mes("What are you still doing")
    |> mes("here? Didn't I tell you to go")
    |> mes("to the Prontera Chivalry and")
    |> mes("ask someone there to teach")
    |> mes("you about Push Back theory?")
    |> close()
  end

  defp wizard_talk(ctx, 2), do: request_tuition(ctx)

  defp wizard_talk(ctx, 3) do
    if count_item(ctx, 991) < 10 or count_item(ctx, 993) < 10 or
         count_item(ctx, 990) < 10 or count_item(ctx, 992) < 10 do
      missing_stones(ctx)
    else
      teach_sight_blaster(ctx)
    end
  end

  defp wizard_talk(ctx, _progress), do: sleep_talk(ctx)

  defp reteach_sight_blaster(ctx) do
    ctx
    |> mes("[Meow]")
    |> mes("What...?! You forgot the")
    |> mes("awesome skill I taught you?")
    |> mes("Transcending's no excuse")
    |> mes("for forgetting! Alright, so you")
    |> mes("want me to teach you, eh?")
    |> mes("Alright, here's your lesson!")
    |> next()
    |> mes("^3355FF*BAM! BOOM! CRASH!*^000000")
    |> specialeffect2(:sui_explosion)
    |> next()
    |> mes("[Meow]")
    |> mes("Don't you dare get")
    |> mes("hoity-toity with me, just")
    |> mes("because you've been reborn!")
    |> mes("You better remember how to")
    |> mes("do that skill before I give")
    |> mes("you another whupping!")
    |> next()
    |> mes("^3355FFYou miraculously recall")
    |> mes("the Sight Blaster skill before")
    |> mes("Meow can administer another")
    |> mes("vicious beating to you.")
    |> specialeffect2(:absorbspirits)
    |> skill(@sight_blaster, 1, :permanent)
    |> next()
    |> mes("[Meow]")
    |> mes("Remember now?")
    |> mes("Great. Now I'm going")
    |> mes("back to taking a nap.")
    |> mes("If you even think about")
    |> mes("bothering me, I'll make")
    |> mes("you regret it. Mark my word!")
    |> close()
  end

  defp sleep_talk(ctx) do
    ctx
    |> mes("[Meow]")
    |> mes("Zzz... Zzz...")
    |> mes("Catherine... I'll")
    |> mes("make you sorry for")
    |> mes("turning me into a kitty...")
    |> mes("I'm gonna... Gonna... Zzz...")
    |> close()
  end

  defp yawn_greeting(ctx) do
    ctx
    |> mes("[Meow]")
    |> mes("*Yaaawn~*")
    |> mes("So sleeepy...")
    |> mes("Hm? Did you want")
    |> mes("to talk to me? Don't")
    |> mes("bother me if you've")
    |> mes("got nothing to say!")
    |> next()
    |> select(["A cat?", "Now I'm sleepy, too..."])
  end

  defp cat_story(ctx) do
    ctx
    |> mes("[Meow]")
    |> mes("Yeah. Yeah, I'm a cat.")
    |> mes("For now, anyway. Damn that")
    |> mes("Catherine! She turned me into")
    |> mes("this form when I borrowed some")
    |> mes("gemstones without her consent.")
    |> mes("I was gonna tell her!")
    |> next()
    |> mes("[Meow]")
    |> mes("Once I become human")
    |> mes("again and regain my powers,")
    |> mes("I'm gonna go freakin' buck")
    |> mes("wild. Catherine, you, everyone.")
    |> mes("You're all turning into cats!")
    |> close()
  end

  defp stranger_nap(ctx) do
    ctx
    |> mes("[Meow]")
    |> mes("Hah! Yeah...")
    |> mes("Taking a nap sounds like")
    |> mes("the best idea I've heard")
    |> mes("all day. Hm. ^333333*Yaaawwn~*^000000")
    |> mes("There we go, time to sleep...")
    |> mes("ZzzzzzzZZZzzz... ZzZzzzz...")
    |> close()
  end

  defp offer_lesson(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Meow]")
      |> mes("Hah! Yeah...")
      |> mes("Taking a nap sounds like")
      |> mes("the best idea I've hear--oh.")
      |> mes("Wait. You're a Wizard, right?")
      |> mes("I was so sleepy, I didn't even")
      |> mes("notice. Ah, this is good~")
      |> next()
      |> mes("[Meow]")
      |> mes("Now, I'm supposed to be")
      |> mes("teaching Wizards this new")
      |> mes("skill on behalf of the Wizard")
      |> mes("Guild. Although I don't really")
      |> mes("want to, I pretty much don't have a choice. So what do you say?")
      |> next()
      |> select(["Nah, I'm too sleepy...", "Sure, I'd like to learn a new skill."])

    if choice == 1 do
      ctx
      |> mes("[Meow]")
      |> mes("^333333*Yaaaawn*^000000")
      |> mes("Alright. If you wanna")
      |> mes("learn it later, then come")
      |> mes("back and remind me about")
      |> mes("the skill. Well then, back to")
      |> mes("napping... Zzz... Zzz...")
      |> close()
    else
      explain_lesson(ctx)
    end
  end

  defp explain_lesson(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Meow]")
      |> mes("Really? Fine, fine.")
      |> mes("Just so you know, I'm")
      |> mes("only teaching this skill so")
      |> mes("that Catherine will return me")
      |> mes("to my human form. It's too")
      |> mes("humiliating to just be a cat!")
      |> next()
      |> mes("[Meow]")
      |> mes("Wait, now that I think")
      |> mes("about it, that dog Maria has")
      |> mes("been hanging about Catherine")
      |> mes("for the longest time, but she's")
      |> mes("never regained her human form.")
      |> mes("N-no! I can't lose hope now!")
      |> next()
      |> mes("[Meow]")
      |> mes("Oh, let's just get this over")
      |> mes("with. Now, you're aware that we")
      |> mes("Wizards have great long range")
      |> mes("attack skills, but we're weak")
      |> mes("in short range battles, right?")
      |> next()
      |> mes("[Meow]")
      |> mes("This new skill that I am")
      |> mes("going to teach you has been")
      |> mes("designed to compensate the")
      |> mes("Wizard class's weakness in")
      |> mes("close range combat. First,")
      |> mes("you chant the spell...")
      |> next()
      |> mes("[Meow]")
      |> mes("Then, for the skill's duration,")
      |> mes("you will be protected by a shield that will push back and damage")
      |> mes("enemies that approach too closely. Doesn't that sound really useful")
      |> mes("in heated battle situations?")
      |> next()
      |> select(["I can push enemies away?"])

    ctx
    |> mes("[Meow]")
    |> mes("Sure you can, well, once you")
    |> mes("learn the skill. Hmm, but you")
    |> mes("need to have a good grasp on")
    |> mes("push back theory before you can")
    |> mes("learn the skill. Hmm, you might")
    |> mes("need a better explanation...")
    |> next()
    |> mes("[Meow]")
    |> mes("You know what? Knights are")
    |> mes("pretty much experts with skills")
    |> mes("that push enemies back, so go")
    |> mes("and find one who'll explain Push Back theory to you in Prontera.")
    |> next()
    |> mes("[Meow]")
    |> mes("Check the 11 o' clock")
    |> mes("direction on your Mini-Map")
    |> mes("in Prontera to find the Knight")
    |> mes("Chivalry. Someone there should")
    |> mes("be willing to teach you more")
    |> mes("about Push Backs in skills...")
    |> set_char_var(:WIZ_SK, 1)
    |> close()
  end

  defp request_tuition(ctx) do
    ctx
    |> mes("[Meow]")
    |> mes("Hm? Oh good, you learned")
    |> mes("the basics for pushing back")
    |> mes("enemies. Now you're almost")
    |> mes("ready to learn the skill that")
    |> mes("I'm supposed to teach you.")
    |> next()
    |> mes("[Meow]")
    |> mes("I'm no philanthropist, so")
    |> mes("I expect some tuition for all")
    |> mes("of my instruction and effort!")
    |> mes("Mmm, what would be good for")
    |> mes("my payment? Ah, I'm low on")
    |> mes("enchanted stones right now~")
    |> next()
    |> mes("[Meow]")
    |> mes("Go and bring me")
    |> mes("^FF000010 Crystal Blues^000000,")
    |> mes("^FF000010 Green Lives^000000,")
    |> mes("^FF000010 Red Bloods^000000 and")
    |> mes("^FF000010 Winds of Verdure^000000.")
    |> next()
    |> mes("[Meow]")
    |> mes("It's not that much,")
    |> mes("so don't complain and")
    |> mes("come back as soon as you")
    |> mes("can. While you're out there,")
    |> mes("I'm going to take another nap~")
    |> set_char_var(:WIZ_SK, 3)
    |> close()
  end

  defp missing_stones(ctx) do
    ctx
    |> mes("[Meow]")
    |> mes("^333333*Yaaaaaawn~*^000000 Hm?")
    |> mes("H-how dare you come")
    |> mes("back without everything")
    |> mes("I asked you for?! You")
    |> mes("forgot what to bring,")
    |> mes("didn't you? Grrrr...")
    |> next()
    |> mes("[Meow]")
    |> mes("I said to bring")
    |> mes("^ff000010 Crystal Blues^000000,")
    |> mes("^ff000010 Green Lives^000000,")
    |> mes("^ff000010 Red Bloods^000000 and")
    |> mes("^ff000010 Winds of Verdure^000000!")
    |> next()
    |> mes("[Meow]")
    |> mes("Don't forget this time!")
    |> mes("And don't even think of")
    |> mes("waking me up until you")
    |> mes("find everything I asked for!")
    |> close()
  end

  defp teach_sight_blaster(ctx) do
    ctx
    |> mes("[Meow]")
    |> mes("*Yaaaawn~* Wh-wha?")
    |> mes("Oh, it's you. So did you")
    |> mes("bring the stones I wanted?")
    |> mes("Mmm. Good, let me see if")
    |> mes("you brought them all...")
    |> mes("One, two, three...")
    |> next()
    |> mes("[Meow]")
    |> mes(".................")
    |> mes("Screw it. I don't feel")
    |> mes("like counting this all.")
    |> mes("Let me just take these,")
    |> mes("and teach you the skill")
    |> mes("so I can go back to sleep.")
    |> next()
    |> mes("[Meow]")
    |> mes("This skill is called,")
    |> mes("''^FF0000Sight Blaster^000000.'' Pretty")
    |> mes("cool, eh? Anyway, it's a Fire")
    |> mes("attribute skill that requires")
    |> mes("you to cast Sight before you")
    |> mes("can activate it. Now try it.")
    |> next()
    |> specialeffect2(:sui_explosion)
    |> mes("^3355FF*BAM! BOOM!*^000000")
    |> next()
    |> mes("[Meow]")
    |> mes("......")
    |> mes("Huh. Not exactly right,")
    |> mes("but not too bad for a first")
    |> mes("try. Remember to will the")
    |> mes("push back to happen. Ergh,")
    |> mes("let's try it once again, okay?")
    |> next()
    |> mes("[Meow]")
    |> mes("You gotta will it.")
    |> mes("Push! Push with")
    |> mes("your freakin' mind!")
    |> mes("Well, push the flames")
    |> mes("you summoned with Sight")
    |> mes("with your mind. Not that hard!")
    |> next()
    |> mes("[Meow]")
    |> mes("Finally...!")
    |> mes("You actually learned it!")
    |> mes("That took way too much effort,")
    |> mes("but at least we're done here.")
    |> specialeffect2(:absorbspirits)
    |> delitem(991, 10)
    |> delitem(993, 10)
    |> delitem(990, 10)
    |> delitem(992, 10)
    |> set_char_var(:WIZ_SK, 100)
    |> skill(@sight_blaster, 1, :permanent)
    |> next()
    |> mes("[Meow]")
    |> mes("I'm so tired from all of")
    |> mes("this teaching. I think I'll")
    |> mes("take a well deserved nap")
    |> mes("right now. Go on your way,")
    |> mes("and if you know any Wizards,")
    |> mes("send 'em to me, I guess.")
    |> close()
  end
end
