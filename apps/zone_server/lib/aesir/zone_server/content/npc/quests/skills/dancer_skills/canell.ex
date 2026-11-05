defmodule Aesir.ZoneServer.Content.Npc.Quests.Skills.DancerSkills.Canell do
  @moduledoc """
  Canell, a stern dancing teacher in Comodo, who teaches Dancers the Charming Wink skill.

  ## Behavior

  - Whips a Dancer of Job Level 40 or higher who answers arrogantly, then asks for a Crystal
    Mirror as the first lesson.
  - Trades the mirror for a confidence lesson and sends the Dancer to her sister Aelle in the
    Prontera Church.
  - After Aelle's drunken lesson, teaches the wink rhythm and grants Charming Wink for the right
    answer; wrong answers earn another lashing.
  - Reteaches Charming Wink to a Gypsy who lost it after transcending.
  - Greets younger Dancers and non-Dancers with small talk.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Lupus
    - Reddozen
    - L0ne_W0lf
    - Yommy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
    quests/skills/dancer_skills.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "comodo",
        x: 204,
        y: 172,
        dir: 5,
        sprite: 724,
        name: "Canell",
        scope: :shared,
        unique_name: "Canell#qsk_dan01"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @charming_wink 1011
  @crystal_mirror 747

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      Rathena.job_id(base_job(ctx)) != Rathena.job_id(:dancer) -> greet_outsider(ctx)
      job_level(ctx) > 39 -> lesson(ctx)
      true -> too_young(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp player_says(ctx), do: mes(ctx, "[#{char_name(ctx, 0)}]")

  defp whip(ctx, hp_percent) do
    ctx |> specialeffect2(:hit2) |> percent_heal(hp: -hp_percent, sp: 0)
  end

  defp greet_outsider(ctx) do
    if sex(ctx) == 0 do
      ctx
      |> mes("[Canell]")
      |> mes("Oh, what a cute")
      |> mes("little girl~! Such")
      |> mes("a chubby lil' belly,")
      |> mes("so cuuuuuuuuuuute~")
      |> close()
    else
      ctx
      |> mes("[Canell]")
      |> mes("Hey there,")
      |> mes("handsome~")
      |> mes("^333333*Wink~*^000000")
      |> emotion(:chup)
      |> specialeffect2(:vallentine2)
      |> next()
      |> mes("^3355FFStrangely enough,")
      |> mes("her wink has made")
      |> mes("your heart throb.^000000")
      |> close()
    end
  end

  defp too_young(ctx) do
    ctx
    |> mes("[Canell]")
    |> mes("Oh, you're such an")
    |> mes("adorable little girl! Ah,")
    |> mes("I'm sorry, but when you")
    |> mes("become a lady at, oh, I don't")
    |> mes("know, Job Level 40, then I'll")
    |> mes("be able to teach you something~")
    |> close()
  end

  defp lesson(ctx) do
    step = get_char_var(ctx, :DANCER_SK, 0)

    cond do
      step == 0 -> first_meeting(ctx)
      step == 1 -> check_mirror(ctx)
      step == 2 -> send_to_sister(ctx)
      step > 2 and step < 7 -> ask_about_sister(ctx)
      step == 7 -> hear_about_sister(ctx)
      step == 8 -> wink_lesson(ctx)
      step > 8 and Rathena.truthy?(getskilllv(ctx, @charming_wink)) -> admire_self(ctx)
      step == 9 and getskilllv(ctx, @charming_wink) == 0 -> reteach_wink(ctx)
      true -> ctx
    end
  end

  defp first_meeting(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Canell]")
      |> mes("It's well known that we must")
      |> mes("be beautiful to captivate those")
      |> mes("who watch us dance. But to rely")
      |> mes("on just our outward appearance")
      |> mes("is a ghastly waste of our full")
      |> mes("potential as performers.")
      |> next()
      |> mes("[Canell]")
      |> mes("Yes, I can tell that you")
      |> mes("don't quite understand that")
      |> mes("the correct frame of mind is")
      |> mes("an essential element to true")
      |> mes("beauty. Now tell me, are you")
      |> mes("confident in your dancing...?")
      |> next()
      |> select(["Of course, old crone!", "I... I'm not sure..."])

    if choice == 1 do
      ctx
      |> mes("[Canell]")
      |> mes("Ho-ho~ I believe you've")
      |> mes("confused confidence with")
      |> mes("arrogance! The naive cannot")
      |> mes("tell there's a vitally important distinction between the two.")
      |> mes("Now... Prepare for punishment!")
      |> next()
      |> player_says()
      |> mes("Ow...!")
      |> mes("Th-that whip!")
      |> mes("I-i-it huuuurts!")
      |> whip(5)
      |> close()
    else
      offer_teaching(ctx)
    end
  end

  defp offer_teaching(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Canell]")
      |> mes("Awareness of your own flaws")
      |> mes("and faults is the first crucial")
      |> mes("step towards improvement.")
      |> mes("Yet your obvious neglect of")
      |> mes("your gift of dancing is...")
      |> mes("grounds for punishment!")
      |> next()
      |> player_says()
      |> mes("What the...? Ack!")
      |> mes("S-stop wh-whipping")
      |> mes("me! It... It stiiings!")
      |> whip(10)
      |> next()
      |> mes("[Canell]")
      |> mes("Ho-ho~! Fortunately for")
      |> mes("you, I will teach you what")
      |> mes("you must learn to rise above")
      |> mes("your current limitations. When")
      |> mes("I'm finished with you, angels and demons won't resist your charms~")
      |> next()
      |> select(["No way, you're not teaching me!", "Alright, I'll see what I can learn."])

    if choice == 1 do
      ctx
      |> mes("[Canell]")
      |> mes("So... You still haven't")
      |> mes("mastered the fine art of")
      |> mes("exuding charm and humility!")
      |> mes("There must be consequences")
      |> mes("for this blatant affront to our")
      |> mes("profession! Prepare yourself!")
      |> next()
      |> player_says()
      |> mes("Nooooo--!")
      |> mes("Not that whip")
      |> mes("again! Arrgh, it's--")
      |> mes("It hurts so much!")
      |> whip(10)
      |> close()
    else
      ctx
      |> mes("[Canell]")
      |> mes("Ho-ho~ It's good that you")
      |> mes("recognize that you have much")
      |> mes("to learn. Well, let's not waste")
      |> mes("any time. Your first lesson will be on image training and self")
      |> mes("visualization. Now, for that...")
      |> next()
      |> mes("[Canell]")
      |> mes("...You must bring")
      |> mes("me ^FF00001 Crystal Mirror^000000!")
      |> mes("This tool is imperative")
      |> mes("to the lesson, so fetch it")
      |> mes("and bring it to me quickly!")
      |> set_char_var(:DANCER_SK, 1)
      |> close()
    end
  end

  defp check_mirror(ctx) do
    if count_item(ctx, @crystal_mirror) > 0 do
      ctx
      |> mes("[Canell]")
      |> mes("Finally, you've come")
      |> mes("with the mirror. Now,")
      |> mes("look deeply and scrutinize")
      |> mes("your reflection. Gaze upon")
      |> mes("each blemish and fault, each")
      |> mes("charming trait of your face.")
      |> next()
      |> mes("[Canell]")
      |> mes("No face is perfect, but")
      |> mes("know that your face is yours")
      |> mes("alone, and that it is what gives you a beauty that can be no")
      |> mes("one else's. Now, repeat")
      |> mes("these truisms after me...")
      |> next()
      |> mes("[Canell]")
      |> mes("''I am beautiful...")
      |> mes("I am irresistable...''")
      |> next()
      |> player_says()
      |> mes("I am beautiful...")
      |> mes("I am irresistable...")
      |> next()
      |> mes("[Intoxicated Canell]")
      |> mes("Louder!")
      |> mes("More feeling!")
      |> mes("''I am beautiful!")
      |> mes("I am irresistable!")
      |> mes("I am the most attractive")
      |> mes("woman in the whole world!''")
      |> next()
      |> player_says()
      |> mes("I am beautiful!")
      |> mes("I am irresistable!")
      |> mes("I am the most attractive")
      |> mes("woman in the whole world!")
      |> specialeffect2(:flasher)
      |> next()
      |> mes("^3355FFYour self esteem has")
      |> mes("sky rocketed. Fortunately,")
      |> mes("you've managed to avoid")
      |> mes("becoming a prima donna.^000000")
      |> delitem(@crystal_mirror, 1)
      |> set_char_var(:DANCER_SK, 2)
      |> close()
    else
      ctx
      |> mes("[Frustrated Canell]")
      |> mes("Did I tell you to come")
      |> mes("back here without bringing")
      |> mes("^FF00001 Crystal Mirror^000000!? Now go")
      |> mes("and get it before I find")
      |> mes("reason to punish you!")
      |> specialeffect(:claymore)
      |> close()
    end
  end

  defp send_to_sister(ctx) do
    ctx
    |> mes("[Canell]")
    |> mes("Yes, the first and most")
    |> mes("important step to becoming")
    |> mes("beautiful is to realize and")
    |> mes("accept your gorgeousness.")
    |> mes("Confidence first, then beauty.")
    |> mes("Never the other way around.")
    |> next()
    |> mes("[Canell]")
    |> mes("Now that you've established")
    |> mes("the proper attitude on beauty,")
    |> mes("it's time for you to learn an")
    |> mes("advanced technique of- shall")
    |> mes("we say- enticement. I know an")
    |> mes("expert that I highly recommend.")
    |> next()
    |> mes("[Canell]")
    |> mes("Go and find my sister")
    |> mes("in Prontera Chruch. If you")
    |> mes("mention me by name, she")
    |> mes("should be willing to teach")
    |> mes("you. I'd do it myself, but I need to enjoy my new Crystal Mirror~")
    |> next()
    |> mes("^3355FFIt figures that she'd")
    |> mes("keep your mirror.^000000")
    |> emotion(:anger)
    |> set_char_var(:DANCER_SK, 3)
    |> close()
  end

  defp ask_about_sister(ctx) do
    ctx
    |> mes("[Canell]")
    |> mes("Ah, such a glamorous")
    |> mes("face and figure. My")
    |> mes("beauty is incompara--")
    |> mes("Oh! It's you. So did my")
    |> mes("sister in Prontera Church")
    |> mes("teach you anything yet?")
    |> emotion(:go)
    |> close()
  end

  defp hear_about_sister(ctx) do
    ctx
    |> mes("[Canell]")
    |> mes("Ah, so were you")
    |> mes("able to find Aelle?")
    |> mes("Were you able to learn")
    |> mes("anything from her?")
    |> next()
    |> player_says()
    |> mes("Actually, I only learned")
    |> mes("about winks, but not so")
    |> mes("much as how to do them.")
    |> mes("She... She got drunk and")
    |> mes("couldn't teach me more.")
    |> next()
    |> mes("[Canell]")
    |> mes("Oh, I should have known")
    |> mes("this would happen. Oh,")
    |> mes("well, I guess there's no way")
    |> mes("around it now. But you should")
    |> mes("know that gettng my sister")
    |> mes("drunk... is punishable.")
    |> next()
    |> mes("[Canell]")
    |> mes("Bam!")
    |> whip(5)
    |> next()
    |> player_says()
    |> mes("?!")
    |> mes("What the")
    |> mes("hell was that?")
    |> next()
    |> mes("[Canell]")
    |> mes("Now, a true Dancer should")
    |> mes("be able to figure out the")
    |> mes("secret to winking on her")
    |> mes("own. But since I'm such")
    |> mes("a kind woman, I will deign")
    |> mes("to explain it to you. Ho-ho~")
    |> next()
    |> mes("^3355FFKind woman...?")
    |> mes("But she just hit you!")
    |> mes("Lightly, of course, but")
    |> mes("still, a smack is a smack.^000000")
    |> set_char_var(:DANCER_SK, 8)
    |> close()
  end

  defp wink_lesson(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Canell]")
      |> mes("Alright, the secret to")
      |> mes("proper winking is to allow")
      |> mes("your eyelid to seductively")
      |> mes("move to a natural rhythm.")
      |> mes("Close your eye for a second, then open it slowly to this count.")
      |> next()
      |> mes("[Canell]")
      |> mes("Un, deux, trois~")
      |> mes("Look at me, do it")
      |> mes("like this. Un, deux, trois~")
      |> mes("Now, let me see you try it.")
      |> emotion(:best)
      |> next()
      |> select(["Un deux trois~-", "Un, doux trois~", "Un, deux, trois~"])

    if choice == 3, do: grant_wink(ctx), else: wrong_rhythm(ctx)
  end

  defp grant_wink(ctx) do
    ctx
    |> player_says()
    |> mes("Un, deux, trois~")
    |> emotion(:best)
    |> specialeffect2(:flasher)
    |> next()
    |> mes("[Canell]")
    |> mes("Great, that's exactly")
    |> mes("how you do it. Now,")
    |> mes("don't forget, the elements")
    |> mes("of rhythm and naturalness")
    |> mes("are absolutely essential to")
    |> mes("this technique of enticement.")
    |> emotion(:chup)
    |> next()
    |> mes("[Canell]")
    |> mes("Now that you've mastered")
    |> mes("the art of winking, you.")
    |> mes("should know that you cannot")
    |> mes("allure those who are much")
    |> mes("stronger than you. So your")
    |> mes("winks won't work on everyone.")
    |> next()
    |> mes("[Canell]")
    |> mes("Of course, my winks don't")
    |> mes("have that drawback. Ho-ho~")
    |> mes("Anyway, it's time for us to part now. I hope that you grow to")
    |> mes("become a more glamorous and charming dancer in days to come.")
    |> emotion(:smile)
    |> next()
    |> mes("^3355FFYou have finally learned")
    |> mes("the Charming Wink skill.^000000")
    |> set_char_var(:DANCER_SK, 9)
    |> specialeffect2(:absorbspirits)
    |> skill(@charming_wink, 1, :permanent)
    |> close()
  end

  defp wrong_rhythm(ctx) do
    ctx
    |> mes("[Canell]")
    |> mes("No, no!")
    |> mes("That's wrong,")
    |> mes("completely wrong!")
    |> mes("Can't you do it right?!")
    |> next()
    |> player_says()
    |> mes("O-ow!")
    |> mes("P-please...!")
    |> mes("Not the whip again!")
    |> whip(5)
    |> close()
  end

  defp admire_self(ctx) do
    ctx
    |> mes("[Canell]")
    |> mes("Hm...?")
    |> mes("Is there anything")
    |> mes("more you wanted to")
    |> mes("ask me? Ah, you must")
    |> mes("be mesmerized by my")
    |> mes("beauty, aren't you?")
    |> emotion(:hng)
    |> next()
    |> mes("[Canell]")
    |> mes("Oh, to be so beautiful")
    |> mes("must be a sin! I should")
    |> mes("work in Prontera Church,")
    |> mes("just like my sister, to")
    |> mes("pray for forgiveness~")
    |> close()
  end

  defp reteach_wink(ctx) do
    ctx
    |> mes("[Canell]")
    |> mes("Hm? Oh, I remember you!")
    |> mes("A Gypsy now, I see~ That")
    |> mes("look suits you. Now, I'm")
    |> mes("sure you've forgotten a few")
    |> mes("things since transcending,")
    |> mes("am I right? Watch this wink...")
    |> next()
    |> mes("[Canell]")
    |> mes("Remember now? It's all")
    |> mes("in the natural, seductive")
    |> mes("and rhythmic movement of")
    |> mes("the eyelid. I hope you use")
    |> mes("your Charming Wink to let")
    |> mes("your inner beauty shine~")
    |> next()
    |> mes("^3355FFYou have learned the")
    |> mes("Charming Wink skill.^000000")
    |> specialeffect2(:absorbspirits)
    |> skill(@charming_wink, 1, :permanent)
    |> close()
  end
end
