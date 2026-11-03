defmodule Aesir.ZoneServer.Content.Npc.Quests.FirstClass.TuArcher.MasterKavaruk do
  @moduledoc """
  Master Kavaruk of the Icarus Archer Guild, who starts both Archer training quests.

  ## Behavior

  - Tells the story of Icarus with advice tailored to the player's job.
  - For Archers, the recent news hands out the guild errands: the Alchemist Guild's Flora
    request (errand step 1), finding Arthail of the Wind (step 2), and, once Arthail's news
    is reported (step 9), closes the errand at step 10 with base and job experience
    (1000/1000 in renewal, 2000/1000 otherwise).
  - Talking about Archers offers the specialized training: accepting sets the training
    step to 1 and sends the player to Seisner; after Seisner's lessons (step 3) Archers are
    sent on to Reidin Corse (step 4), while other jobs end their training there.
  - Hunters are always pointed to Arpesto waiting outside.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Jukka (fix up)
    - Lupus
    - L0ne_W0lf
    - SinSloth
    - Capuche
    - Euphy
    - Kisuka

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "payon_in02",
        x: 54,
        y: 13,
        dir: 3,
        sprite: 55,
        name: "Master Kavaruk",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Master Kavaruk]")
      |> mes("Hello, young one.")
      |> mes("I am Master Kavaruk")
      |> mes("of the Icarus Archer Guild.")
      |> mes("I bid you welcome.")
      |> next()
      |> select(["Ask about 'Icarus.'", "Ask about recent news.", "Talk about Archers."])

    case choice do
      1 -> story_of_icarus(ctx)
      2 -> recent_news(ctx)
      3 -> talk_about_archers(ctx)
      _ -> great_as_you_are(ctx)
    end
  end

  defp story_of_icarus(ctx) do
    ctx =
      ctx
      |> mes("[Master Kavaruk]")
      |> mes("Have you ever")
      |> mes("heard the story")
      |> mes("of Icarus before?")
      |> next()
      |> mes("[Master Kavaruk]")
      |> mes(
        "Icarus was a brave young man who flew through the sky using wings held together by beeswax. Out of curiosity, he flew too close to the sun, his wings melted, and he fell to his death."
      )
      |> next()
      |> mes("[Master Kavaruk]")
      |> mes("Although his is a tragic story, Icarus had a courageous heart")
      |> mes("that we should look up to as")
      |> mes("our standard.")
      |> next()
      |> mes("[Master Kavaruk]")
      |> mes(
        "The members of our guild are those who not only wish to be brave, but to reach out for our dreams like Icarus did. Our members are aspiring Archers, former Archers and current Archers."
      )
      |> next()
      |> mes("[Master Kavaruk]")

    class = Rathena.job_id(class(ctx))
    base_job = Rathena.job_id(base_job(ctx))

    ctx =
      cond do
        class == Rathena.job_id(:novice) ->
          ctx
          |> mes("If you'd like to become an Archer, why don't you go around and learn")
          |> mes(
            "a few things about the profession? I'm sure you'll be able to hear plenty of stories around here."
          )

        class == Rathena.job_id(:archer) ->
          ctx
          |> mes("Since you're an Archer, you might")
          |> mes(
            "benefit from going around and listening to everyone else's battle experiences. Becoming familiar with different fight scenarios will help you in the future."
          )

        base_job == Rathena.job_id(:hunter) ->
          ctx
          |> mes("[Master Kavaruk]")
          |> mes("Arpesto is waiting")
          |> mes("outside. Since he's a")
          |> mes("veteran hunter, he can")
          |> mes("be of great help to you.")

        base_job == Rathena.job_id(:dancer) ->
          ctx
          |> mes("In fact, a few of our")
          |> mes("members specialize in")
          |> mes("capturing the fascination")
          |> mes("of those watching with their")
          |> mes("graceful dances, just like you.")
          |> next()
          |> mes("[Master Kavaruk]")
          |> mes("...But I don't seem to see")
          |> mes("any of them around here right now. They never seem to remain in one")
          |> mes("place for very long. Still, I'm sure of them will turn up here")
          |> mes("one of these days.")

        base_job == Rathena.job_id(:bard) ->
          ctx
          |> mes("In fact, a few of our members")
          |> mes(
            "are highly skilled in singing and entertaining their allies, much in the same way you do."
          )
          |> next()
          |> mes("[Master Kavaruk]")
          |> mes(
            "...But I don't seem to see any of them around here right now. They always wander wherever the wind takes them, but I'm sure one of them will wander back here one"
          )
          |> mes("of these days.")

        true ->
          ctx
          |> mes(
            "They happen to know a lot of information about jobs related to Archers. Why don't you speak to them and learn more about"
          )
          |> mes("these other jobs?")
      end

    close(ctx)
  end

  defp recent_news(ctx) do
    ctx = mes(ctx, "[Master Kavaruk]")

    if Rathena.job_id(base_job(ctx)) == Rathena.job_id(:archer) do
      case get_char_var(ctx, :tu_archer02, 0) do
        0 -> request_flora_help(ctx)
        1 -> request_find_arthail(ctx)
        2 -> remind_find_arthail(ctx)
        9 -> receive_arthail_news(ctx)
        _ -> no_news(ctx)
      end
    else
      no_news(ctx)
    end
  end

  defp request_flora_help(ctx) do
    ctx = mes(ctx, "Oh, it's a good thing")

    ctx
    |> mes(Rathena.concat(Rathena.concat("you're here, ", char_name(ctx, 0)), "."))
    |> mes("I've just received request for support from the Alchemist")
    |> mes("Guild in Al De Baran.")
    |> next()
    |> mes("[Master Kavaruk]")
    |> mes("They've been taking care")
    |> mes(
      "of a Flora field as a way of supplying their funds, but recently some stray cats seem to have been destroying the plants there."
    )
    |> next()
    |> mes("[Master Kavaruk]")
    |> mes(
      "Although the Alchemists have been using Alchemy to summon the Flora again to keep the field running, it's causing a strain on their resources."
    )
    |> next()
    |> mes("[Master Kavaruk]")
    |> mes(
      "They are willing to give rewards for bringing materials such as ^3131FFManeater Blossoms^000000 and ^3131FFStems^000000 which will help them restore"
    )
    |> mes("their Flora.")
    |> next()
    |> mes("[Master Kavaruk]")
    |> mes(
      "If you're interested, it would probably be best to speak to the Alchemist Guild member who is waiting to hear from us at the ^3131FFshop next to the road south of Icarus^000000."
    )
    |> set_char_var(:tu_archer02, 1)
    |> close()
  end

  defp request_find_arthail(ctx) do
    {ctx, _} =
      ctx
      |> mes("Hmmm...")
      |> mes("..........")
      |> next()
      |> select(["Is something the matter?"])

    ctx
    |> mes("[Master Kavaruk]")
    |> mes("Actually, we have a problem.")
    |> mes(
      "The position of master seems to have a lot of power, but I always need to remain here. I don't have the luxury of being able to leave my post."
    )
    |> next()
    |> mes("[Master Kavaruk]")
    |> mes("I asked a member of Icarus to")
    |> mes(
      "wander about the Rune-Midgarts Kingdom and gather news and information about what has been going on recently."
    )
    |> next()
    |> mes("[Master Kavaruk]")
    |> mes(
      "He has been sending me letters containing detailed information, but all of a sudden, I've lost contact with him. I'm concerned over what may have happened."
    )
    |> next()
    |> mes("[Master Kavaruk]")
    |> mes("Would you please go find")
    |> mes(
      "^3131FFArthail of the Wind^000000 for me? Although he doesn't like people, I've ordered for him to wander within the crowds to gather information."
    )
    |> next()
    |> mes("[Master Kavaruk]")
    |> mes("Please find out if he is all right and help him with whatever he")
    |> mes("may need. In the meantime, I will be waiting to hear from you. Thank you very much.")
    |> set_char_var(:tu_archer02, 2)
    |> close()
  end

  defp remind_find_arthail(ctx) do
    ctx
    |> mes("Find Arthail")
    |> mes("of the Wind for me.")
    |> mes("He must be somewhere")
    |> mes("in Prontera...")
    |> close()
  end

  defp receive_arthail_news(ctx) do
    ctx =
      ctx
      |> mes("Hmmm, I see. Thank you")
      |> mes(
        "for bringing me the news. As Arthail has said, I shall wait until he has more news for me."
      )
      |> mes("You should also train and prepare for the future as well.")
      |> set_char_var(:tu_archer02, 10)

    ctx =
      if Rathena.truthy?(checkre(ctx, 3)),
        do: getexp(ctx, 1000, 1000),
        else: getexp(ctx, 2000, 1000)

    close(ctx)
  end

  defp no_news(ctx) do
    ctx
    |> mes("I don't know...")
    |> mes(
      "Recently, I haven't heard any noteworthy news. For now, the warmth of the sun seems to be protecting the peace here."
    )
    |> next()
    |> mes("[Master Kavaruk]")
    |> mes("But if I hear of")
    |> mes("any interesting rumors,")
    |> mes("I will let you know.")
    |> close()
  end

  defp talk_about_archers(ctx) do
    ctx = mes(ctx, "[Master Kavaruk]")
    step = get_char_var(ctx, :tu_archer01, 0)

    cond do
      step < 1 ->
        offer_training(ctx)

      step == 1 or step == 2 ->
        ctx
        |> mes("Hmm...?")
        |> mes("What are you still")
        |> mes("doing here? Go to the")
        |> mes("hills west of Icarus and")
        |> mes("talk to ^3131FFSeisner^000000 to begin your special training.")
        |> close()

      step == 3 ->
        after_seisner_training(ctx)

      step == 4 and Rathena.job_id(base_job(ctx)) == Rathena.job_id(:archer) ->
        ctx
        |> mes(
          "Reidin Corse is just outside of this building. Didn't you see him on your way in?"
        )
        |> close()

      true ->
        great_as_you_are(ctx)
    end
  end

  defp offer_training(ctx) do
    class = Rathena.job_id(class(ctx))
    base_job = Rathena.job_id(base_job(ctx))

    cond do
      class == Rathena.job_id(:novice) or class == Rathena.job_id(:baby) ->
        ctx
        |> mes("Ah...")
        |> mes("So are you")
        |> mes("interested in")
        |> mes("becoming an Archer?")
        |> training_choice()

      class == Rathena.job_id(:archer_high) or base_job == Rathena.job_id(:dancer) or
          base_job == Rathena.job_id(:bard) ->
        ctx
        |> mes(
          "Although I can't deny that you're an expert, I suppose it is a good idea to review the basics of archery from time to time. Would you like to try some refresher training?"
        )
        |> training_choice()

      base_job == Rathena.job_id(:hunter) ->
        ctx
        |> mes("[Master Kavaruk]")
        |> mes("Arpesto is waiting")
        |> mes("outside. Since he's a")
        |> mes("veteran hunter, he can")
        |> mes("be of great help to you.")
        |> close()

      class == Rathena.job_id(:archer) or class == Rathena.job_id(:baby_archer) ->
        ctx
        |> mes(
          "As an Archer, I can see that you'd want to make sure that you have a strong grasp on the fundamentals"
        )
        |> mes("of our job. Would you like some specialized instruction?")
        |> training_choice()

      true ->
        ctx
        |> mes("Although you may not be able")
        |> mes(
          "to directly apply archery related knowledge, it's a good idea to understand the capabilities of"
        )
        |> mes("your Archer allies.")
        |> next()
        |> mes("[Master Kavaruk]")
        |> mes("How would you like")
        |> mes("some specialized instruction to learn more about the Archer job?")
        |> training_choice()
    end
  end

  defp training_choice(ctx) do
    case ctx |> next() |> select(["Yes", "No"]) do
      {ctx, 1} ->
        ctx
        |> set_char_var(:tu_archer01, 1)
        |> mes("[Master Kavaruk]")
        |> mes("Ah yes. Well then, please")
        |> mes(
          "take this message over to ^3131FFSeisner^000000 who is in the Training Grounds west of Icarus."
        )
        |> next()
        |> mes("^3355FFYou've received")
        |> mes("Kavaruk's message")
        |> mes("for Seisner.^000000")
        |> next()
        |> mes("[Master Kavaruk]")
        |> mes("Seisner is very diligent,")
        |> mes("composed, intelligent and")
        |> mes("extremely capable. I believe")
        |> mes("that you can learn much from her.")
        |> close()

      {ctx, 2} ->
        ctx
        |> mes("[Master Kavaruk]")
        |> mes("Ah, I see. Well,")
        |> mes("Icarus will always welcome")
        |> mes("you with open arms. If you")
        |> mes("ever change your mind, feel")
        |> mes("free to come back.")
        |> close()

      {ctx, _} ->
        great_as_you_are(ctx)
    end
  end

  defp after_seisner_training(ctx) do
    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("So ", char_name(ctx, 0)), ","))
      |> mes(
        "Did you have a good experience? Learning theory alone is never too enjoyable, but it is necessary."
      )
      |> next()
      |> mes("[Master Kavaruk]")

    ctx =
      if Rathena.job_id(base_job(ctx)) == Rathena.job_id(:archer) do
        ctx
        |> mes(
          "Now it is time to experience the principles you've just learned firsthand. Go speak to ^3131FFReidin Corse^000000, who is just outside of this building, and he'll tell you about the different skills."
        )
        |> set_char_var(:tu_archer01, 4)
      else
        ctx
        |> mes(
          "Still, there's no need for you to do any field training since only Archers can actually participate"
        )
        |> mes("in that.")
      end

    close(ctx)
  end

  defp great_as_you_are(ctx) do
    ctx
    |> mes("You're great")
    |> mes("just as you are now.")
    |> mes(
      "Still, if you feel like you need something, speak to any of the guild members and listen to their life experiences."
    )
    |> close()
  end
end
