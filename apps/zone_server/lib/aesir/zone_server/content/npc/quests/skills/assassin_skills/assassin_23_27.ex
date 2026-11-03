defmodule Aesir.ZoneServer.Content.Npc.Quests.Skills.AssassinSkills.Assassin2327 do
  @moduledoc """
  Esmille, an Assassin Guild member in Morroc who teaches the Sonic Acceleration quest skill.

  ## Behavior

  - Assassins sent by Killtin can hear about Sonic Acceleration or ask to learn it; once they know
    Sonic Blow, she assigns a random treasure hunt in the Sphinx coffins, the Sphinx stone
    statues, or the flooded Pyramids crypt.
  - Reminds players of their assigned treasure location until they return with a jewel.
  - Accepts any of three jewels as proof (the jewel is kept), then demonstrates the form and
    teaches Sonic Acceleration; interrupted training resumes from the demonstration.
  - Reteaches the skill to transcended Assassins who have lost it, provided they know Sonic Blow.
  - Points other Assassins to Killtin and asks everyone else to send Assassins her way.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Lupus
    - Reddozen
    - DracoRPG
    - L0ne_W0lf
    - 2Spiritual Kid (bug report)

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "in_moc_16",
        x: 23,
        y: 27,
        dir: 5,
        sprite: 885,
        name: "Assassin",
        scope: :shared,
        unique_name: "Assassin#realgirl"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @sonic_blow 136
  @sonic_acceleration 1003

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    assassin? = Rathena.job_id(base_job(ctx)) == Rathena.job_id(:assassin)
    step = get_char_var(ctx, :ASSN_SK, 0)

    cond do
      assassin? and step == 7 -> reteach_transcended(ctx)
      step == 7 -> wish_luck(ctx)
      step == 6 -> resume_training(ctx)
      step == 5 -> check_treasure(ctx)
      step == 2 or step == 3 or step == 4 -> remind_task(ctx, step)
      step == 1 -> introduce_skill(ctx)
      assassin? -> point_to_killtin(ctx)
      true -> ask_for_assassins(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp reteach_transcended(ctx) do
    if getskilllv(ctx, @sonic_acceleration) == 0 do
      ctx =
        ctx
        |> mes("[Esmille]")
        |> mes("Mm? Ah, you've transcended")
        |> mes("and become an Assassin Cross")
        |> mes("as well. I understand the trouble that you must have gone through")
        |> mes("to be reborn with new strength.")
        |> next()
        |> mes("[Esmille]")
        |> mes("You probably need to learn")
        |> mes("the Sonic Acceleration skill")
        |> mes("again after having lost some")
        |> mes("of your memories. I truly")
        |> mes("sympathize, and am willing")
        |> mes("to teach it to you again.")
        |> next()

      if getskilllv(ctx, @sonic_blow) == 0 do
        learn_sonic_blow_first(ctx)
      else
        ctx
        |> demonstrate_form()
        |> close_to_perfection()
        |> next()
        |> teach_sonic_acceleration()
      end
    else
      wish_luck(ctx)
    end
  end

  defp resume_training(ctx) do
    ctx
    |> mes("[Esmille]")
    |> mes("Please focus on the")
    |> mes("training... If we continue to")
    |> mes("be interrupted, you'll never")
    |> mes("be able to learn anything.")
    |> mes("Now, please listen closely.")
    |> next()
    |> demonstrate_form()
    |> a_little_better()
    |> close_to_perfection()
    |> specialeffect2(:sonicblow)
    |> next()
    |> teach_sonic_acceleration()
  end

  defp check_treasure(ctx) do
    ctx =
      ctx
      |> mes("[Esmille]")
      |> mes("So how is your little")
      |> mes("mission coming along?")
      |> mes("I trust that you've completed")
      |> mes("that task I assigned for you.")
      |> next()

    if count_item(ctx, 726) > 0 or count_item(ctx, 723) > 0 or count_item(ctx, 720) > 0 do
      {ctx, _} = select(ctx, ["How's this for treasure?"])

      ctx
      |> mes("[Esmille]")
      |> mes("Oh, that jewel...!")
      |> mes("It's so captivating~")
      |> mes("I haven't seen anything")
      |> mes("so beautiful in such a long")
      |> mes("time. You've done very well...")
      |> next()
      |> mes("[Esmille]")
      |> mes("That jewel is yours")
      |> mes("to keep. In truth, I don't")
      |> mes("really need any treasure, just some proof of your qualification.")
      |> mes("It looks like you're ready for me to teach you Sonic Acceleration.")
      |> set_char_var(:ASSN_SK, 6)
      |> next()
      |> demonstrate_form()
      |> a_little_better()
      |> teach_sonic_acceleration()
    else
      ctx |> mes("[Esmille]") |> mes("Hmmm...") |> close()
    end
  end

  defp remind_task(ctx, step) do
    ctx
    |> mes("[Esmille]")
    |> mes("So how is your little")
    |> mes("mission coming along?")
    |> mes("If you've forgotten the")
    |> mes("location I've asked you to")
    |> mes("search for treasure, then")
    |> mes("I can briefly remind you.")
    |> next()
    |> mes("[Esmille]")
    |> mes("Find something valuable")
    |> task_location(step)
    |> mes("Only the strong can explore")
    |> mes("that area, so doing this will")
    |> mes("prove your competency to me.")
    |> close()
  end

  defp task_location(ctx, 2) do
    ctx
    |> mes("for me by searching the")
    |> mes("^FF0000Coffins^000000 in the Sphinx.")
  end

  defp task_location(ctx, 3) do
    ctx
    |> mes("for me by searching the")
    |> mes("^FF0000Stone Statues^000000 in the Sphinx.")
  end

  defp task_location(ctx, 4) do
    ctx
    |> mes("in the ^FF0000flooded crypt in the")
    |> mes("bottom floor^000000 of the Pyramids.")
  end

  defp introduce_skill(ctx) do
    ctx
    |> mes("[Esmille]")
    |> mes("Ah. Hello, comrade.")
    |> mes("Have you heard about")
    |> mes("the latest news from")
    |> mes("the Assassin Guild?")
    |> mes("Ah, you've spoken to")
    |> mes("Killtin. Good, good...")
    |> next()
    |> mes("[Esmille]")
    |> mes("Now, I've been charged")
    |> mes("with the responsibility of")
    |> mes("teaching the Sonic Acceleration skill to all interested Assassins.")
    |> mes("I can tell you more about it if")
    |> mes("Killtin didn't fully explain.")
    |> next()
    |> skill_menu()
  end

  defp skill_menu(ctx) do
    {ctx, choice} =
      select(ctx, ["Please tell me more...", "I want to learn Sonic Acceleration!"])

    case choice do
      1 -> ctx |> explain_skill() |> skill_menu()
      2 -> request_training(ctx)
      _ -> skill_menu(ctx)
    end
  end

  defp explain_skill(ctx) do
    ctx
    |> mes("[Esmille]")
    |> mes("Sonic Acceleration is")
    |> mes("a ^FF0000support skill used in")
    |> mes("conjunction with Sonic Blow^000000.")
    |> mes("Assassins can only cast this")
    |> mes("skill on themselves for their")
    |> mes("own personal benefit.")
    |> next()
    |> mes("[Esmille]")
    |> mes("If you're familiar with")
    |> mes("Sonic Blow, you'll know")
    |> mes("that it's difficult to inflict")
    |> mes("fatal damage with that skill.")
    |> mes("It's far too fast to be able")
    |> mes("to attack very accurately...")
    |> next()
    |> mes("[Esmille]")
    |> mes("However, by learning")
    |> mes("Sonic Acceleration, you")
    |> mes("can overcome this accuracy")
    |> mes("drawback and fulfill the full")
    |> mes("damage potential of the")
    |> mes("Sonic Blow skill.")
    |> next()
    |> mes("[Esmille]")
    |> mes("This skill is truly great.")
    |> mes("And our guildmaster,")
    |> mes("the one who invented this")
    |> mes("skill, is also... He's a man")
    |> mes("amongst men, I must say.")
    |> emotion(:throb)
    |> next()
  end

  defp request_training(ctx) do
    ctx =
      ctx
      |> mes("[Esmille]")
      |> mes("Ah, I'm glad to see")
      |> mes("that you're so enthusiastic")
      |> mes("about learning this skill.")
      |> mes("But first, there we need to")
      |> mes("take care of the prerequisites...")
      |> next()

    if getskilllv(ctx, @sonic_blow) == 0 do
      learn_sonic_blow_first(ctx)
    else
      ctx
      |> mes("[Esmille]")
      |> mes("Your task will be to bring")
      |> assign_treasure_task()
    end
  end

  defp assign_treasure_task(ctx) do
    case Enum.random(1..3) do
      1 ->
        ctx
        |> mes("treasure from the Sphinx.")
        |> mes("Search the ^FF0000Coffins^000000 that")
        |> mes("are there for precious")
        |> mes("valuables. Consider this")
        |> mes("a test of your strength.")
        |> start_task(2)

      2 ->
        ctx
        |> mes("treasure from the Sphinx.")
        |> mes("Search the ^FF0000Stone Statues^000000")
        |> mes("there for precious valuables.")
        |> mes("Consider this excursion as")
        |> mes("a test of your strength.")
        |> start_task(3)

      3 ->
        ctx
        |> mes("treasure from the Pyramids.")
        |> mes("Search the ^FF0000flooded crypt at")
        |> mes("the bottom floor for precious")
        |> mes("valuables^000000. Consider this as")
        |> mes("a test of your strength.")
        |> start_task(4)

      _ ->
        skill_menu(ctx)
    end
  end

  defp start_task(ctx, step) do
    ctx
    |> set_char_var(:ASSN_SK, step)
    |> next()
    |> mes("[Esmille]")
    |> mes("Whether you can complete")
    |> mes("this task will determine")
    |> mes("if you are worthy enough")
    |> mes("for me to teach you the")
    |> mes("Sonic Acceleration skill.")
    |> mes("Best of luck, and please hurry.")
    |> close()
  end

  defp point_to_killtin(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Assassin]")
      |> mes("Ah. Hello, comrade.")
      |> mes("Have you heard about")
      |> mes("the latest news from")
      |> mes("the Assassin Guild?")
      |> emotion(:smile)
      |> next()
      |> select(["News from the Assassin Guild?"])

    ctx
    |> mes("[Assassin]")
    |> mes("Hm. You must not have")
    |> mes("heard it, then. If you want")
    |> mes("to know more about it, you")
    |> mes("should speak to Killtin, who")
    |> mes("is right next to me. He will")
    |> mes("explain everything clearly.")
    |> close()
  end

  defp ask_for_assassins(ctx) do
    ctx
    |> mes("[Assassin]")
    |> mes("Hm. Do you know any")
    |> mes("Assassins? Tell them")
    |> mes("to come here if they")
    |> mes("haven't already.")
    |> close()
  end

  defp learn_sonic_blow_first(ctx) do
    ctx
    |> mes("[Esmille]")
    |> mes("First, go and learn the")
    |> mes("Sonic Blow skill. The skill")
    |> mes("I will teach you is completely")
    |> mes("useless unless you learn how")
    |> mes("to perform a Sonic Blow. I shall be waiting right here till then.")
    |> close()
  end

  defp wish_luck(ctx) do
    ctx
    |> mes("[Esmille]")
    |> mes("I trust that using")
    |> mes("Sonic Acceleration in")
    |> mes("battle has given you an")
    |> mes("edge over the enemy. Bring")
    |> mes("swift defeat to your foes for")
    |> mes("the Assassin Guild's honor.")
    |> close()
  end

  defp demonstrate_form(ctx) do
    ctx
    |> mes("[Esmille]")
    |> mes("Now, right before you")
    |> mes("perform Sonic Blow, make")
    |> mes("sure your feet are positioned")
    |> mes("like this. Then, as smoothly")
    |> mes("and quickly as possible, shift")
    |> mes("your weight over to this side.")
    |> specialeffect(:sonicblow)
    |> next()
    |> mes("[Esmille]")
    |> mes("Watch carefully, this")
    |> mes("is the most important")
    |> mes("part. See where my hands")
    |> mes("are and the angle of my")
    |> mes("arms? This is the form that")
    |> mes("you've got to memorize.")
    |> specialeffect(:sonicblow)
    |> next()
    |> mes("[Esmille]")
    |> mes("Alright, that's all")
    |> mes("you need to know. Now,")
    |> mes("please try it so I can give")
    |> mes("you feedback on your form.")
    |> next()
    |> specialeffect2(:sonicblow)
    |> next()
    |> mes("[Esmille]")
    |> mes("Hmm, you're shifting")
    |> mes("your weight kind of")
    |> mes("unsteadily. It might")
    |> mes("help if your center of")
    |> mes("gravity was like this...")
    |> next()
    |> specialeffect2(:sonicblow)
    |> next()
  end

  defp a_little_better(ctx) do
    ctx
    |> mes("[Esmille]")
    |> mes("That's a little better.")
    |> mes("Hmmm. Try to think of")
    |> mes("the enemy's weak point")
    |> mes("and follow through with")
    |> mes("the stabbing motion.")
    |> next()
    |> specialeffect2(:sonicblow)
    |> next()
  end

  defp close_to_perfection(ctx) do
    ctx
    |> mes("[Esmille]")
    |> mes("Ah, you're so very")
    |> mes("close to perfection.")
    |> mes("Focus more on smoothly")
    |> mes("transitioning from your")
    |> mes("stance to executed action.")
  end

  defp teach_sonic_acceleration(ctx) do
    ctx =
      ctx
      |> mes("[Esmille]")
      |> mes("Yes, that's it...!")
      |> mes("Very well executed.")

    ctx
    |> mes("Good work, #{char_name(ctx, 0)}.")
    |> skill(@sonic_acceleration, 1, :permanent)
    |> set_char_var(:ASSN_SK, 7)
    |> next()
    |> mes("[Esmille]")
    |> mes("Do you understand now?")
    |> mes("You should have no problem")
    |> mes("remembering this skill now.")
    |> mes("I can teach you nothing more,")
    |> mes("so all I can do now is wish")
    |> mes("you luck on your journeys.")
    |> close()
  end
end
