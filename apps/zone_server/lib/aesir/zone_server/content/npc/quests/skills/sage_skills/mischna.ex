defmodule Aesir.ZoneServer.Content.Npc.Quests.Skills.SageSkills.Mischna do
  @moduledoc """
  Mishuna teaches the Sage quest skills Elemental Converter Creation and Elemental Change.

  ## Behavior

  - Turns away non-Sages and asks them to send any Sages they meet.
  - Asks a Sage for 10 Scorpion Tails, 7 Horns, 12 Rainbow Shells, 10 Snail's Shells and
    4 Blank Scrolls, then takes them and teaches Elemental Converter Creation.
  - Lets the Sage pick a Fire, Earth, Wind or Water Elemental Change whose Endow skill they
    already know, and asks for 20 matching elemental stones plus a Payon and a Morocc Solution.
  - Takes those items and teaches the chosen Elemental Change.
  - Restores Elemental Converter Creation for free whenever it was forgotten mid-quest.
  - After the quest, re-teaches any forgotten skill; a forgotten Elemental Change may be
    picked again freely.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Lupus
    - Reddozen
    - 5511
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
    quests/skills/sage_skills.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "yuno_in03", x: 176, y: 24, dir: 3, sprite: 755, name: "Mischna", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @create_converter 1007

  @elements [
    %{
      name: "Fire",
      skill: 1018,
      endow: "Blaze",
      endow_skill: 280,
      stone: 990,
      stones: "Red Bloods"
    },
    %{
      name: "Earth",
      skill: 1017,
      endow: "Quake",
      endow_skill: 283,
      stone: 993,
      stones: "Green Lives"
    },
    %{
      name: "Wind",
      skill: 1019,
      endow: "Tornado",
      endow_skill: 282,
      stone: 992,
      stones: "Wind of Verdure"
    },
    %{
      name: "Water",
      skill: 1008,
      endow: "Tsunami",
      endow_skill: 281,
      stone: 991,
      stones: "Crystal Blues"
    }
  ]

  @unknown_element %{name: "", skill: 0, endow: "", endow_skill: 0, stone: 0, stones: ""}

  @element_menu [
    "Fire Elemental Change",
    "Earth Elemental Change",
    "Wind Elemental Change",
    "Water Elemental Change"
  ]

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if Rathena.job_id(base_job(ctx)) != Rathena.job_id(:sage) do
      stranger(ctx)
    else
      sage_talk(ctx, get_char_var(ctx, :SAG_SK, 0))
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp sage_talk(ctx, 100), do: review(ctx)
  defp sage_talk(ctx, 0), do: introduce(ctx)

  defp sage_talk(ctx, 1) do
    if count_item(ctx, 904) < 10 or count_item(ctx, 947) < 7 or count_item(ctx, 1013) < 12 or
         count_item(ctx, 946) < 10 or count_item(ctx, 7433) < 4 do
      remind_converter_materials(ctx)
    else
      teach_converter(ctx)
    end
  end

  defp sage_talk(ctx, 2) do
    ctx
    |> recall_converter()
    |> element_choice_intro()
    |> choose_element_to_study()
  end

  defp sage_talk(ctx, progress) when progress in [10, 20, 30, 40] do
    element = Enum.fetch!(@elements, div(progress, 10) - 1)

    ctx
    |> recall_converter()
    |> study_element(element)
  end

  defp sage_talk(ctx, _progress), do: refer_friends(ctx)

  defp stranger(ctx) do
    ctx
    |> mes("[Mishuna]")
    |> mes("Good day, I'm Mishuna, one")
    |> mes("of the instructors here in the")
    |> mes("Schweicherbil Magic Academy.")
    |> mes("By any chance, are you a Sage")
    |> mes("or Scholar? Oh... You're not?")
    |> next()
    |> mes("[Mishuna]")
    |> mes("Oh, that's too bad.")
    |> mes("My apologies. But if you")
    |> mes("happen to know any, or meet")
    |> mes("any in your journeys, please")
    |> mes("direct them to me if they haven't heard of the lessons I provide.")
    |> next()
    |> mes("[Mishuna]")
    |> mes("I'm sorry to bother")
    |> mes("you, and I thank you")
    |> mes("for your time. Good")
    |> mes("day to you, adventurer.")
    |> close()
  end

  defp refer_friends(ctx) do
    ctx
    |> mes("[Mishuna]")
    |> mes("If you have any Sage or")
    |> mes("Scholar friends who haven't")
    |> mes("learned the skills from Sir")
    |> mes("Barmundt's scrolls, then")
    |> mes("please refer them to me.")
    |> next()
    |> mes("[Mishuna]")
    |> mes("I trust that you are")
    |> mes("finding that these")
    |> mes("element based skills")
    |> mes("are very useful in battle.")
    |> mes("Knowledge truly equates")
    |> mes("to power in the long run...")
    |> close()
  end

  defp review(ctx) do
    element_level =
      getskilllv(ctx, 1018) + getskilllv(ctx, 1017) + getskilllv(ctx, 1019) +
        getskilllv(ctx, 1008)

    converter_level = getskilllv(ctx, @create_converter)

    if element_level != 0 and converter_level != 0 do
      refer_friends(ctx)
    else
      ctx
      |> mes("[Mishuna]")
      |> mes("Ah, you must have")
      |> mes("forgotten what I taught")
      |> mes("you somehow. Perhaps")
      |> mes("you lost your copy of the")
      |> mes("skill scroll I gave you? No")
      |> mes("matter, I'll help you remember.")
      |> next()
      |> relearn(element_level, converter_level)
      |> mes("[Mishuna]")
      |> mes("Ah, you've learned these")
      |> mes("skills as quickly as I thought")
      |> mes("you would. Very well then,")
      |> mes("I hope you adeptly use these")
      |> mes("talents for the right purposes.")
      |> mes("Farewell for now, #{char_name(ctx, 0)}.")
      |> close()
    end
  end

  defp relearn(ctx, 0, converter_level) do
    ctx
    |> element_choice_intro()
    |> choose_element_to_relearn(converter_level)
  end

  defp relearn(ctx, _element_level, 0) do
    ctx
    |> mes("[Mishuna]")
    |> mes("Alright, I'm going")
    |> mes("to cast a spell that")
    |> mes("will help you remember")
    |> mes("the skills you forgot.")
    |> mes("Don't move, and try to")
    |> mes("stay as still as possible...")
    |> next()
    |> mes("[Mishuna]")
    |> mes("%$#@!#$% Yap~~")
    |> specialeffect2(:ruwach)
    |> next()
    |> mes("[Mishuna]")
    |> mes("Yap!")
    |> specialeffect2(:brandishspear)
    |> next()
    |> mes("^3355FFYou successfully recalled")
    |> mes("the Elemental Coverter")
    |> mes("Creation skill and are")
    |> mes("able to use it again.^000000")
    |> skill(@create_converter, 1, :permanent)
    |> next()
  end

  defp menu_element(choice), do: Enum.at(@elements, choice - 1, @unknown_element)

  defp choose_element_to_relearn(ctx, converter_level) do
    {ctx, choice} = select(ctx, @element_menu)
    element = menu_element(choice)

    if getskilllv(ctx, element.endow_skill) == 0 do
      ctx
      |> mes("[Mishuna]")
      |> mes("I'm sorry, but you haven't")
      |> mes("learned ^FF0000Endow #{element.endow}^000000, the skill")
      |> mes("required for ^FF0000#{element.name} Elemental")
      |> mes("Change^000000. You'll need to learn")
      |> mes("Endow #{element.endow} or select another")
      |> mes("Elemental Change skill.")
      |> next()
      |> choose_element_to_relearn(converter_level)
    else
      ctx
      |> mes("[Mishuna]")
      |> mes("Very well, I shall")
      |> mes("teach you the ^FF0000#{element.name}")
      |> mes("Elemental Change^000000 skill")
      |> mes("and the ^FF0000Elemental Converter")
      |> mes("Creation skill^000000. Please remain")
      |> mes("still while I chant this spell.")
      |> next()
      |> mes("[Mishuna]")
      |> mes("%$#@!#$% Yap~~")
      |> specialeffect2(:ruwach)
      |> next()
      |> mes("[Mishuna]")
      |> mes("Yap!")
      |> specialeffect2(:brandishspear)
      |> next()
      |> mes("^3355FFYou've successfully")
      |> mes("learned the #{element.name} Elemental")
      |> mes("Change skill and the Elemental")
      |> mes("Converter Creation skill.^000000")
      |> skill(element.skill, 1, :permanent)
      |> restore_converter(converter_level)
      |> next()
    end
  end

  defp restore_converter(ctx, 0), do: skill(ctx, @create_converter, 1, :permanent)
  defp restore_converter(ctx, _converter_level), do: ctx

  defp introduce(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Mishuna]")
      |> mes("Good day, I'm Mishuna, one")
      |> mes("of the instructors here in the")
      |> mes("Schweicherbil Magic Academy.")
      |> mes("How may I be of service?")
      |> next()
      |> select(["I seek new knowledge."])

    {ctx, choice} =
      ctx
      |> mes("[Mishuna]")
      |> mes("Ah, you must be #{char_name(ctx, 0)}.")
      |> mes("I've looked forward to meeting")
      |> mes("you. In the noble pursuit of")
      |> mes("knowledge, might I suggest")
      |> mes("reading the recently restored")
      |> mes("scrolls of Sir Barmundt?")
      |> next()
      |> mes("[Mishuna]")
      |> mes("Sir Barmundt's scrolls contain")
      |> mes("knowledge about the 4 elements,")
      |> mes("which are Fire, Water, Earth, and Wind. The knowledge of these")
      |> mes("scrolls can be applied in the")
      |> mes("use of 2 new Sage skills.")
      |> next()
      |> mes("[Mishuna]")
      |> mes("The first is called ^FF0000Elemental")
      |> mes("Change^000000, which enables you")
      |> mes("to change a monster's attribute")
      |> mes("according to the specific element of the Elemental Change skill")
      |> mes("that you have learned.")
      |> next()
      |> mes("[Mishuna]")
      |> mes("The second is called")
      |> mes("Elemental Converter Creation,")
      |> mes("which enables you to create")
      |> mes("converter items that are required to use the Elemental Change skill.")
      |> next()
      |> mes("[Mishuna]")
      |> mes("Although the knowledge of")
      |> mes("these two skills has been")
      |> mes("lost for years, we've finally")
      |> mes("been able to recover most")
      |> mes("of it. So, do you think you're")
      |> mes("ready to learn these skills?")
      |> next()
      |> select(["Maybe later.", "Yes, I am."])

    if choice == 1 do
      ctx
      |> mes("[Mishuna]")
      |> mes("Ah, you must be busy right")
      |> mes("now. No problem, just come")
      |> mes("back when you think you're")
      |> mes("ready to learn. Well then,")
      |> mes("farewell and have a good day~")
      |> close()
    else
      ctx
      |> mes("[Mishuna]")
      |> mes("Very well, then. First, you")
      |> mes("must learn the Elemental")
      |> mes("Coverter Creation skill, which")
      |> mes("is essential to learning the")
      |> mes("Elemental Change skill.")
      |> next()
      |> mes("[Mishuna]")
      |> mes("Please bring the required")
      |> mes("materials so that we can")
      |> mes("construct a basic elemental")
      |> mes("converter in order for you to")
      |> mes("learn the skill. Let's see,")
      |> mes("you will need to bring...")
      |> next()
      |> converter_materials()
      |> next()
      |> mes("[Mishuna]")
      |> mes("Alright, I shall be")
      |> mes("nexting here for your")
      |> mes("return. Remember that we")
      |> mes("need these items to create")
      |> mes("a converter so that you can learn the skill from my example...")
      |> set_char_var(:SAG_SK, 1)
      |> close()
    end
  end

  defp converter_materials(ctx) do
    ctx
    |> mes("[Mishuna]")
    |> mes("^ff00007 Horns^000000,")
    |> mes("^ff000012 Rainbow Shells^000000,")
    |> mes("^ff000010 Snail's Shells^000000,")
    |> mes("^ff00004 Blank Scrolls^000000 and")
    |> mes("^ff000010 Scorpion Tails^000000.^000000")
  end

  defp remind_converter_materials(ctx) do
    ctx
    |> mes("[Mishuna]")
    |> mes("Hm, you still haven't")
    |> mes("gathered all of the materials")
    |> mes("required to create an elemental")
    |> mes("coverter. Let me remind you")
    |> mes("what to bring so that you")
    |> mes("don't forget next time...")
    |> next()
    |> converter_materials()
    |> next()
    |> mes("[Mishuna]")
    |> mes("Don't forget that we need")
    |> mes("all of these items to create")
    |> mes("a converter so that you can")
    |> mes("learn the Elemental Converter")
    |> mes("Creation skill by watching")
    |> mes("me demonstrate it for you.")
    |> close()
  end

  defp teach_converter(ctx) do
    ctx
    |> mes("[Mishuna]")
    |> mes("Great, you brought everything.")
    |> mes("Now, let me explain the skill.")
    |> mes("The skills you learn as a Sage")
    |> mes("determine what kind of elemental converters that you can craft.")
    |> next()
    |> mes("[Mishuna]")
    |> mes("The ^FF0000Endow Blaze^000000 skill enables")
    |> mes("you to create Fire elemental")
    |> mes("converters. The ^FF0000Endow Quake^000000")
    |> mes("skill enables the creation")
    |> mes("of Earth elemental converters.")
    |> next()
    |> mes("[Mishuna]")
    |> mes("^FF0000Endow Tornado^000000 enables")
    |> mes("the creation of Wind elemental")
    |> mes("converters, and ^FF0000Endow Tsunami^000000")
    |> mes("enables the creation of Water")
    |> mes("elemental converters. That")
    |> mes("all makes sense, right?")
    |> next()
    |> mes("[Mishuna]")
    |> mes("Now, your elemental coverter")
    |> mes("creation success rate depends")
    |> mes("on the level of the Endow Blaze, Endow Quake, Endow Tornado,")
    |> mes("or Endow Tsunami skills, and")
    |> mes("your abilities.")
    |> next()
    |> mes("[Mishuna]")
    |> mes("Now, please take this copy")
    |> mes("of Barmundt's scroll, and use")
    |> mes("it as a reference when you try")
    |> mes("to craft elemental converters")
    |> mes("when you use the Elemental")
    |> mes("Converter Creation skill.")
    |> next()
    |> mes("^3355FFYou have learned the")
    |> mes("Elemental Converter")
    |> mes("Creation skill by reviewing")
    |> mes("your copy of Barmundt's scroll.^000000")
    |> specialeffect2(:absorbspirits)
    |> delitem(904, 10)
    |> delitem(947, 7)
    |> delitem(1013, 12)
    |> delitem(946, 10)
    |> delitem(7433, 4)
    |> set_char_var(:SAG_SK, 2)
    |> skill(@create_converter, 1, :permanent)
    |> next()
    |> mes("[Mishuna]")
    |> mes("Wow, #{char_name(ctx, 0)}!")
    |> mes("You learned that skill")
    |> mes("really quickly! No wonder")
    |> mes("people say that you're one")
    |> mes("of the best Sages around!")
    |> next()
    |> mes("[Mishuna]")
    |> mes("Now you're ready to")
    |> mes("learn the other skill,")
    |> mes("Elemental Change. Alright,")
    |> mes("I need to prepare a few things")
    |> mes("for this lesson, so we'll meet")
    |> mes("and discuss this later, okay?")
    |> close()
  end

  defp recall_converter(ctx) do
    if getskilllv(ctx, @create_converter) == 0 do
      ctx
      |> skill(@create_converter, 1, :permanent)
      |> mes(
        "- I recalled ^ff0000Elemental Converter Creation skill^000000 While I talk to Mishuna! -"
      )
      |> next()
    else
      ctx
    end
  end

  defp element_choice_intro(ctx) do
    ctx
    |> mes("[Mishuna]")
    |> mes("You'll be given the chance to")
    |> mes("choose which kind of ^FF0000Elemental")
    |> mes("Change^000000 skill that you want, even one that you didn't previously")
    |> mes("learn, so long as you fulfill")
    |> mes("the skill's requirements.")
    |> next()
    |> mes("[Mishuna]")
    |> mes("Keep in mind that once")
    |> mes("you learn your Elemental")
    |> mes("Change skill, you won't be")
    |> mes("able to change it. Now, which")
    |> mes("skill would you like to learn?")
    |> next()
  end

  defp choose_element_to_study(ctx) do
    {ctx, choice} = select(ctx, @element_menu)
    element = menu_element(choice)

    if getskilllv(ctx, element.endow_skill) == 0 do
      ctx
      |> mes("[Mishuna]")
      |> mes("I'm sorry, but you have not")
      |> mes("learned ^FF0000Endow #{element.endow}^000000, the skill")
      |> mes("required for the #{element.name} Elemental Change skill. Please learn Endow")
      |> mes("#{element.endow} or select another Elemental Change skill for me to teach you.")
      |> next()
      |> choose_element_to_study()
    else
      ctx
      |> mes("[Mishuna]")
      |> mes("Very well, then. Please")
      |> mes("bring the following items")
      |> mes("so that you can learn the")
      |> mes("#{element.name} Elemental Change skill.")
      |> next()
      |> mes("[Mishuna]")
      |> mes("^FF000020 #{element.stones}^000000,")
      |> mes("^FF00001 Payon Solution^000000 and")
      |> mes("^FF00001 Morocc Solution^000000. Please")
      |> mes("return to me once you have")
      |> mes("all the materials ready.")
      |> set_char_var(:SAG_SK, 10 * choice)
      |> close()
    end
  end

  defp study_element(ctx, element) do
    if count_item(ctx, element.stone) < 20 or count_item(ctx, 1089) < 1 or
         count_item(ctx, 1088) < 1 do
      ctx
      |> mes("[Mishuna]")
      |> mes("Are you having trouble")
      |> mes("gathering all the required")
      |> mes("items? Just in case, let me")
      |> mes("remind you of what you need")
      |> mes("to bring me to learn the #{element.name}")
      |> mes("Elemental Change skill.")
      |> next()
      |> mes("[Mishuna]")
      |> mes("^ff000020 #{element.stones}^000000,")
      |> mes("^ff00001 Payon Solution^000000 and")
      |> mes("^ff00001 Morocc Solution^000000. Please")
      |> mes("don't forget and have the")
      |> mes("materials ready for the next")
      |> mes("time you see me, alright?")
      |> close()
    else
      teach_element(ctx, element)
    end
  end

  defp teach_element(ctx, element) do
    ctx
    |> mes("[Mishuna]")
    |> mes("Ah, you're back. I can now")
    |> mes("finally teach you about the")
    |> mes("#{element.name} Elemental Change skill.")
    |> mes("This skill has the chance to")
    |> mes("permanently change a targeted")
    |> mes("monster's attribute to #{element.name}.")
    |> next()
    |> mes("[Mishuna]")
    |> mes("Remember that you must")
    |> mes("use an elemental converter to")
    |> mes("cast this skill, and that it has a success rate, similarly to the")
    |> mes("Elemental Converter Creation")
    |> mes("skill. So be aware of that.")
    |> next()
    |> mes("[Mishuna]")
    |> mes("Now, #{char_name(ctx, 0)},")
    |> mes("I'm going to cast a spell")
    |> mes("that will help you memorize")
    |> mes("the #{element.name} Elemental Change")
    |> mes("skill. Try to stay still...")
    |> next()
    |> mes("^3355FFMishuna begins to chant")
    |> mes("a strange incantation as")
    |> mes("a soft blue glow surrounds")
    |> mes("his body and slowly grows")
    |> mes("brighter and more intense.^000000")
    |> specialeffect2(:ruwach)
    |> next()
    |> mes("[Mishuna]")
    |> mes("@#$%^~ Yap!")
    |> specialeffect2(:brandishspear)
    |> delitem(element.stone, 20)
    |> delitem(1089, 1)
    |> delitem(1088, 1)
    |> set_char_var(:SAG_SK, 100)
    |> skill(element.skill, 1, 0)
    |> next()
    |> mes("[Mishuna]")
    |> mes("#{char_name(ctx, 0)}...")
    |> mes("I'm happy to say that you've")
    |> mes("successfully memorized the")
    |> mes("#{element.name} Elemental Change skill.")
    |> mes("I hope that it serves you well")
    |> mes("in battle. Farewell for now~")
    |> close()
  end
end
