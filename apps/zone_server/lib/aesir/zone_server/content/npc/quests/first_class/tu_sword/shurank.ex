defmodule Aesir.ZoneServer.Content.Npc.Quests.FirstClass.TuSword.Shurank do
  @moduledoc """
  Shurank, the Prontera Chivalry Knight who tutors new Swordmen through the Swordman training quest.

  ## Behavior

  - Novices are encouraged to become Swordmen; advanced Swordman classes and other jobs only
    get small talk.
  - Teaches Bash, Increase HP Recovery, Provoke, Endure, the Sword Masteries and Magnum Break
    in turn, checking the player's skill levels: each lesson advances the quest step, and
    higher skill levels skip ahead with experience rewards.
  - Mastering Bash earns a Muffler; finishing the Magnum Break lecture ends the quest with a
    Scimiter (plus experience when Magnum Break is above level 5).
  - Sends the player to Dequ'ee in Geffen with a message, later warping them there, and again
    to help Dequ'ee with his murder investigation.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Jukka (fix up)
    - Lupus
    - SinSloth
    - L0ne_W0lf
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "izlude_in", x: 82, y: 163, dir: 3, sprite: 733, name: "Shurank", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @speaker "[Shurank]"
  # The reference script misspells the speaker in the two Endure lectures; kept verbatim.
  @misspelled_speaker "[Shunrank]"

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = mes(ctx, "[Shurank]")

    cond do
      Rathena.job_id(class(ctx)) == Rathena.job_id(:novice) or
          Rathena.job_id(class(ctx)) == Rathena.job_id(:baby) ->
        encourage_novice(ctx)

      Rathena.job_id(base_class(ctx)) == Rathena.job_id(:swordman) and
          Rathena.truthy?(
            :erlang.band(eaclass(ctx), :erlang.bor(:erlang.bor(768, 1_048_576), 4096))
          ) ->
        greet_veteran(ctx)

      Rathena.job_id(base_class(ctx)) != Rathena.job_id(:swordman) ->
        greet_other_class(ctx)

      true ->
        lesson(ctx, get_char_var(ctx, :tu_swordman, 0))
    end
  end

  defp encourage_novice(ctx) do
    ctx
    |> mes("Still wondering")
    |> mes("what to do with")
    |> mes("your future, eh?")
    |> next()
    |> mes("[Shurank]")
    |> mes("If I may be so bold,")
    |> mes("I suggest that you follow")
    |> mes("the path of strength.")
    |> mes("Become... A Swordman.")
    |> next()
    |> mes("[Shurank]")
    |> mes(
      "If you wish to stake your life on the way of the sword, speak to the Swordman Association representative to the left."
    )
    |> next()
    |> mes("[Shurank]")
    |> mes("Whatever you do,")
    |> mes(
      "I hope that you live out your life without any regrets. And if you do happen to become a Swordman,"
    )
    |> mes("come back to me...")
    |> close()
  end

  defp greet_veteran(ctx) do
    ctx = ctx |> mes("From your raiment,") |> mes("I see that you are")

    ctx =
      if sex(ctx) == get_char_var(ctx, :SEX_MALE, 0) do
        mes(ctx, "a man of the sword.")
      else
        mes(ctx, "a woman of the sword.")
      end

    ctx
    |> mes("Your eyes tell me that")
    |> mes("you've seen many a battle.")
    |> next()
    |> mes("[Shurank]")
    |> mes(
      "There's nothing that I can actually offer to teach you. But if you know any new Swordmen that show potential, please direct them to me."
    )
    |> close()
  end

  defp greet_other_class(ctx) do
    ctx
    |> mes("Greetings adventurer.")
    |> mes("If you happen to know")
    |> mes("any new Swordmen,")
    |> mes("please direct them to me.")
    |> next()
    |> mes("[Shurank]")
    |> mes(
      "My specialty happens to be teaching the fundamentals of the Swordman job to green recruits that have just made the job change."
    )
    |> next()
    |> mes("[Shurank]")
    |> mes("Although it would be great if everyone can wield a sword,")
    |> mes(
      "I'm afraid there's nothing I can effectively teach to you. The methods of your job are..."
    )
    |> mes("Foreign to me.")
    |> close()
  end

  defp lesson(ctx, 23), do: nothing_left_to_teach(ctx)
  defp lesson(ctx, 22), do: magnum_break_lecture(ctx)
  defp lesson(ctx, 21), do: sword_mastery_lecture(ctx)
  defp lesson(ctx, 13), do: remind_dequee_visit(ctx)
  defp lesson(ctx, 12), do: endure_training_check(ctx)
  defp lesson(ctx, 11), do: endure_learned_check(ctx)
  defp lesson(ctx, 10), do: endure_lecture(ctx)
  defp lesson(ctx, 9), do: provoke_progress_check(ctx)
  defp lesson(ctx, 8), do: provoke_training_check(ctx)
  defp lesson(ctx, 7), do: provoke_lecture(ctx)
  defp lesson(ctx, 6), do: send_to_geffen(ctx)
  defp lesson(ctx, 5), do: message_errand(ctx)
  defp lesson(ctx, 4), do: hp_recovery_lecture(ctx)
  defp lesson(ctx, 3), do: bash_mastery_check(ctx)
  defp lesson(ctx, 2), do: bash_training_check(ctx)
  defp lesson(ctx, 1), do: bash_progress_check(ctx)
  defp lesson(ctx, 0), do: introduce_bash(ctx)
  defp lesson(ctx, _step), do: idle_reply(ctx)

  defp idle_reply(ctx), do: ctx |> mes("...") |> mes("......") |> close()

  defp nothing_left_to_teach(ctx) do
    ctx
    |> mes("Greetings, my friend.")
    |> mes("There is nothing more")
    |> mes("that I can teach you...")
    |> next()
    |> mes("[Shurank]")
    |> mes("To improve your skills,")
    |> mes(
      "you must explore this vast world and experience all sorts of battle situations. And always commit yourself to your training."
    )
    |> close()
  end

  defp magnum_break_lecture(ctx) do
    {ctx, magnum} =
      ctx
      |> mes("This will be my")
      |> mes("final lecture to you.")
      |> mes("Please listen carefully")
      |> mes("as I tell you all about")
      |> mes("Magnum Break.")
      |> next()
      |> mes("[Shurank]")
      |> mes(
        "Magnum Break, mastered at Skill Level 10, requires ^5D478BLevel 5 Bash^000000. When used, this skill inflicts splash damage to enemies surrounding the caster."
      )
      |> next()
      |> mes("[Shurank]")
      |> mes("Enemies struck by Magnum Break")
      |> mes(
        "will be pushed back by a Fire property attack. Afterwards, your weapon will temporarily inflict 20% more damage with Fire property attacks."
      )
      |> next()
      |> mes("[Shurank]")
      |> mes("Magnum Break is ideal for use")
      |> mes(
        "when surrounded by foes, but also keep in mind that it also inflicts a little damage on its caster."
      )
      |> next()
      |> check_skill(:chk_magnum, 7)

    if magnum > 5 do
      ctx
      |> mes("[Shurank]")
      |> mes(
        "I see that you've been training in the use of Magnum Break. Although it is an awesome skill, it's not for every Swordman. Still, there's no harm in learning it."
      )
      |> next()
      |> mes("[Shurank]")
      |> mes("Here is a humble reward for")
      |> mes("your great efforts. But do not let your talents allow you to grow arrogant!")
      |> set_char_var(:tu_swordman, 23)
      |> completequest(8228)
      |> give_exp(186, 1860)
      |> give_item(1113, 1)
      |> next()
      |> final_words_opening()
      |> mes(
        "that murderer, it's no longer in our hands. At this time, there's nothing that we can effectively"
      )
      |> mes("do about it.")
      |> final_words_closing()
      |> close()
    else
      ctx
      |> final_words_opening()
      |> mes(
        "that murderer, it's no longer in our hands. At this time, there's nothing that we can effectively do about it."
      )
      |> final_words_closing()
      |> next()
      |> mes("[Shurank]")
      |> mes("Before you go, please take this.")
      |> mes(
        "I hope that you make good use of it as you train to become stronger and stronger. Good luck out there."
      )
      |> set_char_var(:tu_swordman, 23)
      |> completequest(8228)
      |> give_item(1113, 1)
      |> close()
    end
  end

  defp final_words_opening(ctx) do
    ctx
    |> mes("[Shurank]")
    |> mes(
      "That is all I have to teach you about Swordman skills. Hopefully, I've been able to clear up anything you haven't understood about your job and skills."
    )
    |> next()
    |> mes("[Shurank]")
    |> mes("As for the matter concerning")
  end

  defp final_words_closing(ctx) do
    ctx
    |> next()
    |> mes("[Shurank]")
    |> mes("However, I'd like")
    |> mes("to ask that you keep the")
    |> mes("information you've learned")
    |> mes("to yourself. This matter is considered highly classified...")
    |> next()
    |> mes("[Shurank]")
    |> mes(
      "In any case, there's no need to worry about it anymore. But if we ever need assistance, I'll remember to ask you for your help."
    )
    |> next()
    |> mes("[Shurank]")
    |> mes(
      "You've done very well. Continue training and if you reach ^5D478BJob Level 40^000000, you can be promoted to a Knight or a Crusader."
    )
    |> next()
    |> mes("[Shurank]")
    |> mes("Well...")
    |> mes(
      "We Swordmen typically aren't prone to being sentimental, but I'm glad to have met you. Do your best and become a splendid Swordman."
    )
  end

  defp sword_mastery_lecture(ctx) do
    ctx =
      ctx
      |> mes("Ah, you've returned. I've just received a communique from")
      |> mes(
        "Dequ'ee. It seems you've been working very hard and that you've made the most of this experience."
      )
      |> next()
      |> mes("[Shurank]")
      |> mes(
        "For now, I believe you'll benefit from learning some more about Swordman skills. First, let me tell you more about the Sword Masteries."
      )
      |> next()
      |> mes("[Shurank]")
      |> mes("There are two different kinds:")
      |> mes("^5D478BOne Handed Sword Mastery^000000 and")
      |> mes("^5D478BTwo Handed Sword Mastery^000000. Both")
      |> mes("are Passive Skills that increase your Attack Power as these skills are leveled up.")
      |> next()
      |> mes("[Shurank]")
      |> mes("One Handed Sword Mastery")
      |> mes(
        "increases the damage of Daggers and One Handed Swords while Two Handed Sword Mastery increases the damage of Two Handed Swords."
      )
      |> next()

    {ctx, one_handed} = check_skill(ctx, :chk_hanson, 2)
    {ctx, two_handed} = check_skill(ctx, :chk_yangson, 3)

    if one_handed > 9 or two_handed > 9 do
      ctx
      |> mes("[Shurank]")
      |> mes(
        "Ah, from the way you handle your Sword, I see that you have mastered a Sword Mastery. I'm thoroughly impressed."
      )
      |> next()
      |> mes("[Shurank]")
      |> mes("Let me give you")
      |> mes("this small reward")
      |> mes("in recognition of")
      |> mes("your accomplishment.")
      |> set_char_var(:tu_swordman, 22)
      |> changequest(8227, 8228)
      |> give_exp(186, 1860)
      |> next()
      |> magnum_break_preview()
      |> close()
    else
      ctx
      |> magnum_break_preview()
      |> set_char_var(:tu_swordman, 22)
      |> close()
    end
  end

  defp magnum_break_preview(ctx) do
    ctx
    |> mes("[Shurank]")
    |> mes("Next time, I will tell you more about the Magnum Break skill.")
    |> mes("I'll be here when you're ready to learn more.")
  end

  defp remind_dequee_visit(ctx) do
    ctx
    |> mes(
      "You should leave as soon as possible to meet Dequ'ee in Geffen. You do remember where to find him, don't you?"
    )
    |> close()
  end

  defp endure_training_check(ctx) do
    {ctx, endure} =
      ctx
      |> mes("So how has your")
      |> mes("training for the Endure")
      |> mes("skill coming along?")
      |> next()
      |> check_skill(:chk_endure, 8)

    if endure > 1 do
      endure_mastered(ctx)
    else
      ctx
      |> mes("[Shurank]")
      |> mes("Hmm...")
      |> mes("You're not quite")
      |> mes("there yet. In the")
      |> mes("meantime, I encourage")
      |> mes("you to double your efforts!")
      |> close()
    end
  end

  defp endure_learned_check(ctx) do
    {ctx, endure} =
      ctx
      |> mes("So have you")
      |> mes("learned how to use")
      |> mes("the Endure skill yet?")
      |> next()
      |> check_skill(:chk_endure, 8)

    cond do
      endure > 0 and endure < 2 ->
        ctx
        |> review_endure(@misspelled_speaker)
        |> erasequest(8221)
        |> setquest(8222)
        |> set_char_var(:tu_swordman, 13)
        |> dequee_errand()

      endure > 1 ->
        endure_mastered(ctx)

      true ->
        ctx
        |> mes("[Shurank]")
        |> mes("No...?")
        |> mes(
          "I recommend that you learn it as soon as you can. Endure is an invaluable skill for any Swordman to have!"
        )
        |> close()
    end
  end

  defp endure_lecture(ctx) do
    {ctx, endure} =
      ctx
      |> mes("The time has come")
      |> mes("for me to tell you")
      |> mes("all I know about")
      |> mes("the Endure skill.")
      |> next()
      |> check_skill(:chk_endure, 8)

    cond do
      endure == 0 ->
        ctx
        |> explain_endure(@misspelled_speaker)
        |> mes("[Shurank]")
        |> mes(
          "Alright. Now I want you to train in the use of the Endure skill. You can become a great Swordman"
        )
        |> mes("if you can endure attacks")
        |> mes("from your enemies!")
        |> set_char_var(:tu_swordman, 11)
        |> changequest(8220, 8221)
        |> close()

      endure > 0 and endure < 2 ->
        ctx
        |> review_endure(@speaker)
        |> set_char_var(:tu_swordman, 13)
        |> erasequest(8221)
        |> setquest(8222)
        |> dequee_errand()

      endure > 1 ->
        ctx
        |> mes("[Shurank]")
        |> mes(
          "Hm. But judging from the gleen of toughness on your skin, I suppose teaching you about Endure would be a waste of your time. Well done!"
        )
        |> set_char_var(:tu_swordman, 13)
        |> erasequest(8221)
        |> setquest(8222)
        |> give_exp(126, 1260)
        |> dequee_errand()

      true ->
        provoke_progress_check(ctx)
    end
  end

  defp review_endure(ctx, speaker) do
    ctx
    |> mes("[Shurank]")
    |> mes("I see that you")
    |> mes("know how to use the")
    |> mes(
      "Endure skill. Still, it wouldn't hurt if I review the basic details regarding its use..."
    )
    |> next()
    |> explain_endure(speaker)
    |> mes("[Shurank]")
    |> mes(
      "Since you've learned the Endure skill already, I don't think I need to explain it any further. You've done well."
    )
  end

  defp explain_endure(ctx, speaker) do
    ctx
    |> mes("[Shurank]")
    |> mes(
      "As you've noticed, receiving any damage causes you to reel in pain, stunning you for an instant. Thus, rapidly attacking enemies are dangerous since it's difficult to counter or escape them."
    )
    |> next()
    |> mes(speaker)
    |> mes(
      "Activating Endure enables you to shrug off attacks. You'll receive damage, but enemy attacks will not impede you as much. This means you can counter enemy attacks or escape if you need to."
    )
    |> next()
    |> mes("[Shurank]")
    |> mes(
      "Of course, you can't use Endure forever. However, the more you increase the level of the Endure"
    )
    |> mes(
      "skill, the longer Endure's effect will last. Also, remember that Endure also has a skill delay."
    )
    |> next()
  end

  defp endure_mastered(ctx) do
    ctx
    |> mes("[Shurank]")
    |> mes(
      "From that gleen of toughness upon your skin, I see now that I was foolish to ask. Well done~"
    )
    |> set_char_var(:tu_swordman, 13)
    |> erasequest(8221)
    |> setquest(8222)
    |> give_exp(126, 1260)
    |> dequee_errand()
  end

  defp dequee_errand(ctx) do
    ctx
    |> next()
    |> mes("[Shurank]")
    |> mes("Ah, once again, I have")
    |> mes(
      "another task for you to perform. Please visit Dequ'ee in Geffen since it seems he has something"
    )
    |> mes("to ask of you.")
    |> next()
    |> mes("[Shurank]")
    |> mes(
      "Hurry and meet with Dequ'ee and return to me when you complete whatever it is that he wishes for you to do."
    )
    |> close()
  end

  defp provoke_progress_check(ctx) do
    {ctx, provoke} =
      ctx
      |> mes("So have you been")
      |> mes("learning more about")
      |> mes("the use of the Provoke skill?")
      |> next()
      |> check_skill(:chk_provoke, 6)

    cond do
      provoke > 4 and provoke < 10 ->
        ctx
        |> praise_provoke_progress()
        |> set_char_var(:tu_swordman, 10)
        |> give_exp(112, 1120)
        |> endure_preview()

      provoke == 10 ->
        ctx
        |> praise_provoke_mastery()
        |> set_char_var(:tu_swordman, 10)
        |> give_exp(126, 1260)
        |> endure_preview()

      true ->
        ctx
        |> mes("[Shurank]")
        |> mes("Hmm, I acknowledge")
        |> mes(
          "your progress, but you're not quite there yet. You've got to become more skilled in Provoke before"
        )
        |> mes("I can continue my lectures.")
        |> close()
    end
  end

  defp provoke_training_check(ctx) do
    {ctx, provoke} =
      ctx
      |> mes("Ah, you've returned.")
      |> mes("So how has your training")
      |> mes("in the use of the Provoke")
      |> mes("skill been progressing?")
      |> next()
      |> check_skill(:chk_provoke, 6)

    cond do
      provoke > 0 and provoke < 5 ->
        ctx
        |> mes("[Shurank]")
        |> mes("Ah, now I can see that you")
        |> mes(
          "know how to use it. That's a vast improvement over not being able to use it at all. Let me refesh you on Provoke's details."
        )
        |> next()
        |> explain_provoke()
        |> mes("[Shurank]")
        |> mes(
          "Alright, come back to me when you become sufficiently skilled in the use of Provoke. In the meantime, keep training."
        )
        |> set_char_var(:tu_swordman, 9)
        |> close()

      provoke > 4 and provoke < 10 ->
        ctx
        |> praise_provoke_progress()
        |> set_char_var(:tu_swordman, 10)
        |> give_exp(112, 1120)
        |> endure_preview()

      provoke == 10 ->
        ctx
        |> praise_provoke_mastery()
        |> set_char_var(:tu_swordman, 10)
        |> give_exp(126, 1260)
        |> next()
        |> mes(
          "Next time we speak, I will tell you what I know about the ^5D478BEndure^000000 skill. When you're ready to learn, come back to me."
        )
        |> close()

      true ->
        ctx
        |> mes("[Shurank]")
        |> mes(
          "Still haven't learned Provoke, eh? As a Swordman, I believe that it's important that you at least be able to use Provoke!"
        )
        |> close()
    end
  end

  defp provoke_lecture(ctx) do
    {ctx, provoke} =
      ctx
      |> mes("Ah, you've returned. For a new Swordman, you are doing quite")
      |> mes("well. So what is the message")
      |> mes("from Dequ'ee?")
      |> next()
      |> mes("[Shurank]")
      |> mes("I see...")
      |> mes("Well, now that we taken care")
      |> mes(
        "of that, let me continue your instruction on Swordman skills. This time, we'll cover Provoke."
      )
      |> next()
      |> check_skill(:chk_provoke, 6)

    cond do
      provoke == 0 ->
        ctx
        |> mes("[Shurank]")
        |> mes("You haven't")
        |> mes("learned Provoke yet?")
        |> mes("Hm. All the more reason why")
        |> mes("I should explain it to you then.")
        |> next()
        |> explain_provoke()
        |> ask_provoke_training()
        |> set_char_var(:tu_swordman, 8)
        |> changequest(8217, 8218)
        |> close()

      provoke > 0 and provoke < 5 ->
        ctx
        |> mes("[Shurank]")
        |> mes(
          "Hm. You seem to have a basic understanding of Provoke, but let me give you a few details so that you can better understand the use of that skill."
        )
        |> next()
        |> explain_provoke()
        |> ask_provoke_training()
        |> set_char_var(:tu_swordman, 9)
        |> changequest(8218, 8219)
        |> close()

      provoke > 4 and provoke < 10 ->
        ctx
        |> praise_provoke_progress()
        |> set_char_var(:tu_swordman, 10)
        |> changequest(8219, 8220)
        |> give_exp(112, 1120)
        |> endure_preview()

      provoke == 10 ->
        ctx
        |> praise_provoke_mastery()
        |> set_char_var(:tu_swordman, 10)
        |> completequest(8218)
        |> completequest(8219)
        |> completequest(8220)
        |> setquest(8221)
        |> give_exp(126, 1260)
        |> endure_preview()

      true ->
        send_to_geffen(ctx)
    end
  end

  defp explain_provoke(ctx) do
    ctx
    |> mes("[Shurank]")
    |> mes("In order to effectively use Provoke, you must understand")
    |> mes("how it works: Provoke infuriates your opponents, making them")
    |> mes("want to attack you.")
    |> next()
    |> mes("[Shurank]")
    |> mes(
      "When provoked, an enemy will have greater attack strength, making it more dangerous, but will also have reduced defense, making your enemy easier to defeat."
    )
    |> next()
    |> mes("[Shurank]")
    |> mes(
      "Ideally, you may wish to use Provoke on enemies when they are weakened enough so that you can finish them off more quickly. But that's up to you."
    )
    |> next()
    |> mes("[Shurank]")
    |> mes(
      "Also, the higher the level of Provoke that is used, the higher the attack increase and defense decrease of your target."
    )
    |> next()
    |> mes("[Shurank]")
    |> mes(
      "As an Active Skill, Provoke will consume a small amount of SP, just like Bash. So be careful not to run out of SP when using this skill."
    )
    |> next()
  end

  defp ask_provoke_training(ctx) do
    ctx
    |> mes("[Shurank]")
    |> mes("Now I ask that you train yourself in the use of Provoke. Come back")
    |> mes("to me when you have a sufficient understanding of the use of the Provoke skill.")
  end

  defp praise_provoke_progress(ctx) do
    ctx
    |> mes("[Shurank]")
    |> mes(
      "Ah, I see that you have a fairly good understanding of the Provoke skill. Let me reward you in this small way for your efforts."
    )
  end

  defp praise_provoke_mastery(ctx) do
    ctx
    |> mes("[Shurank]")
    |> mes("Y-you've mastered")
    |> mes("Provoke? Impressive!")
    |> mes("I see that you've made")
    |> mes("up your mind to become")
    |> mes("an outstanding Swordman.")
    |> mes("Here is a small reward...")
  end

  defp endure_preview(ctx) do
    ctx
    |> next()
    |> mes("[Shurank]")
    |> mes(
      "Next time we speak, I will tell you what I know about the ^5D478BEndure^000000 skill. When you're ready to learn, come back to me."
    )
    |> close()
  end

  defp send_to_geffen(ctx) do
    ctx
    |> relay_message()
    |> mes("[Shurank]")
    |> mes(
      "But now that I think about it, it may take you a while to travel to Geffen. I shall send you there myself! Good luck!"
    )
    |> next()
    |> warp("gef_fild07", 35, 192)
    |> close()
  end

  defp message_errand(ctx) do
    ctx
    |> mes(
      "Ah, you've returned. I know I said that I would teach you what I know about the Provoke skill, but..."
    )
    |> next()
    |> mes("[Shurank]")
    |> mes(
      "I actually have an important task that I'd like for you to perform. It's not very difficult: All you must do is deliver a message."
    )
    |> next()
    |> mes("[Shurank]")
    |> relay_message()
    |> mes("[Shurank]")
    |> mes("Although there's a Warp service,")
    |> mes(
      "I recommend traveling by foot. You cannot grow strong without testing your strength and practicing your skills!"
    )
    |> set_char_var(:tu_swordman, 6)
    |> changequest(8215, 8216)
    |> close()
  end

  defp relay_message(ctx) do
    ctx
    |> mes(
      "I wish for you to find a Knight named ^5D478BDequ'ee^000000 in ^5D478BGeffen^000000. Listen carefully, this is the message"
    )
    |> mes("I want you to give him.")
    |> next()
    |> mes("[Shurank]")
    |> mes("^0000FFWhat happened")
    |> mes("to the murderer?^000000")
    |> mes(
      "^0000FFDid you find out who he is? If you did, what are we supposed to do now?^000000"
    )
    |> next()
    |> mes("[Shurank]")
    |> mes("If you use those exact words, Dequ'ee will understand what")
    |> mes("you're talking about. Remember his response and let me know his answer.")
    |> next()
    |> mes("[Shurank]")
    |> mes(
      "It shouldn't be too hard fighting the monsters on the way to Geffen, but if you encounter any that are too strong, there's no shame in running away."
    )
    |> next()
  end

  defp hp_recovery_lecture(ctx) do
    {ctx, hp_recovery} =
      ctx
      |> mes("Since you've mastered Bash,")
      |> mes("I feel that you're ready to learn more about Swordman skills.")
      |> next()
      |> mes("[Shurank]")
      |> mes("Now, you must be familiar with the ^5D478BIncrease HP Recovery Skill^000000. When")
      |> mes("it comes to damage, you must be")
      |> mes("able to both take it and dish it out.")
      |> next()
      |> check_skill(:chk_hp, 4)

    ctx =
      cond do
        hp_recovery == 0 ->
          ctx
          |> mes("[Shurank]")
          |> mes("But judging from that")
          |> mes("scrawny frame of yours,")
          |> mes("its looks like you haven't learned the Increase HP Recovery Skill at all...!")
          |> next()
          |> explain_hp_recovery()
          |> mes("[Shurank]")
          |> mes("I strongly suggest that you")
          |> mes(
            "learn this skill! Of course, there are other Swordman skills that are just as important, though..."
          )
          |> set_char_var(:tu_swordman, 5)
          |> next()

        hp_recovery == 10 ->
          ctx
          |> mes("[Shurank]")
          |> mes("Ah! That healthy glow!")
          |> mes(
            "I see that you've mastered this skill already. Let me give you a little reward for your hard training!"
          )
          |> set_char_var(:tu_swordman, 5)
          |> give_exp(112, 1120)
          |> next()

        true ->
          ctx
          |> mes("[Shurank]")
          |> mes(
            "Ah, and I see that you've already learned a little bit about it. But let me briefly tell you more about Increase HP Recovery."
          )
          |> next()
          |> explain_hp_recovery()
          |> mes("[Shurank]")
          |> mes(
            "Increase HP Recovery is a fairly important skill, but whether or not you want to master that is really up to you."
          )
          |> set_char_var(:tu_swordman, 5)
          |> next()
      end

    ctx
    |> setquest(8215)
    |> mes("[Shurank]")
    |> mes(
      "By now, I believe that you know enough about the Increase HP Recovery skill. Next time, I shall teach you what I know about the Provoke skill."
    )
    |> close()
  end

  defp explain_hp_recovery(ctx) do
    ctx
    |> mes("[Shurank]")
    |> mes("The Increase HP Recovery Skill")
    |> mes("is a passive skill that is always in effect and does not consume")
    |> mes("any of your SP.")
    |> next()
    |> mes("[Shurank]")
    |> mes(
      "It enables you to regenerate your health twice as fast. This might not seem like a big deal, but it will reduce the time you need to rest from battles."
    )
    |> next()
  end

  defp bash_mastery_check(ctx) do
    {ctx, bash} =
      ctx
      |> mes("If you want to be")
      |> mes("able to use the full")
      |> mes("power of the Bash skill,")
      |> mes("you better have mastered it")
      |> mes("if you want me to acknowledge")
      |> mes("you as a fellow Swordman.")
      |> next()
      |> check_skill(:chk_bash, 5)

    if bash == 10 do
      ctx
      |> praise_bash_mastery()
      |> set_char_var(:tu_swordman, 4)
      |> changequest(8213, 8214)
      |> reward_bash_mastery()
    else
      bash_not_mastered(ctx)
    end
  end

  defp bash_training_check(ctx) do
    {ctx, bash} =
      ctx
      |> mes("I hope you've been")
      |> mes("training yourself in using")
      |> mes("Bash. If you want to grow as a Swordman, you will have great")
      |> mes("need to master this skill.")
      |> next()
      |> check_skill(:chk_bash, 5)

    cond do
      bash > 4 and bash < 10 ->
        ctx
        |> mes("[Shurank]")
        |> mes(
          "Hm. It doesn't look like you've gained mastery of Bash, but it seems like you're trying hard."
        )
        |> next()
        |> mes("[Shurank]")
        |> mes(
          "Let me review the use of the Bash skill to you. If you've heard this before, it'll be a good refresher."
        )
        |> next()
        |> explain_bash()
        |> mes("[Shurank]")
        |> mes(
          "Here's a little reward for all of your hard work. I hope you realize the importance of using Bash as"
        )
        |> mes("you grow stronger.")
        |> set_char_var(:tu_swordman, 3)
        |> changequest(8212, 8213)
        |> give_exp(83, 830)
        |> close()

      bash == 10 ->
        ctx
        |> praise_bash_mastery()
        |> set_char_var(:tu_swordman, 4)
        |> changequest(8212, 8214)
        |> reward_bash_mastery()

      true ->
        bash_not_mastered(ctx)
    end
  end

  defp bash_progress_check(ctx) do
    {ctx, bash} =
      ctx
      |> mes("Have you been learning")
      |> mes(
        "the art of using Bash? I fervently believe that the Bash skill is the essense of Swordmanship!"
      )
      |> next()
      |> check_skill(:chk_bash, 5)

    cond do
      bash > 0 and bash < 5 ->
        ctx
        |> explain_bash_in_detail()
        |> humble_bash_reward()
        |> set_char_var(:tu_swordman, 2)
        |> changequest(8211, 8212)
        |> give_exp(58, 580)
        |> close()

      bash > 4 and bash < 10 ->
        ctx
        |> mes("[Shurank]")
        |> mes("Hmm...")
        |> mes(
          "Still haven't mastered Bash, eh? Well, in any case, I think you've made some progress."
        )
        |> next()
        |> mes("[Shurank]")
        |> mes(
          "Let me explain the use of the Bash skill to you. If you've heard this before, it'll be a good refresher."
        )
        |> next()
        |> explain_bash_in_detail()
        |> mes("[Shurank]")
        |> mes(
          "For your efforts and patience, I offer you this small reward. Please take it and grow even stronger..."
        )
        |> set_char_var(:tu_swordman, 3)
        |> changequest(8211, 8213)
        |> give_exp(83, 830)
        |> next()
        |> mes("[Shurank]")
        |> mes(
          "I believe that every true Swordman should master the Bash skill. If you ever do master the skill as a Swordman, come back to me."
        )
        |> close()

      bash == 10 ->
        ctx
        |> praise_bash_mastery()
        |> set_char_var(:tu_swordman, 4)
        |> changequest(8211, 8214)
        |> reward_bash_mastery()

      true ->
        ctx
        |> mes("[Shurank]")
        |> mes(
          "You still can't even use Bash...? What's the use of a sword if not to smash things?! Come back to me"
        )
        |> mes("once you've learned how to use")
        |> mes("that skill!")
        |> close()
    end
  end

  defp introduce_bash(ctx) do
    {ctx, bash} =
      ctx
      |> mes("Ah, a comrade in arms.")
      |> mes(
        "Allow me to introduce myself. I am Shurank Chainlier, a Knight in the service of the Prontera Chivalry."
      )
      |> next()
      |> mes("[Shurank]")
      |> mes(
        "It concerns me deeply that the Swordmen of today may not truly understand the way of the sword. And to think that they may become Knights later..."
      )
      |> next()
      |> mes("[Shurank]")
      |> mes("Have you been training")
      |> mes("to be an expert Swordman?")
      |> mes("If so, you must learn the")
      |> mes("fundamentals, the first of")
      |> mes("which is the ^5D478BBash^000000 skill.")
      |> next()
      |> check_skill(:chk_bash, 5)

    cond do
      bash == 0 ->
        ctx
        |> mes("[Shurank]")
        |> mes("^333333*Gasp*^000000")
        |> mes(
          "Those soft, delicate hands! You've never learned how to use Bash, haven't you?! How do you expect to lead battles without knowing Bash?"
        )
        |> next()
        |> mes("[Shurank]")
        |> mes(
          "Now, if you wish to become a true Swordman, you must learn the Bash skill. There's no question about it: You've got to know these basics! Take this, and learn to Bash!"
        )
        |> set_char_var(:tu_swordman, 1)
        |> give_exp(49, 490)
        |> setquest(8211)
        |> close()

      bash > 0 and bash < 5 ->
        ctx
        |> explain_bash_in_detail()
        |> humble_bash_reward()
        |> set_char_var(:tu_swordman, 2)
        |> setquest(8212)
        |> give_exp(58, 580)
        |> close()

      bash > 4 and bash < 10 ->
        ctx
        |> mes("[Shurank]")
        |> mes(
          "I see that you've gained some proficiency with the Bash skill. But still, it's not enough. Let me explain..."
        )
        |> next()
        |> explain_bash()
        |> bash_nuances()
        |> humble_bash_reward()
        |> set_char_var(:tu_swordman, 3)
        |> setquest(8213)
        |> give_exp(83, 830)
        |> next()
        |> mes("[Shurank]")
        |> mes("But if you wish to become an expert Swordman in my eyes, you must master Bash!")
        |> close()

      bash == 10 ->
        ctx
        |> praise_bash_mastery()
        |> set_char_var(:tu_swordman, 4)
        |> setquest(8214)
        |> reward_bash_mastery()

      true ->
        idle_reply(ctx)
    end
  end

  defp explain_bash_in_detail(ctx) do
    ctx
    |> mes("[Shurank]")
    |> mes("I see that you understand")
    |> mes(
      "a little bit about the Bash skill. But still, it's not enough. Let me explain in detail..."
    )
    |> next()
    |> explain_bash()
    |> bash_nuances()
  end

  defp explain_bash(ctx) do
    ctx
    |> mes("[Shurank]")
    |> mes(
      "Bash is an active skill, mastered at Level 10, which allows you to smash your target. In essense,"
    )
    |> mes("it's a highly damaging attack!")
    |> next()
    |> mes("[Shurank]")
    |> mes("Since it's an active skill, Bash consumes SP each time it is")
    |> mes("used. If you're not careful, you'll be out of SP in no time...!")
    |> next()
  end

  defp bash_nuances(ctx) do
    ctx
    |> mes("[Shurank]")
    |> mes(
      "Well, that's all I can tell you about Bash for now. As for its subtle nuances, you'll have to experience them for yourself"
    )
    |> mes("in battle.")
    |> next()
  end

  defp humble_bash_reward(ctx) do
    ctx
    |> mes("[Shurank]")
    |> mes(
      "Still, for your training efforts, let me give you a humble reward. But remember, we still have more"
    )
    |> mes("of the fundamentals to cover!")
  end

  defp praise_bash_mastery(ctx) do
    ctx
    |> mes("[Shurank]")
    |> mes("Those calluses...!")
    |> mes(
      "Only a master of the Bash skill has those kinds of hands. Great work, Swordman. I'm very impressed."
    )
    |> next()
    |> mes("[Shurank]")
    |> mes(
      "Here's a small prize in recognition of your efforts thus far. But don't relax yet! You still have a long way to go before grasping"
    )
    |> mes("all of the basics.")
  end

  defp reward_bash_mastery(ctx) do
    ctx
    |> give_exp(97, 970)
    |> give_item(2503, 1)
    |> close()
  end

  defp bash_not_mastered(ctx) do
    ctx
    |> mes("[Shurank]")
    |> mes("Hmm, you might be able to")
    |> mes(
      "use Bash quite well, but you are not a master of it yet. I encourage you to master Bash in order to unleash its true potential!"
    )
    |> close()
  end

  defp check_skill(ctx, local, skill_id) do
    ctx = set_local(ctx, local, getskilllv(ctx, skill_id))
    {ctx, get_local(ctx, local, 0)}
  end

  defp give_exp(ctx, renewal_exp, classic_exp) do
    if Rathena.truthy?(checkre(ctx, 3)) do
      getexp(ctx, renewal_exp, 0)
    else
      getexp(ctx, classic_exp, 0)
    end
  end
end
