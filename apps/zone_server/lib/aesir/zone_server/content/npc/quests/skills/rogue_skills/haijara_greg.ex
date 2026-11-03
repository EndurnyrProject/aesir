defmodule Aesir.ZoneServer.Content.Npc.Quests.Skills.RogueSkills.HaijaraGreg do
  @moduledoc """
  Haijara Greg, the Rogue hiding in the guild's panic room who teaches Close Confine.

  ## Behavior

  - Rogues who threaten him are hit by Close Confine and Back Stab, losing most of their HP.
  - Rogues who offer help hear the legend of Chae Takbae and carry his letter to his sons.
  - After his sons' replies and Thor's training, he sends the player after the Killer who
    steals the skill book.
  - Once the book is returned, he optionally explains the skill and teaches Close Confine.
  - Transcended Stalkers who completed the quest relearn the skill from him.
  - Non-Rogues are begged to send a trustworthy Rogue or Stalker.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Lupus
    - Reddozen
    - 2Spiritual Kid
    - DracoRPG
    - L0ne_W0lf
    - Samuray22
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "in_rogue",
        x: 355,
        y: 179,
        dir: 0,
        sprite: 46,
        name: "Haijara Greg",
        scope: :shared,
        unique_name: "Haijara Greg#rogueguild"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if Rathena.job_id(base_job(ctx)) == Rathena.job_id(:rogue) do
      talk_to_rogue(ctx, get_char_var(ctx, :ROG_SK, 0))
    else
      ctx
      |> panic_room_intro()
      |> next()
      |> mes("[Haijara Greg]")
      |> mes("Please...")
      |> mes("Find me a Stalker")
      |> mes("or a Rogue that I can")
      |> mes("trust and send him to")
      |> mes("help me! I don't have ")
      |> mes("much time left...")
      |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp talk_to_rogue(ctx, step) do
    cond do
      step == 12 and upper(ctx) == 1 ->
        ctx
        |> mes("[Haijara Greg]")
        |> mes("Hm? Ah, amnesia as")
        |> mes("resulting from transcending,")
        |> mes("eh? Then I will teach you the")
        |> mes("Close Confine skill once again.")
        |> specialeffect2(:lightsphere)
        |> skill(1005, 1, :permanent)
        |> set_char_var(:ROG_SK, 13)
        |> close()

      step == 13 and upper(ctx) == 1 ->
        ctx
        |> mes("[Haijara Greg]")
        |> mes("A Stalker, eh?")
        |> mes("Make sure that you")
        |> mes("use your abilities to")
        |> mes("malign foes that deserve")
        |> mes("to be stalked. Best of")
        |> mes("luck to you, adventurer.")
        |> close()

      true ->
        quest_step(ctx, step)
    end
  end

  defp quest_step(ctx, step) when step < 1, do: ctx |> panic_room_intro() |> close()

  defp quest_step(ctx, 1) do
    {ctx, choice} =
      ctx
      |> mes("[Haijara Greg]")
      |> mes("Wh-who are you,")
      |> mes("and how did you get")
      |> mes("in here? Identify yourself!")
      |> next()
      |> select(["I don't mean you any harm!", "Give us what we want!"])

    if choice == 1, do: explain_visit(ctx), else: punish_greed(ctx)
  end

  defp quest_step(ctx, 2) do
    ctx
    |> mes("[Haijara Greg]")
    |> mes("We're running out of")
    |> mes("time... Please bring this")
    |> mes("letter to my youngest son,")
    |> mes("^FF0000Louis^000000, as soon as you can!")
    |> mes("You can find him in the Rogue")
    |> mes("Guild near ^FF0000Hollgrehenn Junior^000000.")
    |> close()
  end

  defp quest_step(ctx, 3) do
    ctx
    |> mes("[Haijara Greg]")
    |> mes("Louis sent you to find")
    |> mes("^FF0000Thor^000000? He's in the Rogue")
    |> mes("Guild near ^FF0000Hermanthorn Jr.^000000,")
    |> mes("isn't he? I'm sorry that you")
    |> mes("have to visit my sons one by")
    |> mes("one... I know it's impractical.")
    |> close()
  end

  defp quest_step(ctx, 4) do
    ctx
    |> mes("[Haijara Greg]")
    |> mes("Ah, looking for ^FF0000Jay^000000, eh?")
    |> mes("He's near ^FF0000Antonio Jr.^000000 here")
    |> mes("in the Rogue Guild. Or at")
    |> mes("least, he's usually there.")
    |> close()
  end

  defp quest_step(ctx, 5) do
    ctx
    |> mes("[Haijara Greg]")
    |> mes("Oh, you're back!")
    |> mes("And you've brought")
    |> mes("a letter from Jay.")
    |> mes("Good, good, let me")
    |> mes("read what he has to say...")
    |> set_char_var(:ROG_SK, 6)
    |> next()
    |> mes("[Haijara Greg]")
    |> mes("Ah, great news! He's")
    |> mes("contacted the Rogue Guild")
    |> mes("to request extra protection")
    |> mes("and to alert their guard. I can")
    |> mes("finally relax just a little now. No one messes with Rogues.")
    |> next()
    |> mes("[Haijara Greg]")
    |> mes("Thank you very much for")
    |> mes("your help. I would be in")
    |> mes("hiding forever if it weren't")
    |> mes("for you. In return, let me")
    |> mes("offer you the chance to learn")
    |> mes("Chae Takbae's secret skill.")
    |> next()
    |> mes("[Haijara Greg]")
    |> mes("Please speak to ^FF0000Thor^000000")
    |> mes("and tell him that I've")
    |> mes("permitted you to learn")
    |> mes("the skill I have taught")
    |> mes("all of my sons. He'll")
    |> mes("comply, I'm sure of it.")
    |> close()
  end

  defp quest_step(ctx, 6) do
    ctx
    |> mes("[Haijara Greg]")
    |> mes("Please ask Thor to teach")
    |> mes("you Chae Takbae's secret")
    |> mes("Rogue skill. Understand that")
    |> mes("I can't teach you this skill")
    |> mes("with the equipment here in")
    |> mes("this sloven panic room.")
    |> close()
  end

  defp quest_step(ctx, 7) do
    ctx
    |> mes("[Haijara Greg]")
    |> mes("Hm...? Aren't you")
    |> mes("supposed to be in the")
    |> mes("middle of training to learn")
    |> mes("that skill? Please speak to")
    |> mes("Thor and complete your training.")
    |> close()
  end

  defp quest_step(ctx, 8) do
    ctx
    |> mes("[Haijara Greg]")
    |> mes("You've completed the")
    |> mes("training? Ah, that's quite")
    |> mes("exceptional. However, you")
    |> mes("should speak to Thor first...")
    |> close()
  end

  defp quest_step(ctx, 9) do
    ctx
    |> mes("[Haijara Greg]")
    |> mes("Oh, you've come back!")
    |> mes("I hear that you've completed")
    |> mes("the training and are ready")
    |> mes("to hear about the applications")
    |> mes("for the Close Confine skill.")
    |> next()
    |> mes("[Haijara Greg]")
    |> mes("Wah! What th--?!")
    |> mes("Stop! P-please, stop")
    |> mes("that man! We can't let")
    |> mes("him steal that book!")
    |> specialeffect(:comboattack5)
    |> donpcevent("Killer#Rogueguild::OnEnable")
    |> set_char_var(:ROG_SK, 10)
    |> close()
  end

  defp quest_step(ctx, 10) do
    ctx
    |> mes("[Haijara Greg]")
    |> mes("That man just stole the")
    |> mes("Close Confine skill book!")
    |> mes("Please! Don't let him get")
    |> mes("away! That book is priceless!")
    |> donpcevent("#killershow01::OnEnable")
    |> close()
  end

  defp quest_step(ctx, 11) do
    {ctx, choice} =
      ctx
      |> donpcevent("Killer#Rogueguild::OnDisable")
      |> donpcevent("#killershow01::OnDisable")
      |> mes("^3355FFYou returned the")
      |> mes("skill book written by")
      |> mes("Chae Takbae to Haijara.^000000")
      |> next()
      |> mes("[Haijara Greg]")
      |> mes("Thanks so much for your")
      |> mes("assistance. Now, if you'd")
      |> mes("like to know some detailed")
      |> mes("information about Close")
      |> mes("Confine, I can tell you more")
      |> mes("about the skill if you like.")
      |> next()
      |> select(["Yes, please.", "No, thanks."])

    if choice == 1, do: explain_close_confine(ctx), else: wish_luck(ctx)
  end

  defp quest_step(ctx, _step) do
    ctx
    |> mes("[Haijara Greg]")
    |> mes("Thank you for helping")
    |> mes("me protect this priceless")
    |> mes("skill book. I hope that the")
    |> mes("next time we meet, we'll be")
    |> mes("comrades on the battlefield...")
    |> close()
  end

  defp panic_room_intro(ctx) do
    ctx
    |> mes("[Haijara Greg]")
    |> mes("H-how did you find this")
    |> mes("place? I thought this panic")
    |> mes("room was supposed to be")
    |> mes("impenetrable, even by Rogues!")
    |> next()
    |> mes("[Haijara Greg]")
    |> mes("This can't be good!")
    |> mes("It will only be a matter of")
    |> mes("time before they find me...")
  end

  defp explain_visit(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Haijara Greg]")
      |> mes("No...?")
      |> mes("Then... Then")
      |> mes("why have you come?")
      |> mes("It is no accident that")
      |> mes("you have found me.")
      |> next()
      |> select(["I came to help you.", "Oh, actually, I wasn't looking for you."])

    if choice == 1 do
      ask_for_help(ctx)
    else
      ctx
      |> mes("[Haijara Greg]")
      |> mes("Hm...?")
      |> mes("That seems unlikely, but")
      |> mes("I suppose I better give you")
      |> mes("the benefit of the doubt.")
      |> mes("Well then, I hope that you")
      |> mes("can find your way out of here.")
      |> close()
    end
  end

  defp ask_for_help(ctx) do
    ctx = ctx |> mes("[Haijara Greg]") |> mes("Hmm... Well, I suppose")

    ctx =
      if upper(ctx) == 1,
        do: mes(ctx, "I can trust a fellow Stalker"),
        else: mes(ctx, "I can trust a fellow Rogue")

    {ctx, knows_legend} =
      ctx
      |> mes("with my predictament. Honor")
      |> mes("among thieves and all that.")
      |> mes("Alright. Have you ever heard")
      |> mes("the legend of Chae Takbae?")
      |> next()
      |> select(["No", "Yes"])

    ctx = if knows_legend == 1, do: tell_legend(ctx), else: recall_legend(ctx)
    {ctx, choice} = select(ctx, ["Sure!", "Sorry, but I'm busy."])

    if choice == 1 do
      ctx
      |> mes("[Haijara Greg]")
      |> mes("Oh, thank you so much!")
      |> mes("Listen, I can't risk being")
      |> mes("found, so would you take")
      |> mes("this letter to my youngest")
      |> mes("son, ^FF0000Louis Greg^000000? Hurry,")
      |> mes("there's not much time left!")
      |> set_char_var(:ROG_SK, 2)
      |> close()
    else
      ctx
      |> mes("[Haijara Greg]")
      |> mes("I... I see.")
      |> mes("But please realize")
      |> mes("that, if not you, who")
      |> mes("can I trust to help me?")
      |> close()
    end
  end

  defp tell_legend(ctx) do
    ctx
    |> mes("[Haijara Greg]")
    |> mes("100 years ago, Chae Takbae")
    |> mes("was the very first person to")
    |> mes("transcend his limits. He was")
    |> mes("also the very person to choose")
    |> mes("a different path, rather than the job order he previously had.")
    |> next()
    |> mes("[Haijara Greg]")
    |> mes("He was originally a Monk,")
    |> mes("but after transcending, he")
    |> mes("somehow became a Stalker.")
    |> mes("Retaining his knowledge of")
    |> mes("the Monk's Root skill, he adapted it for the purposes of the Rogues.")
    |> next()
    |> mes("[Haijara Greg]")
    |> mes("Chae Takbae recorded the")
    |> mes("fundamentals for this new")
    |> mes("Rogue skill in a book that")
    |> mes("I was fortunate enough to")
    |> mes("obtain. But as soon as I got")
    |> mes("it, the blackmailing begain...")
    |> next()
    |> mes("[Haijara Greg]")
    |> mes("There are unscrupulous")
    |> mes("parties that will use any")
    |> mes("means to take the book away")
    |> mes("from me. I can understand, as")
    |> mes("my sons and I have learned new")
    |> mes("skills from Takbae's writings.")
    |> next()
    |> mes("[Haijara Greg]")
    |> mes("However, I am running")
    |> mes("out of time and those men")
    |> mes("will inevitably find me.")
    |> mes("Will you help me save")
    |> mes("myself and my sons?")
    |> next()
  end

  defp recall_legend(ctx) do
    ctx
    |> mes("[Haijara Greg]")
    |> mes("Then you would know the")
    |> mes("value of the skill book he has")
    |> mes("written that I now possess.")
    |> mes("However, I'm hounded by men")
    |> mes("who will do anything to get it.")
    |> mes("Would you please help me?")
    |> next()
  end

  defp punish_greed(ctx) do
    ctx
    |> mes("[Haijara Greg]")
    |> mes("I see. So be it.")
    |> mes("I'll show you the skill")
    |> mes("that you covet so much...")
    |> mes("^FF0000Close Confine^000000!")
    |> specialeffect(:changecold)
    |> specialeffect2(:changewind)
    |> next()
    |> mes("[Haijara Greg]")
    |> mes("Hmpf. Now you are")
    |> mes("helpless, allowing")
    |> mes("me to do this: ^FF0000Back Stab^000000!")
    |> specialeffect2(:comboattack5)
    |> percent_heal(hp: -95, sp: 0)
    |> next()
    |> mes("[Haijara Greg]")
    |> mes("Now get out of here.")
    |> mes("Never show your greedy")
    |> mes("face in front of me again.")
    |> mes("And just be happy that")
    |> mes("I haven't killed you!")
    |> set_char_var(:ROG_SK, 1)
    |> close()
  end

  defp explain_close_confine(ctx) do
    ctx
    |> mes("[Haijara Greg]")
    |> mes("As you must know,")
    |> mes("Close Confine immobilizes")
    |> mes("an enemy that is very close")
    |> mes("to you. However, there are")
    |> mes("a few nuances regarding its")
    |> mes("use on players or monsters.")
    |> next()
    |> mes("[Haijara Greg]")
    |> mes("Now, Close Confine is")
    |> mes("similar to the Monk's skill,")
    |> mes("Root, but it only inhibits the")
    |> mes("enemy's movement, not")
    |> mes("its attack capabilities.")
    |> next()
    |> mes("[Haijara Greg]")
    |> mes("With the exception of")
    |> mes("Back Stab, which we can")
    |> mes("only use once during Close")
    |> mes("Confine's duration, we can")
    |> mes("use any skill during the")
    |> mes("Close Confine status.")
    |> next()
    |> mes("[Haijara Greg]")
    |> mes("Enemies affected by")
    |> mes("Close Confine can escape")
    |> mes("by using Fly Wing, Butterfly")
    |> mes("Wings, or the Teleport or")
    |> mes("Hiding skills. However, only")
    |> mes("Hiding is active during WoE.")
    |> next()
    |> mes("[Haijara Greg]")
    |> mes("Therefore, Close Confine")
    |> mes("can be a very useful skill")
    |> mes("during Guild War sieges, given")
    |> mes("that the target doesn't use the")
    |> mes("the Hiding skill to get away.")
    |> next()
    |> mes("[Haijara Greg]")
    |> mes("With the exception of Boss")
    |> mes("monsters, Close Confine")
    |> mes("will immobilize monsters for")
    |> mes("10 seconds, giving Rogues")
    |> mes("new possibilities when")
    |> mes("hunting in a party.")
    |> next()
    |> mes("[Haijara Greg]")
    |> mes("Well, that's all I can tell")
    |> mes("you about Close Confine.")
    |> mes("I hope that you can learn")
    |> mes("more about this skill through")
    |> mes("practice, and that you become as great a legend as Chae Takbae.")
    |> teach_close_confine()
  end

  defp wish_luck(ctx) do
    ctx
    |> mes("[Haijara Greg]")
    |> mes("All right then...")
    |> mes("I hope that you can")
    |> mes("learn more about Close")
    |> mes("Confine through diligent")
    |> mes("practice. Good luck, and")
    |> mes("thanks again for your help.")
    |> teach_close_confine()
  end

  defp teach_close_confine(ctx) do
    ctx
    |> set_char_var(:ROG_SK, 12)
    |> skill(1005, 1, :permanent)
    |> specialeffect2(:lightsphere)
    |> close()
  end
end
