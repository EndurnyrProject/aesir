defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.CsarAlexsayIii do
  @moduledoc """
  The ruler of Moscovia, who judges the Banish Winter conspiracy and rewards The Moving Island.

  ## Behavior

  - Players carrying less than 2000 free weight are turned away first.
  - Banish Winter: a player accused of meeting Baba Yaga (stage 12) is put on trial, on talk or
    when walking near him, and clears their name by handing over 40 Yaga's Pestles (stages 13
    and 14); once winter is banished (stage 20) he grants an Old Blue Box.
  - The Moving Island: after hearing the whale island story (stage 17) he demands proof. With a
    Gusli at stage 35 the player admits or denies being able to play it and receives an Old Blue
    Box and experience either way; with a Gusli at stage 38 the player plays it for an Old Violet
    Box and more experience.
  - Every other stage gets a short remark or the default greeting.

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
        map: "mosk_in",
        x: 131,
        y: 92,
        dir: 3,
        sprite: 965,
        name: "Csar Alexsay III",
        scope: :shared,
        unique_name: "Csar Alexsay III#npc",
        trigger: {7, 7}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @yaga_pestle 7762
  @gusli 2707
  @minister_npc "Prime Minister Dmitree#m"

  @impl true
  def on_event("OnTouch", ctx) do
    if get_char_var(ctx, :mos_nowinter, 0) == 12, do: baba_yaga_trial(ctx), else: ctx
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    if max_weight(ctx) - weight(ctx) < 2000 do
      ctx
      |> mes("[Csar Alexsay III]")
      |> mes("You're carrying too many items.")
      |> mes("Please come after using kafra service.")
      |> close()
    else
      talk_by_stage(
        ctx,
        get_char_var(ctx, :mos_nowinter, 0),
        get_char_var(ctx, :mos_whale_edq, 0)
      )
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp talk_by_stage(ctx, 12, _whale_stage), do: baba_yaga_trial(ctx)
  defp talk_by_stage(ctx, 13, _whale_stage), do: pestle_evidence(ctx)

  defp talk_by_stage(ctx, 14, _whale_stage) do
    ctx
    |> mes("[Csar Alexsay III]")
    |> mes("It'd be great if I stayed put, for")
    |> mes("the good of both me and my people.")
    |> mes("I don't want to see the Baba Yaga")
    |> mes("personally.")
    |> next()
    |> mes("[Csar Alexsay III]")
    |> mes("So, I want you to ")
    |> mes("take my place for that.")
    |> next()
    |> mes("[Csar Alexsay III]")
    |> mes("Please help Baba Yaga")
    |> mes("to seize the summer.")
    |> close()
  end

  defp talk_by_stage(ctx, 20, _whale_stage), do: winter_banished(ctx)

  defp talk_by_stage(ctx, _winter_stage, whale_stage) when whale_stage < 16 do
    ctx
    |> mes("[Csar Alexsay III]")
    |> mes("Welcome to Moscovia!")
    |> mes("I am the ruler, Csar Aleksay III, of Moscovia.")
    |> next()
    |> mes("[Csar Alexsay III]")
    |> mes(
      "Go back to your hometown and talk about the beauty of Moscovia! Talk about my great government to all the people of the lands!"
    )
    |> close()
  end

  defp talk_by_stage(ctx, _winter_stage, 16) do
    ctx
    |> mes("[Csar Alexsay III]")
    |> mes("A foreign traveler...?")
    |> mes("Do you have something to tell me?")
    |> next()
    |> mes("[Csar Alexsay III]")
    |> mes("If it is not important,")
    |> mes("have an audience with the Prime Minister first.")
    |> close()
  end

  defp talk_by_stage(ctx, _winter_stage, 17), do: whale_story(ctx)

  defp talk_by_stage(ctx, _winter_stage, whale_stage)
       when whale_stage > 17 and whale_stage < 35 do
    ctx
    |> mes("[Csar Alexsay III]")
    |> mes("I'm tired... I want to take a rest, so... leave.")
    |> next()
    |> mes("[Csar Alexsay III]")
    |> mes("Just think about finding the whale island...")
    |> close()
  end

  defp talk_by_stage(ctx, _winter_stage, 35), do: gusli_audience(ctx)
  defp talk_by_stage(ctx, _winter_stage, 38), do: gusli_performance(ctx)

  defp talk_by_stage(ctx, _winter_stage, 39) do
    ctx
    |> mes("[Csar Alexsay III]")
    |> mes("What happen... If you have special things go out.")
    |> close()
  end

  defp talk_by_stage(ctx, _winter_stage, 40) do
    ctx
    |> mes("[Csar Alexsay III]")
    |> mes("Um... You are a traveler as I saw.")
    |> mes("If you have special things, don't interfere my rest.")
    |> close()
  end

  defp talk_by_stage(ctx, _winter_stage, 41) do
    ctx
    |> mes("[Csar Alexsay III]")
    |> mes("Oh... You. ~")
    |> mes("Nice to see you again.")
    |> mes("I want for you to sometimes stop by here and play some music for me. ~")
    |> close()
  end

  defp talk_by_stage(ctx, _winter_stage, _whale_stage) do
    ctx
    |> mes("[Csar Alexsay III]")
    |> mes("Welcome to Moscovia,")
    |> mes("I am Csar Alexsay the Third.")
    |> next()
    |> mes("[Csar Alexsay III]")
    |> mes("Go back to your hometown and tell everyone about the beauty of Moscovia,")
    |> mes("and my great government.")
    |> close()
  end

  defp baba_yaga_trial(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Csar Alexsay III]")
      |> mes("You!!!")
      |> mes("So many people saw you")
      |> mes("meet with Baba Yaga!")
      |> next()
      |> mes("[Csar Alexsay III]")
      |> mes("The guilt which must be felt, when")
      |> mes("meeting secretly with a witch...")
      |> next()
      |> mes("[Csar Alexsay III]")
      |> mes("For that, we indict capital")
      |> mes("punishment without any just trial!")
      |> next()
      |> mes("[Csar Alexsay III]")
      |> mes("But you are a stranger to these")
      |> mes("lands... So I will hold you in special trial.")
      |> next()
      |> mes("[Csar Alexsay III]")
      |> mes("If you have anything to say...")
      |> mes("spare me no detail.")
      |> next()
      |> select(["Explain the circumstances."])

    ctx =
      ctx
      |> mes("-Talk about what happened with Baba")
      |> mes("Yaga, and move forward with the plan.-")
      |> next()
      |> mes("[Csar Alexsay III]")
      |> mes("Hm-hm, that's an embarrassing story...")
      |> mes("But if you are telling the")
      |> mes("truth, my people will be pleased.")
      |> next()
      |> mes("[Csar Alexsay III]")
      |> mes("Okay, Bring to me")
      |> mes("any evidence, to believe")
      |> mes("what you are saying.")
      |> next()
      |> mes("[Csar Alexsay III]")
      |> mes("You killed the Baba Yaga!!")
      |> mes("If this is true, bring")
      |> mes("me Yaga's Pestles.")
      |> mes("If you do, I will make")
      |> mes("sure no one ever doubts you.")
      |> next()

    if count_item(ctx, @yaga_pestle) > 39 do
      case select(ctx, ["Show the Yaga's Pestles.", "Do nothing."]) do
        {ctx, 1} -> offer_pestles(ctx)
        {ctx, _} -> demand_pestles(ctx)
      end
    else
      demand_pestles(ctx)
    end
  end

  defp offer_pestles(ctx) do
    ctx
    |> player_says("Yes, Here you are.")
    |> next()
    |> mes("-Offered the Yaga's Pestles.-")
    |> delitem(@yaga_pestle, 40)
    |> next()
    |> mes("[Csar Alexsay III]")
    |> mes("Hm.. You do have them.")
    |> mes("For the time being, I will admit")
    |> mes("that you are coming and going to")
    |> mes("hunt Baba Yaga.")
    |> next()
    |> mes("[Csar Alexsay III]")
    |> mes("But do not engage in doubtable")
    |> mes("behavior that would instigate my")
    |> mes("people to act in a strange way!")
    |> next()
    |> mes("[Csar Alexsay III]")
    |> mes("If you do that, I will arrest you immediately!")
    |> mes("So take care of yourself.")
    |> next()
    |> mes("[Csar Alexsay III]")
    |> mes("And, when you succeed in")
    |> mes("banishing winter with magic,")
    |> mes("announce that to me immediately.")
    |> set_char_var(:mos_nowinter, 14)
    |> changequest(18076, 18077)
    |> close()
  end

  defp demand_pestles(ctx) do
    ctx
    |> mes("[Csar Alexsay III]")
    |> mes("I said to bring me")
    |> mes("40 Yaga's Pestles")
    |> mes("from the Baba Yaga.")
    |> set_char_var(:mos_nowinter, 13)
    |> close()
  end

  defp pestle_evidence(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Csar Alexsay III]")
      |> mes("Did you bring some evidence to")
      |> mes("resolve your issue of doubt, traveler?")
      |> next()
      |> select(["Yes, I did.", "I am confused."])

    cond do
      choice != 1 ->
        ctx
        |> mes("[Csar Alexsay III]")
        |> mes("I said to bring me")
        |> mes("40 Yaga's Pestles")
        |> mes("from the Baba Yaga.")
        |> next()
        |> mes("[Csar Alexsay III]")
        |> mes("Are you here to tease me?")
        |> close()

      count_item(ctx, @yaga_pestle) > 39 ->
        hand_over_pestles(ctx)

      true ->
        ctx
        |> mes("[Csar Alexsay III]")
        |> mes("Your items do not match the")
        |> mes("count of 40 Yaga's Pestles.")
        |> mes("Did you forget the amount,")
        |> mes("or did you wish to lie to me...")
        |> next()
        |> mes("[Csar Alexsay III]")
        |> mes("I will treat that as a joke!")
        |> mes("A kind of sarcasm!")
        |> mes("You go away now and bring some")
        |> mes("evidence to certify your innocence.")
        |> close()
    end
  end

  defp hand_over_pestles(ctx) do
    ctx
    |> delitem(@yaga_pestle, 40)
    |> mes("[Csar Alexsay III]")
    |> mes("Good,")
    |> mes("I won't doubt you anymore.")
    |> mes("Because you've proven yourself,")
    |> mes("you can remain a free traveler.")
    |> next()
    |> mes("[Csar Alexsay III]")
    |> mes("Surely, I hate cooperating with Baba Yaga.")
    |> mes("But if my people are happy")
    |> mes("after the work you do,")
    |> mes("I am also pleased.")
    |> next()
    |> mes("[Csar Alexsay III]")
    |> mes("For the time being, I will admit")
    |> mes("that you are coming and going to")
    |> mes("hunt Baba Yaga.")
    |> next()
    |> mes("[Csar Alexsay III]")
    |> mes("But do not engage in doubtable")
    |> mes("behavior that would instigate my")
    |> mes("people to act in a strange way!")
    |> next()
    |> mes("[Csar Alexsay III]")
    |> mes("If you do that, I will arrest you immediately!")
    |> mes("So take care of yourself.")
    |> set_char_var(:mos_nowinter, 14)
    |> changequest(18076, 18077)
    |> close()
  end

  defp winter_banished(ctx) do
    ctx
    |> mes("[Csar Alexsay III]")
    |> mes("Are you here for...")
    |> next()
    |> mes("[Csar Alexsay III]")
    |> mes("I already heard about the")
    |> mes("weather from the minister.")
    |> next()
    |> mes("[Csar Alexsay III]")
    |> mes("Actually, I was a little")
    |> mes("dissatisfied with the doing")
    |> mes("of witchcraft at the center")
    |> mes("of the square...")
    |> next()
    |> mes("[Csar Alexsay III]")
    |> mes("But... I can admit it was good work.")
    |> next()
    |> mes("[Csar Alexsay III]")
    |> mes("Everyone hates the cold winter.")
    |> mes("Now, the winter will not")
    |> mes("come anymore! So, I'm very pleased.")
    |> next()
    |> mes("[Csar Alexsay III]")
    |> mes("Right.")
    |> mes("I want to give you something")
    |> mes("in the name of the people.")
    |> next()
    |> mes("[Csar Alexsay III]")
    |> mes("Here, take it.")
    |> mes("I give it as an atonement")
    |> mes("to make my people happy.")
    |> set_char_var(:mos_nowinter, 21)
    |> completequest(18079)
    |> give_item(603, 1)
    |> next()
    |> mes("[Csar Alexsay III]")
    |> mes("Stay here as long as you want, and")
    |> mes("enjoy yourself to the fullest this summer.")
    |> close()
  end

  defp whale_story(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Csar Alexsay III]")
      |> mes("Oh, are you the traveler who told me about an interesting adventure story...")
      |> next()
      |> mes("[Csar Alexsay III]")
      |> mes(
        "Not only are you not from Moscovia, but also... you have found the moving island, which only existed in legends! I want to hear details..."
      )
      |> next()
      |> mes("[Csar Alexsay III]")
      |> mes("Let's hear it...")
      |> mes("Tell me quickly.")
      |> mes("I'm anxious to know the truth about the island...")
      |> next()
      |> select(["Tell the story all the while."])

    ctx
    |> mes("...")
    |> next()
    |> mes("... ...")
    |> next()
    |> mes("... ... ...")
    |> next()
    |> mes("... ... ... ...")
    |> next()
    |> mes("[Csar Alexsay III]")
    |> mes(
      "Surely, an interesting story... But it sounds so unbelievable! What do you think, Prime Minister?"
    )
    |> next()
    |> mes("[Prime Minister Dmitree]")
    |> mes("It doesn't sound like a lie,")
    |> mes("but it's difficult to believe")
    |> mes("completely. I mean, I've known")
    |> mes("a whale to be huge, but...")
    |> next()
    |> mes("[Prime Minister Dmitree]")
    |> mes("a person living there...")
    |> mes("water streaming...")
    |> mes("and a tree growing on it...!!!")
    |> mes("Hmm...")
    |> next()
    |> mes("[Csar Alexsay III]")
    |> mes(
      "I agree. I have heard many kinds of mysterious adventure stories, but this sounds like an absurd story!"
    )
    |> next()
    |> mes("[Csar Alexsay III]")
    |> mes("Not to mention that it's happened near my nation. Unbelievable!")
    |> next()
    |> mes("[Prime Minister Dmitree]")
    |> mes("But Csar... In my memory,")
    |> mes("I heard that exactly, the")
    |> mes("last time a story was told")
    |> mes(
      "about the mysterious moving island. But there was a musical instrument...which an old man played."
    )
    |> next()
    |> mes("[Csar Alexsay III]")
    |> mes("Really? Tell me the details.")
    |> next()
    |> mes("[Prime Minister Dmitree]")
    |> mes("Surely, I have heard the same")
    |> mes("story, as told in the legends")
    |> mes("of our ancestors; about an old man who lived there.")
    |> next()
    |> mes("[Csar Alexsay III]")
    |> mes(
      "Hm. There are many doubtful points. Ordinarily, I would give you a big prize, but in this case, it is difficult to believe."
    )
    |> next()
    |> mes("[Csar Alexsay III]")
    |> mes("Bring me something to prove")
    |> mes("the existence of the whale.")
    |> mes("If you do, I will give you a big prize.")
    |> next()
    |> mes("[Csar Alexsay III]")
    |> mes("But if you don't,")
    |> mes(
      "I will punish you for your lies! Bring this instrument that supposedly an old man has."
    )
    |> next()
    |> mes("[Prime Minister Dmitree]")
    |> mes("Csar... This is a foreigner...")
    |> mes("No disrespect was meant to you.")
    |> mes("Perhaps a little more generosity is in order?.")
    |> next()
    |> mes("[Csar Alexsay III]")
    |> mes(
      "No way! If the story is not true, many other foreign travelers who pass by this land will disrespect me like this... What would you have me do?"
    )
    |> next()
    |> mes("[Prime Minister Dmitree]")
    |> mes("......")
    |> next()
    |> mes("[Csar Alexsay III]")
    |> mes("You got it, traveler?")
    |> mes("You have a heavy responsibility.")
    |> mes("Bring evidence of this whale island to me, to provide me with some relief. Now go.")
    |> set_char_var(:mos_whale_edq, 18)
    |> advance_quest(18112, 18113)
    |> close()
  end

  defp gusli_audience(ctx) do
    ctx =
      ctx
      |> mes("[Csar Alexsay III]")
      |> mes("Oh. You've come back...")
      |> mes("Hm. Did you find something to bring")
      |> mes("to me from the whale island?")
      |> next()
      |> mes("[Csar Alexsay III]")
      |> mes("Did you bring the instrument?")
      |> mes("A Gooselri? Which only exists")
      |> mes("in the whale island? Let's see.")
      |> next()

    if count_item(ctx, @gusli) > 0 do
      ctx
      |> mes("[Csar Alexsay III]")
      |> mes("Oh... Is this instrument... a Gooselri?")
      |> next()
      |> mes("[Prime Minister Dmitree]")
      |> mes("Actually, Csar, I believe it is")
      |> mes("called a Gusli.")
      |> next()
      |> examine_gusli()
      |> next()
      |> select(["I can play.", "I can't play it."])
      |> case do
        {ctx, 1} -> play_badly(ctx)
        {ctx, _} -> decline_to_play(ctx)
      end
    else
      ctx
      |> mes("[Csar Alexsay III]")
      |> mes("What are you doing? Can you play it")
      |> mes("without even holding the musical instrument???")
      |> next()
      |> mes("[Csar Alexsay III]")
      |> mes("Don't be impudent with me! Do it right!")
      |> close()
    end
  end

  defp play_badly(ctx) do
    ctx
    |> mes("[Csar Alexsay III]")
    |> mes("You can play it!")
    |> mes("Good, play it right away!")
    |> next()
    |> soundeffect("mos_gusli2.wav", 0)
    |> emote_with_minister(:anger)
    |> mes("[Csar Alexsay III]")
    |> mes("Um... What is this? Do you mock me?")
    |> mes("You are so impudent... You...!")
    |> next()
    |> mes("[Prime Minister Dmitree]")
    |> mes("Csar... Calm down, please.")
    |> mes("If you are quick to anger by such a")
    |> mes("lowly person, it will become a")
    |> mes("problem of prestige for you.")
    |> next()
    |> mes("[Csar Alexsay III]")
    |> mes("Agh... I agree with you.")
    |> mes("You. Give a proper prize to the")
    |> mes("adventurer and send them on their way.")
    |> next()
    |> mes("[Prime Minister Dmitree]")
    |> mes("How can I re...reward...?")
    |> next()
    |> emotion(:hng)
    |> mes("[Csar Alexsay III]")
    |> mes("I ordered you instead Prime")
    |> mes("Minister, to make this poor player")
    |> mes("disappear from in front of my eyes,")
    |> mes("right now.")
    |> next()
    |> mes("[Prime Minister Dmitree]")
    |> mes("You should be grateful for the")
    |> mes("Csar's mercy... impudent")
    |> mes("traveler...")
    |> next()
    |> mes("[Prime Minister Dmitree]")
    |> mes("Even though I regard as your effort for the time so, award you. Take it and go out.")
    |> gusli_reward(50_000, 500_000, 39)
  end

  defp decline_to_play(ctx) do
    ctx
    |> mes("[Csar Alexsay III]")
    |> mes("Um... That's too bad.")
    |> mes("I see... Will I ever believe...")
    |> next()
    |> mes("[Csar Alexsay III]")
    |> mes("Thanks for your efforts.")
    |> mes("Hey, Prime Minister,")
    |> mes("reward this traveler.")
    |> next()
    |> mes("[Prime Minister Dmitree]")
    |> mes("How can I reward the traveler?")
    |> next()
    |> mes("[Csar Alexsay III]")
    |> mes("I leave the matter in your hands;")
    |> mes("it's up to you. I will take a")
    |> mes("rest.")
    |> next()
    |> mes("[Prime Minister Dmitree]")
    |> mes("The Csar didn't take pleasure in")
    |> mes("your story, as I expected.")
    |> next()
    |> mes("[Prime Minister Dmitree]")
    |> mes("Even though I regard as your effort for the time so, award you. Take it.")
    |> gusli_reward(70_000, 700_000, 40)
  end

  defp gusli_reward(ctx, renewal_exp, pre_renewal_exp, whale_stage) do
    ctx
    |> give_item(12_702, 1)
    |> grant_exp(renewal_exp, pre_renewal_exp)
    |> set_char_var(:mos_whale_edq, whale_stage)
    |> advance_quest(18118, 18119)
    |> completequest(18119)
    |> close()
  end

  defp gusli_performance(ctx) do
    ctx =
      ctx
      |> mes("[Csar Alexsay III]")
      |> mes("Oh you come...hum did you find")
      |> mes("something to satisfy me")
      |> mes("at the whale island?")
      |> next()

    if Rathena.truthy?(count_item(ctx, @gusli)) do
      ctx
      |> mes("[Csar Alexsay III]")
      |> mes("Oh... Is this instrument... a Gooselri?")
      |> next()
      |> mes("[Prime Minister Dmitree]")
      |> mes("Actually, Csar, I believe it is called a Gusli.")
      |> next()
      |> examine_gusli()
      |> next()
      |> player_says("Yes. I learned how to play it at Whale Island.")
      |> next()
      |> mes("[Csar Alexsay III]")
      |> mes("Oh! Oh!... You can play it!")
      |> mes("Play it right away. I wonder about its sound.")
      |> next()
      |> soundeffect("mos_gusli1.wav", 0)
      |> mes("-When the music of the Gusli is")
      |> mes("played, all the people in the")
      |> mes("Csar's Palace fall in with the tune.-")
      |> next()
      |> emote_with_minister(:cry)
      |> mes("[Csar Alexsay III]")
      |> mes("Oh! I can't hear without tears.")
      |> mes("That's a sad tune.")
      |> next()
      |> mes("[Prime Minister Dmitree]")
      |> mes("That's right, Csar.")
      |> mes("I have never heard a sad tune such as this.")
      |> mes("Kh-huk. Sniff.")
      |> next()
      |> mes("[Csar Alexsay III]")
      |> mes("Huk... You. Give a big prize to")
      |> mes("this traveler!")
      |> next()
      |> mes("[Prime Minister Dmitree]")
      |> mes("Hukhuk... Sniff. How can I reward this?")
      |> next()
      |> mes("[Csar Alexsay III]")
      |> mes("I leave this matter in your hands.")
      |> mes("Give a proper prize to whom has")
      |> mes("Shown me a great story and")
      |> mes("beautiful music.")
      |> next()
      |> mes("[Prime Minister Dmitree]")
      |> mes("I express thanks to you on behalf")
      |> mes("of our dear Csar and all the people")
      |> mes("in his palace. I will reward your")
      |> mes("efforts, in the name of the Csar.")
      |> give_item(617, 1)
      |> grant_exp(100_000, 1_200_000)
      |> set_char_var(:mos_whale_edq, 41)
      |> completequest(18120)
      |> close()
    else
      ctx
      |> mes("[Csar Alexsay III]")
      |> mes("But you... Where do you keep the")
      |> mes("instrument which you are to show me?")
      |> next()
      |> mes("[Csar Alexsay III]")
      |> mes("Don't you need to be holding the instrument, in order to play it???")
      |> next()
      |> player_says("I'm sorry. I will be ready now, and try again to play it.")
      |> close()
    end
  end

  defp examine_gusli(ctx) do
    ctx
    |> mes("[Csar Alexsay III]")
    |> mes("Oh. Prime Minister, is this the")
    |> mes("correct instrument from the")
    |> mes("legends, then?")
    |> next()
    |> mes("[Prime Minister Dmitree]")
    |> mes("I can't be sure, but this is")
    |> mes("definitely an instrument never seen")
    |> mes("in our lands before.")
    |> next()
    |> mes("[Csar Alexsay III]")
    |> mes("Hm. This is also my first time")
    |> mes("seeing this kind of musical")
    |> mes("instrument. So mysterious... Hey!")
    |> mes("Can you play it?")
  end

  defp player_says(ctx, line) do
    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes(line)
  end

  defp emote_with_minister(ctx, emote) do
    ctx = emotion(ctx, emote)
    emotion(ctx, emote, getnpcid(ctx, @minister_npc))
  end

  defp grant_exp(ctx, renewal_exp, pre_renewal_exp) do
    exp = if Rathena.truthy?(checkre(ctx, 3)), do: renewal_exp, else: pre_renewal_exp
    getexp(ctx, exp, 0)
  end

  defp advance_quest(ctx, from_quest, to_quest) do
    if Rathena.truthy?(isbegin_quest(ctx, from_quest)) do
      changequest(ctx, from_quest, to_quest)
    else
      ctx
    end
  end
end
