defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.AgedStranger do
  @moduledoc """
  The old hermit of Whale Island, who guides the player through The Moving Island quest.

  ## Behavior

  - Refuses to talk while the player has less than 2000 free weight.
  - On the first visit he explains Whale Island, then sails the island back to the mainland
    over a 20 second wait before the player can disembark at the Moscovia docks.
  - When the player returns, he asks for Log, Tough Vines, Antelope Horn and Sea-otter Fur and
    crafts a Gusli from them, which takes a 1 in 3 chance per visit to finish.
  - Teaches the Gusli to a player who equips it: Bards and Clowns pass each attempt with a 1 in
    3 chance, everyone else with a 1 in 6 chance.
  - Afterwards he offers to send the player back to Moscovia or, once the quest is done, to an
    unexplored field.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Kisuka
    - brianluau
    - Gepard
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Lemongrass
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "mosk_fild01",
        x: 86,
        y: 104,
        dir: 3,
        sprite: 963,
        name: "Aged Stranger",
        scope: :shared,
        unique_name: "Aged Stranger#npc"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @gusli 2707
  @materials "^0000FFLog 30, Tough Vines 20, Antelope Horn 20, Sea-otter Fur 10^000000."

  @impl true
  def on_talk(ctx) do
    if max_weight(ctx) - weight(ctx) < 2000 do
      ctx
      |> mes("[Aged Stranger]")
      |> mes("You're carrying too many items.")
      |> mes("Please come after using kafra service.")
      |> close()
    else
      talk_at_stage(ctx, get_char_var(ctx, :mos_whale_edq, 0))
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp talk_at_stage(ctx, 13) do
    ctx
    |> mes("[Aged Stranger]")
    |> mes("Oh, your awake.")
    |> mes("How do you feel? Are you ok??")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Hm... where..is...")
    |> mes("Eck! What happened...?")
    |> next()
    |> mes("[Aged Stranger]")
    |> mes("Well... You were a bit")
    |> mes("of a surprise! I haven't")
    |> mes("talked for a long time...")
    |> mes("with a person who lives on dry")
    |> mes("land.")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Where am I?")
    |> mes("Who are you old man?")
    |> next()
    |> mes("[Aged Stranger]")
    |> mes("This is... well...")
    |> mes("What can I say...")
    |> mes("This is called a moving island, by")
    |> mes("most people.")
    |> next()
    |> mes("[Aged Stranger]")
    |> mes("This is a small island that only I inhabit.")
    |> next()
    |> mes("[Aged Stranger]")
    |> mes("I call it...")
    |> mes("Whale Island.")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("This place is very famously known")
    |> mes("as The Moving Island! But... This")
    |> mes("island is... Maybe...")
    |> next()
    |> mes("[Aged Stranger]")
    |> mes("Now do you get it? Hahaha!")
    |> mes("Right. We are standing on")
    |> mes("the back of a gigantic whale!")
    |> mes("That's why I call it Whale Island!")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("How...? How is it possible")
    |> mes("that the water flows in streams")
    |> mes("here? And trees grow! On the")
    |> mes("whale's back!?!")
    |> next()
    |> mes("[Aged Stranger]")
    |> mes("Heheheh. This is an island")
    |> mes("of legend. Right now you are")
    |> mes("experiencing greatness! Hahahaha!")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Are you a real person?")
    |> next()
    |> mes("[Aged Stranger]")
    |> mes("Heheh, as you can see,")
    |> mes("I am just an aged man.")
    |> mes("I've simply spent my lifetime here")
    |> mes("leisurely, by breaking off")
    |> mes("relations with any unworldly life.")
    |> next()
    |> mes("[Aged Stranger]")
    |> mes("Okay, now you get yourself")
    |> mes("together. I will send you back to")
    |> mes("dry land. If you don't go back")
    |> mes("soon, some people may worry.")
    |> next()
    |> soundeffect("mos_gusli1.wav", 0)
    |> mes("-The island starts to move slowly")
    |> mes("when the old man plays an")
    |> mes("unfamiliar instrument...-")
    |> next()
    |> mes("[Aged Stranger]")
    |> mes("In a few minutes, you will go back")
    |> mes("to the land from whence you came.")
    |> mes("You can relax.")
    |> next()
    |> play_gusli()
    |> set_char_var(:mos_whale_edq, 14)
    |> advance_quest(18_109, 18_110)
    |> close2()
    |> sleep2(20_000)
    |> set_char_var(:mos_whale_edq, 15)
  end

  defp talk_at_stage(ctx, 14) do
    ctx
    |> play_gusli()
    |> set_char_var(:mos_whale_edq, 15)
    |> close()
  end

  defp talk_at_stage(ctx, 15) do
    ctx
    |> mes("[Aged Stranger]")
    |> mes("Hm... Almost there...")
    |> mes("Young man, you will arrive back on")
    |> mes("the mainland in a few minutes. Go carefully.")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Old man, if I want to come back")
    |> mes("here again, how can I do it?")
    |> next()
    |> mes("[Aged Stranger]")
    |> mes("Hehe... Do you want to come here")
    |> mes("again? Here? Where I live alone? In")
    |> mes("this small island? You are")
    |> mes("funny...")
    |> next()
    |> mes("[Aged Stranger]")
    |> mes("If we are preordained to meet,")
    |> mes("we will meet here again,")
    |> mes("won't we? Heheheh...")
    |> next()
    |> mes("[Aged Stranger]")
    |> mes("It's time to... well,")
    |> mes("go back safely. Someday, if you")
    |> mes("want to come again to meet me, you")
    |> mes("can endure the same seas as last")
    |> mes("time. I won't stop you. Hehehe.")
    |> changequest(18_110, 18_111)
    |> close2()
    |> warp("moscovia", 163, 54)
  end

  defp talk_at_stage(ctx, 30) do
    {ctx, _} =
      ctx
      |> mes("[Aged Stranger]")
      |> mes("Hahaha... I didn't know that I")
      |> mes("would meet you again! How did you")
      |> mes("return?")
      |> next()
      |> select(["Explain the whole story."])

    {ctx, choice} =
      ctx
      |> mes("[Aged Stranger]")
      |> mes("Hm... just like that?")
      |> mes("Whoever hasn't come here directly")
      |> mes("would expect you to return like")
      |> mes("that. Well.")
      |> next()
      |> mes("[Aged Stranger]")
      |> mes("I just wanted to spend the rest of")
      |> mes("my life here, leisurely... I'm")
      |> mes("interested in the world... but I'm")
      |> mes("no match for it...")
      |> next()
      |> mes("[Aged Stranger]")
      |> mes("Do not look sorry for me.")
      |> mes("When you went back I didn't ask you")
      |> mes("not to say anything about this")
      |> mes("island to others.")
      |> next()
      |> mes("[Aged Stranger]")
      |> mes("If I had decided to hide where")
      |> mes("nobody can find... Well, you")
      |> mes("needn't worry too much about that")
      |> mes("now.")
      |> next()
      |> mes("[Aged Stranger]")
      |> mes("Anyway, are you troubled?")
      |> mes("What are you going to do?")
      |> next()
      |> select(["Think more.", "Don't you have a way?"])

    case choice do
      1 ->
        ctx
        |> mes("[Aged Stranger]")
        |> mes("Do that. Think carefully, the")
        |> mes("answer is to be found...")
        |> mes("Hoohoohoo!")
        |> close()

      _ ->
        request_materials(ctx)
    end
  end

  defp talk_at_stage(ctx, 31) do
    {ctx, choice} =
      ctx
      |> mes("[Aged Stranger]")
      |> mes("Okay, are you ready to go back to the mainland?")
      |> next()
      |> select(["What are the materials?", "I am ready."])

    case choice do
      1 ->
        list_materials(ctx)

      _ ->
        ctx
        |> lets_go()
        |> set_char_var(:mos_whale_edq, 32)
        |> sail_to("moscovia", 162, 56)
    end
  end

  defp talk_at_stage(ctx, 33) do
    ctx =
      ctx
      |> mes("[Aged Stranger]")
      |> mes("Oh... Did you get all the")
      |> mes("materials?")
      |> next()

    if count_item(ctx, 7201) > 29 and count_item(ctx, 7197) > 19 and
         count_item(ctx, 7106) > 19 and count_item(ctx, 7065) > 9 do
      ctx
      |> mes("[Aged Stranger]")
      |> mes("You found the right materials.")
      |> mes("Okay, I will start to make the")
      |> mes("instrument.")
      |> next()
      |> delitem(7201, 30)
      |> delitem(7197, 20)
      |> delitem(7106, 20)
      |> delitem(7065, 10)
      |> set_char_var(:mos_whale_edq, 34)
      |> advance_quest(18_117, 18_118)
      |> mes("[Aged Stranger]")
      |> mes("Wait for a moment until I make the")
      |> mes("instrument successfully.")
      |> close()
    else
      missing_materials(ctx)
    end
  end

  defp talk_at_stage(ctx, 34) do
    if Enum.random(1..3) != 2 do
      ctx
      |> mes("[Aged Stranger]")
      |> mes("It's not completed yet. Please wait a little longer.")
      |> close()
    else
      ctx |> hand_over_gusli() |> gusli_owner_menu(true)
    end
  end

  defp talk_at_stage(ctx, 35), do: gusli_owner_menu(ctx, true)

  defp talk_at_stage(ctx, 36) do
    ctx =
      ctx
      |> mes("[Aged Stranger]")
      |> mes("Are you ready to learn the Gusli?")
      |> mes("Please equip the Gusli.")
      |> next()

    if Rathena.truthy?(is_equipped(ctx, @gusli)), do: first_lesson(ctx), else: not_prepared(ctx)
  end

  defp talk_at_stage(ctx, 37) do
    ctx =
      ctx
      |> mes("[Aged Stranger]")
      |> mes("Are you ready to learn the Gusli?")
      |> next()

    if Rathena.truthy?(is_equipped(ctx, @gusli)), do: next_lesson(ctx), else: not_prepared(ctx)
  end

  defp talk_at_stage(ctx, 38), do: gusli_owner_menu(ctx, false)

  defp talk_at_stage(ctx, stage) when stage > 38 do
    {ctx, choice} =
      ctx
      |> mes("[Aged Stranger]")
      |> mes("This is the Whale Island.")
      |> mes("I don't know how you came here.")
      |> next()
      |> mes("[Aged Stranger]")
      |> mes("If you want, I can send you back")
      |> mes("to the mainland. What'll it be?")
      |> next()
      |> select(["Look around.", "Go back to the mainland.", "Venture into the unknown."])

    case choice do
      1 -> take_a_rest(ctx)
      2 -> ctx |> lets_go() |> sail_to("moscovia", 162, 56)
      3 -> offer_unknown_lands(ctx)
      _ -> ctx
    end
  end

  defp talk_at_stage(ctx, _stage) do
    {ctx, choice} =
      ctx
      |> mes("[Aged Stranger]")
      |> mes("Long time, no see!")
      |> mes("You probably like the island, don't you?")
      |> mes("Please stay and take a rest.")
      |> next()
      |> mes("[Aged Stranger]")
      |> mes("Or if you want, I can send you back")
      |> mes("to the mainland. What'll it be?")
      |> next()
      |> select(["Look around.", "Go back to the mainland."])

    case choice do
      1 ->
        take_a_rest(ctx)

      _ ->
        ctx
        |> mes("[Aged Stranger]")
        |> mes("Good. I will go to the place")
        |> mes("right way.")
        |> next()
        |> soundeffect("mos_gusli1.wav", 0)
        |> mes("A old man started to play a instrument")
        |> mes("closing his eyes.")
        |> mes("And then he didn't any answer so, looks like")
        |> mes("falling down to only his world.")
        |> close2()
        |> warp("moscovia", 162, 56)
    end
  end

  defp request_materials(ctx) do
    ctx
    |> mes("[Aged Stranger]")
    |> mes("To bring the Csar here and show him")
    |> mes("everything?!? It's difficult...")
    |> next()
    |> mes("[Aged Stranger]")
    |> mes("An evidence of whale island...")
    |> mes("That's all you need if only it")
    |> mes("existed in this island...")
    |> next()
    |> soundeffect("mos_gusli1.wav", 0)
    |> mes("-The aged man closes his eyes and")
    |> mes("starts to play his instrument, as")
    |> mes("he falls in thought.-")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Old man, could you make one of")
    |> mes("those instruments for me? That is a")
    |> mes("marvelous thing that I've seen only")
    |> mes("here.")
    |> next()
    |> mes("[Aged Stranger]")
    |> mes("Oh... That's a good idea.")
    |> mes("There isn't an instrument like this")
    |> mes("in all Moscovia! Absolutely...")
    |> next()
    |> mes("[Aged Stranger]")
    |> mes("Hm... If you grant my request, I")
    |> mes("will make this instrument for you.")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("What is your request?")
    |> next()
    |> mes("[Aged Stranger]")
    |> mes("Just in time. I have always used")
    |> mes("this instrument which is already")
    |> mes("over 50 years old. The body is so")
    |> mes("worn. It's not surprising that it's")
    |> mes("falling apart...")
    |> next()
    |> mes("[Aged Stranger]")
    |> mes("It is made with strings that only")
    |> mes("exist in this place, but you can")
    |> mes("get the other materials for it in")
    |> mes("the mainland.")
    |> next()
    |> mes("[Aged Stranger]")
    |> mes("If you bring the materials, I can")
    |> mes("make a new one.")
    |> next()
    |> mes("[Aged Stranger]")
    |> mes("The materials are #{@materials}")
    |> next()
    |> mes("[Aged Stranger]")
    |> mes("I won't move the island, so you can")
    |> mes("find it when you come back with the")
    |> mes("materials.")
    |> next()
    |> mes("[Aged Stranger]")
    |> mes("Tell me whenever you're ready, and")
    |> mes("I'll send you back to the")
    |> mes("mainland.")
    |> advance_quest(18_116, 18_117)
    |> set_char_var(:mos_whale_edq, 31)
    |> close()
  end

  defp missing_materials(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Aged Stranger]")
      |> mes("Ugh... We need more materials...")
      |> mes("We need #{@materials}")
      |> next()
      |> mes("[Aged Stranger]")
      |> mes("What will you do? Will you go back")
      |> mes("to the mainland to find the")
      |> mes("materials?")
      |> next()
      |> select(["What are the materials?", "I am ready."])

    case choice do
      1 -> list_materials(ctx)
      _ -> ctx |> lets_go() |> sail_to("moscovia", 162, 56)
    end
  end

  defp list_materials(ctx) do
    ctx
    |> mes("[Aged Stranger]")
    |> mes("You should bring these materials:")
    |> next()
    |> mes("[Aged Stranger]")
    |> mes("You should bring these materials:")
    |> mes(@materials)
    |> close()
  end

  defp hand_over_gusli(ctx) do
    ctx
    |> mes("[Aged Stranger]")
    |> mes("I have succeeded in making the")
    |> mes("instrument! Here you are. It's yours.")
    |> mes("This instrument is called a Gusli.")
    |> mes("This is a traditional instrument")
    |> mes("which comes from a faraway land of")
    |> mes("the ancestors of Moscovia.")
    |> give_item(@gusli, 1)
    |> set_char_var(:mos_whale_edq, 35)
    |> next()
    |> mes("[Aged Stranger]")
    |> mes("I am the last person who has")
    |> mes("learned it in this land.")
    |> next()
    |> mes("[Aged Stranger]")
    |> mes("So, indeed... This is a very")
    |> mes("special item here, that only we")
    |> mes("have.")
    |> next()
    |> mes("[Aged Stranger]")
    |> mes("If you show this to the good Csar,")
    |> mes("he can believe your story about the")
    |> mes("island. Everything is going to be")
    |> mes("well.")
    |> next()
    |> advance_quest(18_118, 18_119)
  end

  defp first_lesson(ctx) do
    ctx =
      ctx
      |> mes("[Aged Stranger]")
      |> mes("Hm... Very well.")
      |> mes("At first, look at me how I play,")
      |> mes("then you play it slowly.")
      |> next()
      |> soundeffect("mos_gusli1.wav", 0)
      |> mes("[Aged Stranger]")
      |> mes("Do not hurry,")
      |> mes("keep your composure,")
      |> mes("just look carefully,")
      |> mes("and follow me slowly.")
      |> next()

    if musician?(ctx) do
      ctx
      |> mes("[Aged Stranger]")
      |> mes(
        "Oh! Ooh... Your hands are really good. You are surely talented with a music instrument."
      )
      |> next()
      |> mes("[Aged Stranger]")
      |> mes(
        "I heard that there are some adventurers in the mainland... that like playing instruments and singing songs! You must be one of them..."
      )
      |> next()
      |> mes("[Aged Stranger]")
      |> mes("This may go faster than I expected.")
      |> next()
      |> your_turn()
      |> attempt_gusli(3)
    else
      ctx |> your_turn() |> attempt_gusli(6)
    end
  end

  defp your_turn(ctx) do
    ctx
    |> mes("[Aged Stranger]")
    |> mes("Okay, it's time for your turn. Play it. Play the song that I played.")
    |> next()
  end

  defp next_lesson(ctx) do
    ctx =
      ctx
      |> mes("[Aged Stranger]")
      |> mes("Um... You did well.")
      |> next()

    if musician?(ctx) do
      ctx
      |> mes("[Aged Stranger]")
      |> mes("with your ability, you can")
      |> mes("absolutely play it wonderfully.")
      |> mes("Cheer up.")
      |> next()
      |> play_again()
      |> attempt_gusli(3)
    else
      ctx |> play_again() |> attempt_gusli(6)
    end
  end

  defp play_again(ctx) do
    ctx
    |> mes("[Aged Stranger]")
    |> mes("Good. Let's play again. Play the")
    |> mes("song that I played.")
    |> next()
  end

  defp musician?(ctx) do
    job = Rathena.job_id(class(ctx))
    job == Rathena.job_id(:bard) or job == Rathena.job_id(:clown)
  end

  defp not_prepared(ctx) do
    ctx
    |> mes("[Aged Stranger]")
    |> mes("Um... Your preparations are not")
    |> mes("good. You're not holding the")
    |> mes("instrument correctly. Equip it")
    |> mes("properly, and then you can learn.")
    |> next()
    |> mes("[Aged Stranger]")
    |> mes("Tell me again when you are prepared")
    |> mes("to play the Gusli correctly.")
    |> close()
  end

  defp attempt_gusli(ctx, odds) do
    if Enum.random(1..odds) == 2 do
      ctx
      |> soundeffect("mos_gusli1.wav", 0)
      |> emotion(:best)
      |> specialeffect2(:exit)
      |> mes("[Aged Stranger]")
      |> mes("Oh! You are good at playing the")
      |> mes("Gusli! In such a short time... you")
      |> mes("are great!")
      |> next()
      |> mes("[Aged Stranger]")
      |> mes("You've done well. I don't need to")
      |> mes("teach you anymore. Your ability")
      |> mes("will be improved with more practice.")
      |> next()
      |> mes("[Aged Stranger]")
      |> mes("Now go back to the mainland and")
      |> mes("play the Gusli for our dear Csar.")
      |> next()
      |> mes("[Aged Stranger]")
      |> mes("With your ability to play, surely")
      |> mes("you can win the admiration of all.")
      |> set_char_var(:mos_whale_edq, 38)
      |> finish_lessons_quest()
      |> close()
    else
      ctx
      |> mes("[Aged Stranger]")
      |> mes("Um, a little bit greenhorn...")
      |> mes("Do not play that way.")
      |> mes("Take more time to concentrate while")
      |> mes("you play.")
      |> next()
      |> mes("[Aged Stranger]")
      |> mes("Practice more on your own.")
      |> mes("I will check on you again.")
      |> mes("If you practice, you will be good")
      |> mes("at it in no time.")
      |> set_char_var(:mos_whale_edq, 37)
      |> close()
    end
  end

  defp finish_lessons_quest(ctx) do
    cond do
      Rathena.truthy?(isbegin_quest(ctx, 18_119)) -> changequest(ctx, 18_119, 18_120)
      Rathena.truthy?(isbegin_quest(ctx, 18_118)) -> changequest(ctx, 18_118, 18_120)
      true -> ctx
    end
  end

  defp gusli_owner_menu(ctx, offer_lessons?) do
    lessons_option = if offer_lessons?, do: "I want to learn the Gusli", else: ""

    {ctx, choice} =
      ctx
      |> mes("[Aged Stranger]")
      |> mes("So, what will you do now?")
      |> next()
      |> select(["How would I get back here?", lessons_option, "Go back to the mainland."])

    case choice do
      1 ->
        ctx
        |> mes("[Aged Stranger]")
        |> mes("You are my friend now,")
        |> mes("and you have this instrument.")
        |> mes("Whenever you want to come back")
        |> mes("here again, just play the Gusli")
        |> mes("at the docks of Moscovia.")
        |> next()
        |> explain_gusli_call()
        |> close()

      2 ->
        ctx
        |> mes("[Aged Stranger]")
        |> mes("You really want to...")
        |> mes("learn this instrument...")
        |> mes("don't you?")
        |> mes("Well... it's hard to learn")
        |> mes("in such a short time...")
        |> next()
        |> mes("[Aged Stranger]")
        |> mes("It's okay if you can't play this")
        |> mes("instrument. I already made it for you.")
        |> next()
        |> mes("[Aged Stranger]")
        |> mes("But I can teach you how")
        |> mes("to play it anyway.")
        |> mes("I can't be too sure, though")
        |> mes("because I have never taught others.")
        |> next()
        |> mes("[Aged Stranger]")
        |> mes("Okay. If you are ready to play the")
        |> mes("Gusli, let me know.")
        |> set_char_var(:mos_whale_edq, 36)
        |> close()

      3 ->
        ctx
        |> mes("[Aged Stranger]")
        |> mes("I see. Okay, let's go.")
        |> next()
        |> mes("[Aged Stranger]")
        |> mes("Whenever you want to come back here")
        |> mes("again, play the Gusli at the docks")
        |> mes("of Moscovia.")
        |> next()
        |> explain_gusli_call()
        |> next()
        |> sail_to("moscovia", 162, 56)

      _ ->
        ctx
    end
  end

  defp explain_gusli_call(ctx) do
    ctx
    |> mes("[Aged Stranger]")
    |> mes("Even if it's difficult to play it")
    |> mes("well, because you may not yet know")
    |> mes("how to play it, it's not a problem.")
    |> mes("Just make a sound.")
    |> next()
    |> mes("[Aged Stranger]")
    |> mes("This island... this whale... can")
    |> mes("perceive the sound of a Gusli from")
    |> mes("an endless distance away.")
    |> next()
    |> mes("[Aged Stranger]")
    |> mes("If you play this instrument,")
    |> mes("wherever you are, I'll go to you")
    |> mes("with this island. Only if you are a")
    |> mes("friend... heheh.")
  end

  defp offer_unknown_lands(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Aged Stranger]")
      |> mes("Oh, if you want, I can")
      |> mes("guide you to a good place for you.")
      |> next()
      |> mes("[Aged Stranger]")
      |> mes("There are some lands...")
      |> mes("untouched and mysterious...")
      |> mes("around Moscovia...")
      |> next()
      |> mes("[Aged Stranger]")
      |> mes("If you want, I'll send you there. What do you think of that?")
      |> next()
      |> select(["Consider it.", "Ok, please send me there."])

    case choice do
      1 -> take_a_rest(ctx)
      _ -> ctx |> lets_go() |> sail_to("mosk_fild02", 204, 54)
    end
  end

  defp take_a_rest(ctx) do
    ctx
    |> mes("[Aged Stranger]")
    |> mes("Well, well... Do as you please.")
    |> mes("If so, I will take a rest.")
    |> close()
  end

  defp lets_go(ctx) do
    ctx
    |> mes("[Aged Stranger]")
    |> mes("I see. If so, let's go.")
    |> next()
  end

  defp sail_to(ctx, map, x, y) do
    ctx
    |> play_gusli()
    |> close2()
    |> warp(map, x, y)
  end

  defp play_gusli(ctx) do
    ctx
    |> soundeffect("mos_gusli1.wav", 0)
    |> mes("-The old man starts to play")
    |> mes("his instrument, with eyes closed.")
    |> mes("He is unresponsive...")
    |> mes("like having fallen into a world")
    |> mes("only his own.-")
  end

  defp advance_quest(ctx, from, to) do
    if Rathena.truthy?(isbegin_quest(ctx, from)), do: changequest(ctx, from, to), else: ctx
  end
end
