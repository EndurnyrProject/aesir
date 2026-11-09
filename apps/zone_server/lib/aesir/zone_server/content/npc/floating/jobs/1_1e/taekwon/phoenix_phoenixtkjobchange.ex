defmodule Aesir.ZoneServer.Content.Npc.Floating.Jobs.M11e.Taekwon.PhoenixPhoenixtkjobchange do
  @moduledoc """
  Phoenix, who starts a Novice on the Taekwon Do job change quest.

  ## Behavior

  - Greets Taekwon Do practitioners, and babies, with their own short lines,
    and describes the art to any other class.
  - Takes a Novice's application, requires Job Level 9 to begin training and
    splits on Base Level: at 20 or more the applicant moves straight to the
    spiritual trial (`TK_Q` 2, quest 6001), otherwise the base level is
    remembered in `TAEK_Q` and the first step starts (`TK_Q` 1, quest 6000).
  - On step 1, advances the quest once the applicant has gained the level.
  - On step 2, asks two questions and ends the conversation on either wrong
    answer; passing both moves `TK_Q` to 3 and the quest to 6002.
  - On step 3, accepts a final pledge, changes the job to Taekwon, hands out the
    Guard set and closes the quest.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Tsuyuki
    - Samuray22
    - Kisuka
    - L0ne_W0lf
    - Lemongrass

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script jobs/1-1e/taekwon.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "payon_in01",
        x: 62,
        y: 10,
        dir: 5,
        sprite: 753,
        name: "Phoenix",
        scope: :renewal,
        unique_name: "Phoenix#TKJobChange"
      },
      %{
        map: "payon",
        x: 157,
        y: 141,
        dir: 5,
        sprite: 753,
        name: "Phoenix",
        scope: :pre_renewal,
        unique_name: "Phoenix#TKJobChange"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FClearjobvar
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @guard_set 2101

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    job = Rathena.job_id(class(ctx))
    quest = get_char_var(ctx, :TK_Q, 0)

    cond do
      upper(ctx) == 2 ->
        greet_baby(ctx)

      job == Rathena.job_id(:taekwon) ->
        greet_taekwon(ctx)

      job > Rathena.job_id(:novice) or (job == Rathena.job_id(:novice) and quest == 0) ->
        introduce(ctx)

      true ->
        quest_step(ctx, quest)
    end
  end

  defp greet_baby(ctx) do
    ctx |> mes("[Phoenix]") |> mes("Hello, child.") |> close()
  end

  defp greet_taekwon(ctx) do
    ctx
    |> mes("[Phoenix]")
    |> mes("How is your training")
    |> mes("coming along? As your")
    |> mes("techniques become more")
    |> mes("refined or spectacular,")
    |> mes("never forget that you can")
    |> mes("always rely on the basics.")
    |> close()
  end

  defp introduce(ctx) do
    ctx =
      ctx
      |> mes("[Phoenix]")
      |> mes("This land. Our once")
      |> mes("beautiful world has been")
      |> mes("stained by evil: there are")
      |> mes("too many men corrupted by")
      |> mes("darkness, too many monsters")
      |> mes("threatening the innocent...")
      |> next()
      |> mes("[Phoenix]")
      |> mes("The havoc that reigns in this")
      |> mes("world is too much for normal")
      |> mes("humans, which cannot stand")
      |> mes("up for themselves against such")
      |> mes("overwhelming odds. Still, one")
      |> mes("must aspire to fight the odds.")
      |> next()
      |> mes("[Phoenix]")
      |> mes("And so, I've dedicated")
      |> mes("myself to becoming stronger.")
      |> mes("I have been training to achieve")
      |> mes("enlightenment, developing an art to hone the mind and body that")
      |> mes("I wish to share with the world.")
      |> next()
      |> mes("[Phoenix]")
      |> mes("I may not be able to change")
      |> mes("the world on my own, but I'll")
      |> mes("never stop training myself")
      |> mes("spiritually and physically.")
      |> mes("I know that the answer")
      |> mes("will come in time...")
      |> next()

    if Rathena.job_id(class(ctx)) == Rathena.job_id(:novice) do
      offer_training(ctx)
    else
      ctx
      |> mes("[Phoenix]")
      |> mes("Noble adventurer:")
      |> mes("if you know anyone who")
      |> mes("has not chosen his path")
      |> mes("in life, please recommend")
      |> mes("him to me. If interested,")
      |> mes("I may teach him my art...")
      |> close()
    end
  end

  defp offer_training(ctx) do
    {ctx, answer} =
      ctx
      |> mes("[Phoenix]")
      |> mes("If you have not decided on")
      |> mes("the path you wish to take in")
      |> mes("life, I'd like you to consider")
      |> mes("becoming a practitioner of my")
      |> mes("art. It won't be easy, but it will lead you to great strength...")
      |> next()
      |> select(["Okay, I will join you.", "No, thank you."])

    if answer == 1, do: accept_student(ctx), else: decline_training(ctx)
  end

  defp decline_training(ctx) do
    ctx
    |> mes("[Phoenix]")
    |> mes("I understand. One's life can")
    |> mes("take many paths, but you can")
    |> mes("only choose to travel on one")
    |> mes("at a time. I hope that you work")
    |> mes("towards enlightenment in your")
    |> mes("very own way, adventurer.")
    |> close()
  end

  defp accept_student(ctx) do
    if Rathena.truthy?(can_change_job?(ctx)) do
      ctx
      |> mes("[Phoenix]")
      |> mes("Very well... I accept you")
      |> mes("as my student. In beginning")
      |> mes("training, your physical body")
      |> mes("must first be conditioned in")
      |> mes("order to perform the skills")
      |> mes("that you will be learning.")
      |> next()
      |> continue_training()
    else
      ctx
      |> mes("[Phoenix]")
      |> mes("How unfortunate!")
      |> mes("You're not yet ready to")
      |> mes("begin training under my")
      |> mes("tutelage with your current")
      |> mes("Job Level. Please return when you reach Job Level 9 or higher.")
      |> close()
    end
  end

  defp continue_training(ctx) do
    if base_level(ctx) > 19 do
      ctx
      |> mes("[Phoenix]")
      |> mes("Hm. I see that you have")
      |> mes("undergone sufficient physical")
      |> mes("training as a Novice. Very good. Then let us prepare for your")
      |> mes("spiritual training. Take a deep")
      |> mes("breath, speak to me when ready.")
      |> set_char_var(:TK_Q, 2)
      |> setquest(6001)
      |> close()
    else
      ctx
      |> mes("[Phoenix]")
      |> mes("The mind is not necessarily")
      |> mes("bound to the limits of the body, but you will never fulfill your")
      |> mes("true potential without integrating mind and body. Go, gain ^FF00001 more")
      |> mes("Base Level^000000, and then return.")
      |> next()
      |> set_char_var(:TAEK_Q, base_level(ctx))
      |> set_char_var(:TK_Q, 1)
      |> setquest(6000)
      |> mes("[Phoenix]")
      |> mes("I understand this is not an")
      |> mes("easy task for Novices, but you")
      |> mes("must ready yourself for the")
      |> mes("hardship for this job. I shall")
      |> mes("expect you to be stronger")
      |> mes("the next time we meet.")
      |> close()
    end
  end

  defp quest_step(ctx, 1) do
    if base_level(ctx) > get_char_var(ctx, :TAEK_Q, 0) do
      ctx
      |> set_char_var(:TK_Q, 2)
      |> changequest(6000, 6001)
      |> mes("[Phoenix]")
      |> mes("Good. I sense that you")
      |> mes("are more in tune with your")
      |> mes("inner strength. That is the")
      |> mes("natural result of leveling up.")
      |> mes("We're ready to proceed with")
      |> mes("the next portion of training.")
      |> close()
    else
      ctx
      |> mes("[Phoenix]")
      |> mes("You must gain ^FF00001 more")
      |> mes("Base Level^000000 to prove that")
      |> mes("you can endure the hardship")
      |> mes("that entails this job. Never")
      |> mes("neglect your training.")
      |> close()
    end
  end

  defp quest_step(ctx, 2), do: interview(ctx)
  defp quest_step(ctx, 3), do: final_pledge(ctx)
  defp quest_step(ctx, _step), do: ctx

  defp interview(ctx) do
    ctx
    |> mes("[Phoenix]")
    |> mes("For your spiritual training,")
    |> mes("I will ask you a series of")
    |> mes("questions to test your spirit.")
    |> mes("Relax. Answer as honestly")
    |> mes("as you can. Your will and")
    |> mes("convictions will be tested.")
    |> next()
    |> mes("[Phoenix]")
    |> mes("As a practitioner of my")
    |> mes("art, the ability to quickly")
    |> mes("make the best decision will")
    |> mes("be necessary in battle. Now,")
    |> mes("we will begin the questioning.")
    |> next()
    |> mes("[Phoenix]")
    |> mes("When you encounter")
    |> mes("great difficulty, how do")
    |> mes("you generally respond?")
    |> next()
    |> ask_about_difficulty()
  end

  defp ask_about_difficulty(ctx) do
    {ctx, answer} =
      select(ctx, [
        "I face it head on.",
        "Avoid it somehow.",
        "Regroup and analyze the problem."
      ])

    case answer do
      1 -> ctx |> praise_determination() |> ask_about_conflict()
      2 -> refuse_cowardice(ctx)
      3 -> refuse_regrouping(ctx)
      _ -> ctx
    end
  end

  defp praise_determination(ctx) do
    ctx
    |> mes("[Phoenix]")
    |> mes("Yes, that is the answer")
    |> mes("I wanted. Even if you cannot")
    |> mes("handle a problem at first, we")
    |> mes("can only benefit from such")
    |> mes("strong determination. Don't")
    |> mes("let any obstacle stop you.")
    |> next()
    |> mes("[Phoenix]")
    |> mes("Even if you fail, you")
    |> mes("can only learn from the")
    |> mes("experience when you give")
    |> mes("your all. Half-hearted")
    |> mes("attempts rarely yield")
    |> mes("fruitful results.")
    |> next()
    |> mes("[Phoenix]")
    |> mes("Seeing as you already")
    |> mes("understand the importance")
    |> mes("of one's will, we'll proceed")
    |> mes("to the next question.")
    |> next()
  end

  defp refuse_cowardice(ctx) do
    ctx
    |> mes("[Phoenix]")
    |> mes("Fool! How do you expect")
    |> mes("to mature if you run away")
    |> mes("from challenges? Fear can")
    |> mes("be a healthy reaction that")
    |> mes("can save your life, but true")
    |> mes("cowardice is despicable.")
    |> next()
    |> mes("[Phoenix]")
    |> mes("It disappoints me to")
    |> mes("hear you say that. Never")
    |> mes("say such a thing to me again.")
    |> mes("Hm. Contemplate the meanings")
    |> mes("of courage and cowardice, and")
    |> mes("then speak to me once again.")
    |> close()
  end

  defp refuse_regrouping(ctx) do
    ctx
    |> mes("[Phoenix]")
    |> mes("Regroup? It is good to do that")
    |> mes("after you have been defeated.")
    |> mes("But it is best to face problems")
    |> mes("once you encounter them.")
    |> mes("You will not always have")
    |> mes("the luxury of regrouping.")
    |> next()
    |> mes("[Phoenix]")
    |> mes("Problems can be predicted")
    |> mes("and analyzed, but I think")
    |> mes("immediate retreat is unwise.")
    |> mes("Contemplate on your fears,")
    |> mes("as well as what you define as")
    |> mes("failure. Then, return to me.")
    |> close()
  end

  defp ask_about_conflict(ctx) do
    {ctx, answer} =
      ctx
      |> mes("[Phoenix]")
      |> mes("On your travels, you will")
      |> mes("encounter many people with")
      |> mes("differing backgrounds and")
      |> mes("viewpoints. Inevitably, you")
      |> mes("will encounter someone whose")
      |> mes("way of life you cannot fathom.")
      |> next()
      |> mes("[Phoenix]")
      |> mes("Likewise, this person will")
      |> mes("not understand your way of")
      |> mes("life. When your two viewpoints")
      |> mes("clash, causing heated conflict,")
      |> mes("how would you respond?")
      |> next()
      |> select([
        "Insist that I'm right, regardless",
        "Disregard conflicting viewpoint",
        "Accept differences and learn from them"
      ])

    case answer do
      1 -> insist_on_own_view(ctx)
      2 -> disregard_view(ctx)
      3 -> ctx |> accept_differences() |> satisfied()
      _ -> ctx
    end
  end

  defp insist_on_own_view(ctx) do
    ctx
    |> mes("[Phoenix]")
    |> mes("It's important to have your")
    |> mes("own opinion. However, you")
    |> mes("must recognize that you may")
    |> mes("be wrong, and an opposing")
    |> mes("view may have some merit.")
    |> next()
    |> mes("[Phoenix]")
    |> mes("There is no one right")
    |> mes("answer and the light of")
    |> mes("truth can take many shades.")
    |> mes("Such is the way of nature.")
    |> mes("To force ideas on others is")
    |> mes("an oppressive practice.")
    |> next()
    |> mes("[Phoenix]")
    |> mes("Do not limit yourself")
    |> mes("to a single view, and do")
    |> mes("not stifle your growth by")
    |> mes("adhering to a single truth.")
    |> mes("Contemplate on this, and")
    |> mes("then speak with me again.")
    |> close()
  end

  defp disregard_view(ctx) do
    ctx
    |> mes("[Phoenix]")
    |> mes("It is important to get")
    |> mes("along with others, but")
    |> mes("you will bring no value")
    |> mes("to this world without your")
    |> mes("own unique contributions,")
    |> mes("thoughts and opinions.")
    |> next()
    |> mes("[Phoenix]")
    |> mes("A conflict of ideals, when")
    |> mes("conducted with respect for")
    |> mes("yourself and others, is a")
    |> mes("great opportunity to broaden")
    |> mes("your understanding of the")
    |> mes("world as it is to others.")
    |> next()
    |> mes("[Phoenix]")
    |> mes("Reflect on this idea of")
    |> mes("establishing harmony with")
    |> mes("the self, and harmony with")
    |> mes("others. Then, return to me.")
    |> close()
  end

  defp accept_differences(ctx) do
    ctx
    |> mes("[Phoenix]")
    |> mes("Good. You must see")
    |> mes("differences for what they")
    |> mes("truly are. You must also")
    |> mes("take criticism to your own")
    |> mes("views with grace and ")
    |> mes("sincere consideration.")
    |> next()
    |> mes("[Phoenix]")
    |> mes("It is impossible to know")
    |> mes("everything in this world.")
    |> mes("It is impossible to understand")
    |> mes("every view. But that does not")
    |> mes("mean that views you do not")
    |> mes("understand are meritless.")
    |> next()
    |> mes("[Phoenix]")
    |> mes("The one with whom you")
    |> mes("disagree may have the")
    |> mes("answer you do not know.")
    |> mes("In your time of weakness,")
    |> mes("this person may be your")
    |> mes("greatest help. Remember that.")
    |> next()
  end

  defp satisfied(ctx) do
    ctx
    |> mes("[Phoenix]")
    |> mes("I am satisfied by the")
    |> mes("answers you have given")
    |> mes("me. Please reflect on what")
    |> mes("we have discussed for a little")
    |> mes("while. When your mind is calm,")
    |> mes("come and speak to me.")
    |> set_char_var(:TK_Q, 3)
    |> changequest(6001, 6002)
    |> close()
  end

  defp final_pledge(ctx) do
    {ctx, answer} =
      ctx
      |> mes("[Phoenix]")
      |> mes("Are you feeling calm")
      |> mes("and at peace? I will ask")
      |> mes("you a very important question.")
      |> mes("Give me your honest answer.")
      |> next()
      |> mes("[Phoenix]")
      |> mes("^FF0000Are you ready to dedicate")
      |> mes("yourself to the special art")
      |> mes("I will teach you, and uphold")
      |> mes("the dignity of its philosophy?")
      |> next()
      |> select(["Yes.", "No."])

    if answer == 1, do: become_taekwon(ctx), else: not_ready(ctx)
  end

  defp become_taekwon(ctx) do
    ctx =
      ctx
      |> mes("[Phoenix]")
      |> mes("Very well. You are no")
      |> mes("longer just a student.")
      |> mes("You are now entrusted with")
      |> mes("the powers and responsibilities")
      |> mes("of a disciple of ^FF0000Taekwon Do^000000.")
      |> next()
      |> mes("[Phoenix]")
      |> mes("''Taekwon'' has the meaning")
      |> mes("of ''punching and kicking,''")
      |> mes("and ''Do'' has the meaning")
      |> mes("of ''art.'' This martial art is")
      |> mes("focused on skills using")
      |> mes("the fists and the feet.")
      |> next()
      |> mes("[Phoenix]")
      |> mes("Please use this discipline")
      |> mes("to hone your body and mind")
      |> mes("and learn the skills that are")
      |> mes("best suited to you. Never")
      |> mes("shirk your training, or bring")
      |> mes("shame to Taekwon Do.")
      |> next()

    {ctx, _} =
      ctx
      |> completequest(6002)
      |> jobchange(:taekwon)
      |> FClearjobvar.call([])

    ctx =
      ctx
      |> give_item(@guard_set, 1)
      |> mes("[Phoenix]")
      |> mes("You are still young, so")
      |> mes("I assume you'll want a job")
      |> mes("title. Mm. In that case, you")

    ctx =
      if sex(ctx) == 0 do
        mes(ctx, "are now a ^FF0000Taekwon Girl^000000.")
      else
        mes(ctx, "are now a ^FF0000Taekwon Boy^000000.")
      end

    ctx
    |> mes("Yes, that sounds good. ")
    |> next()
    |> mes("[Phoenix]")
    |> mes("Please, take this training")
    |> mes("uniform and guard set: make")
    |> mes("good use of these gifts. As")
    |> mes("you travel and train, enlighten")
    |> mes("others about our art and learn what you can from them in return.")
    |> next()
    |> mes("[Phoenix]")
    |> mes("It is now time for you to")
    |> mes("embark on your own journey")
    |> mes("to find new challenges to")
    |> mes("develop your strength.")
    |> mes("Carry yourself with pride")
    |> mes("as a Taekwon Do practitioner...")
    |> next()
    |> mes("[Phoenix]")
    |> mes("Very well. I wish you luck.")
    |> mes("I hope to see you again")
    |> mes("sometime, " <> char_name(ctx, 0) <> ".")
    |> close()
  end

  defp not_ready(ctx) do
    ctx
    |> mes("[Phoenix]")
    |> mes("Hm, perhaps you are not")
    |> mes("quite ready to progress from")
    |> mes("your status as a student to")
    |> mes("a full fledged disciple.")
    |> mes("When you feel prepared,")
    |> mes("come and speak to me.")
    |> close()
  end
end
