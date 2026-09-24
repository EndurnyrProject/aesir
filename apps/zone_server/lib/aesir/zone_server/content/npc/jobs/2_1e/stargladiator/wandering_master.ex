defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21e.Stargladiator.WanderingMaster do
  @moduledoc """
  Moogang, a wandering Taekwon Master, trains candidates and grants the Star Gladiator job.

  ## Behavior

  - Sets the first test for candidates recommended by Moohyun, once all skill points are spent:
    gather Rough Wind, Great Nature, Mystic Frozen and Flame Heart.
  - Takes the elemental items and guides the candidate through the Sun, Moon and Star rooms.
  - Changes candidates who completed Cheehee's testing to Star Gladiator and clears job quest
    variables.
  - Lets Star Gladiators revisit any of the three rooms; other visitors hear about hiking.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Celestria
    - Samuray22
    - L0ne_W0lf
    - Kisuka

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "comodo",
        x: 172,
        y: 230,
        dir: 3,
        sprite: 730,
        name: "Wandering Master",
        scope: :shared,
        unique_name: "Wandering Master#job_sta"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FClearjobvar
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      Rathena.job_id(class(ctx)) == Rathena.job_id(:taekwon) ->
        guide_candidate(ctx, get_char_var(ctx, :STGL_Q, 0))

      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:star_gladiator) ->
        offer_room_visit(ctx)

      true ->
        talk_about_hiking(ctx)
    end
  end

  defp guide_candidate(ctx, stage) do
    cond do
      stage == 1 -> offer_first_test(ctx)
      stage == 2 -> check_elements(ctx)
      stage == 3 -> offer_altar(ctx)
      stage > 3 and stage < 7 -> return_to_altar(ctx)
      stage == 7 -> advise_on_riddle(ctx)
      stage == 8 -> send_to_moon_room(ctx)
      stage == 9 or stage == 11 -> offer_star_room_return(ctx)
      stage == 10 -> offer_cheehee_visit(ctx)
      stage == 12 -> grant_star_gladiator(ctx)
      true -> introduce_self(ctx)
    end
  end

  defp offer_first_test(ctx) do
    ctx = mes(ctx, "[Moogang]")

    {ctx, choice} =
      ctx
      |> mes("#{char_name(ctx, 0)}...")
      |> mes("I have been expecting you.")
      |> mes("Moohyun has told me about")
      |> mes("your arrival and your desire")
      |> mes("to become a Taekwon Master.")
      |> mes("I will trust his judgment...")
      |> next()
      |> mes("[Moogang]")
      |> mes("Yes, Moohyun is skilled at")
      |> mes("discerning the inner strengths")
      |> mes("of others. You should do well.")
      |> mes("Are you ready for the first test, to use your fists and legs in the")
      |> mes("service of the grand cosmos?")
      |> next()
      |> select(["Yes, let me take the test!", "Wait, I need to think about this!"])

    cond do
      choice != 1 ->
        ctx
        |> mes("[Moogang]")
        |> mes("I respect your decision,")
        |> mes("although I see no reason")
        |> mes("for you to hesitate. But like")
        |> mes("the phases of the moon, all")
        |> mes("changes must occur according")
        |> mes("to the grand scheme of things.")
        |> close()

      Rathena.truthy?(skill_point(ctx)) ->
        request_skill_points_spent(ctx)

      true ->
        assign_first_test(ctx)
    end
  end

  defp request_skill_points_spent(ctx) do
    ctx =
      ctx
      |> mes("[Moogang]")
      |> mes("Hm? You still have Skill")
      |> mes("Points that you haven't yet")
      |> mes("allocated. Use them, learn")

    ctx =
      if sex(ctx) == get_char_var(ctx, :SEX_FEMALE, 0) do
        mes(ctx, "and improve your Taekwon Girl")
      else
        mes(ctx, "and improve your Taekwon Boy")
      end

    ctx
    |> mes("skills. When you are finished, come back here for your training.")
    |> close()
  end

  defp assign_first_test(ctx) do
    ctx
    |> mes("[Moogang]")
    |> mes("Taekwon Do sets the basics.")
    |> mes("Mind, body, soul. These are not")
    |> mes("separate parts, but a functioning whole. Your self is in touch")
    |> mes("with itself, but is it in touch")
    |> mes("with the outside world?")
    |> next()
    |> mes("[Moogang]")
    |> mes("Close your eyes. Seek out")
    |> mes("the sensation of the wind.")
    |> mes("Open your arms and embrace")
    |> mes("the sky. Can you feel it? The")
    |> mes("everspreading flow of the")
    |> mes("universal cosmos?")
    |> next()
    |> mes("[Moogang]")
    |> mes("Nature's laws cannot be broken,")
    |> mes("but as your undestanding of nature grows, you'll be able to grasp the")
    |> mes("sunlight, hold the moonlight, and mold the starlight. This test will")
    |> mes("help you attune yourself...")
    |> next()
    |> mes("[Moogang]")
    |> mes("Go forth and gather the")
    |> mes("power of nature scattered")
    |> mes("around the world. Bring me")
    |> mes("pieces of the blustery wind,")
    |> mes("solid earth, freezing ice,")
    |> mes("and burning flame.")
    |> next()
    |> mes("[Moogang]")
    |> mes("In other words...")
    |> mes("^4D4DFFRough Wind^000000,")
    |> mes("^4D4DFFGreat Nature^000000,")
    |> mes("^4D4DFFMystic Frozen^000000 and")
    |> mes("^4D4DFFFlame Heart^000000.")
    |> mes("Now go...")
    |> set_char_var(:STGL_Q, 2)
    |> changequest(7007, 7008)
    |> close()
  end

  defp check_elements(ctx) do
    if count_item(ctx, 996) > 0 and count_item(ctx, 997) > 0 and count_item(ctx, 995) > 0 and
         count_item(ctx, 994) > 0 do
      accept_elements(ctx)
    else
      ctx
      |> mes("[Moogang]")
      |> mes("For your first test on your")
      |> mes("journey towards becoming")
      |> mes("a Taekwon Master, bring me ")
      |> mes("shards of the natural elements.")
      |> mes("I want you to understand their innate harmony with one another.")
      |> next()
      |> mes("[Moogang]")
      |> mes("Bring...")
      |> mes("^4D4DFFRough Wind^000000,")
      |> mes("^4D4DFFGreat Nature^000000,")
      |> mes("^4D4DFFMystic Frozen^000000 and")
      |> mes("^4D4DFFFlame Heart^000000.")
      |> mes("Now go...")
      |> close()
    end
  end

  defp accept_elements(ctx) do
    ctx
    |> mes("[Moogang]")
    |> mes("Ah, you've completed the")
    |> mes("task I've set for you. Very")
    |> mes("good. Now, while holding these")
    |> mes("shards of the wind, earth, ice")
    |> mes("and flame, did you sense the")
    |> mes("connection between them all?")
    |> next()
    |> mes("[Moogang]")
    |> mes("Winds provide gentle and")
    |> mes("comforting breezes or bring")
    |> mes("destructive hurricanes. Earth")
    |> mes("is the solid ground on which")
    |> mes("all life lives, but it can also")
    |> mes("sink and shake buildings.")
    |> next()
    |> mes("[Moogang]")
    |> mes("Water gives life and provides")
    |> mes("cooling refreshment, but it can")
    |> mes("also drown and freeze life. Fire can bring comforting warmth,")
    |> mes("but it can also reduce life to")
    |> mes("gray ashes. Such is nature.")
    |> next()
    |> mes("[Moogang]")
    |> mes("This is the power of nature.")
    |> mes("Any force can be used to do")
    |> mes("good or evil, depending on")
    |> mes("how you wield it. So do you")
    |> mes("understand now? This is how")
    |> mes("the universe is intertwined.")
    |> next()
    |> mes("[Moogang]")
    |> mes("However, the most primal,")
    |> mes("the purest elements of our")
    |> mes("universe are equated to the")
    |> mes("cosmos: the Sun, the Moon,")
    |> mes("and the Stars. Contemplate")
    |> mes("on this truth for a while...")
    |> next()
    |> mes("[Moogang]")
    |> mes("With the realization of")
    |> mes("the nature of the universe")
    |> mes("comes the respect for nature")
    |> mes("and all things. Now, when you")
    |> mes("are ready for the next test, then")
    |> mes("I shall guide you to the altar.")
    |> delitem(996, 1)
    |> delitem(997, 1)
    |> delitem(995, 1)
    |> delitem(994, 1)
    |> set_char_var(:STGL_Q, 3)
    |> changequest(7008, 7009)
    |> close()
  end

  defp offer_altar(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Moogang]")
      |> mes("Are you ready for")
      |> mes("the next test to become")
      |> mes("a Taekwon Master? Then,")
      |> mes("I shall guide you to the altar.")
      |> next()
      |> select(["Wait, I need more time!", "Yes, I am ready."])

    if choice == 1 do
      ctx
      |> mes("[Moogang]")
      |> mes("I see. Well then, please")
      |> mes("let me know when you")
      |> mes("are ready to proceed.")
      |> close()
    else
      ctx
      |> mes("[Moogang]")
      |> mes("At the altar, speak")
      |> mes("to Daru, who will serve")
      |> mes("as your guide for that")
      |> mes("test. After you complete")
      |> mes("the test, come talk to me.")
      |> close()
      |> warp("job_star", 34, 12)
    end
  end

  defp return_to_altar(ctx) do
    ctx
    |> mes("[Moogang]")
    |> mes("How very strange...")
    |> mes("You cannot have completed")
    |> mes("that test by now. Ah, something")
    |> mes("must have happened. I shall")
    |> mes("send you back to the altar")
    |> mes("so that Daru can test you.")
    |> close()
    |> warp("job_star", 34, 12)
  end

  defp advise_on_riddle(ctx) do
    ctx
    |> mes("[Moogang]")
    |> mes("Hmm...")
    |> mes("You seem troubled.")
    |> mes("Ah, you must be thinking")
    |> mes("about Beeryu's riddle, yes?")
    |> mes("You are the only one that")
    |> mes("can find the answer...")
    |> next()
    |> mes("[Moogang]")
    |> mes("Hmm. Perhaps it would")
    |> mes("be best for you to consult")
    |> mes("with ^4D4DFFMoohyun^000000 back in Payon")
    |> mes("so that you may understand")
    |> mes("Beeryu's test regarding the")
    |> mes("value of patience.")
    |> next()
    |> mes("[Moogang]")
    |> mes("Once you discover the")
    |> mes("meaning of patience that")
    |> mes("Beeryu wants you to find,")
    |> mes("come back to me so that")
    |> mes("I can send you back to the")
    |> mes("Moon Room for testing.")
    |> close()
  end

  defp send_to_moon_room(ctx) do
    ctx
    |> mes("[Moogang]")
    |> mes("Ah, I see that Moohyun")
    |> mes("has helped you achieve a")
    |> mes("new level of understanding.")
    |> mes("Very well, very well. Let me")
    |> mes("send you to the Moon Room")
    |> mes("where Beeryu is waiting...")
    |> close()
    |> warp("job_star", 100, 13)
  end

  defp offer_star_room_return(ctx) do
    ctx
    |> mes("[Moogang]")
    |> mes("Would you like to")
    |> mes("return to the Star Room")
    |> mes("to complete your Taekwon")
    |> mes("Master testing and training?")
    |> next()
    |> select(["Yes, please.", "Maybe later."])
    |> answer_star_room_offer()
  end

  defp offer_cheehee_visit(ctx) do
    ctx
    |> mes("[Moogang]")
    |> mes("Ah, you have come here in")
    |> mes("order to speak to Cheehee.")
    |> mes("Would you like me to send")
    |> mes("you to the Star Room now?")
    |> next()
    |> select(["Yes, please.", "Maybe later."])
    |> answer_star_room_offer()
  end

  defp answer_star_room_offer({ctx, 1}) do
    ctx
    |> mes("[Moogang]")
    |> mes("Don't lose heart...")
    |> mes("I expect that you will")
    |> mes("achieve your goal of")
    |> mes("becoming a Taekwon")
    |> mes("Master very soon.")
    |> close()
    |> warp("job_star", 166, 29)
  end

  defp answer_star_room_offer({ctx, _choice}) do
    ctx
    |> mes("[Moogang]")
    |> mes("I see. Well, when")
    |> mes("your mind, body and")
    |> mes("spirit are prepared, please")
    |> mes("come and talk to me again.")
    |> close()
  end

  defp grant_star_gladiator(ctx) do
    ctx =
      ctx
      |> mes("[Moogang]")
      |> mes("Ah, you've returned")
      |> mes("wiser and more attuned")
      |> mes("with nature than before.")
      |> mes("Yes, I can see it in your eyes.")
      |> mes("So tell me, what did you learn?")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("I can feel the bond between")
      |> mes("the Sun, the Moon and the")
      |> mes("Stars. They all give light,")
      |> mes("but their different shades")
      |> mes("bestow different gifts.")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("The sun gives glorious")
      |> mes("warmth and is the wellspring")
      |> mes("of life. Moonlight is gentle and gives comfort. The twinkling")
      |> mes("of stars gives hope in even")
      |> mes("the darkest of nights.")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("I also know the Sun's")
      |> mes("scorching, destructive")
      |> mes("heat, the loneliness of")
      |> mes("the Moon, and the sadness")
      |> mes("of the Stars. I now understand")
      |> mes("the spectrum of the cosmos!")
      |> next()

    {ctx, _} =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("The combined rage of the")
      |> mes("cosmos can summon a ")
      |> mes("demon of utter darkness.")
      |> mes("The combined love of the")
      |> mes("cosmos bestows infinite")
      |> mes("blessing and light...")
      |> next()
      |> mes("[Moogang]")
      |> mes("I cannot ask for")
      |> mes("anything more. You")
      |> mes("are already a warrior")
      |> mes("of the Sun, the Moon and")
      |> mes("the Stars. Welcome to our")
      |> mes("way of martial arts, friend.")
      |> completequest(7011)
      |> jobchange(:star_gladiator)
      |> FClearjobvar.call([])

    ctx
    |> next()
    |> mes("[Moogang]")
    |> mes("From now on, please")
    |> mes("make your decisions very")
    |> mes("carefully. What you decide")
    |> mes("will determine the course")
    |> mes("of your entire life. Also,")
    |> mes("never forget this song...")
    |> next()
    |> mes("[Moogang]")
    |> mes("''^4D4DFFThe Sun shines on even days.")
    |> mes("The Moon gleams on odd days.")
    |> mes("The Stars sparkle on every")
    |> mes("fifth day without fail.^000000''")
    |> next()
    |> mes("[Moogang]")
    |> mes("That is all that I can")
    |> mes("share with you. Never forget")
    |> mes("that we, as Taekwon Masters,")
    |> mes("cannot exist separately from")
    |> mes("the Sun, Moon and Stars...")
    |> close()
  end

  defp introduce_self(ctx) do
    ctx =
      ctx
      |> mes("[Moogang]")
      |> mes("Oh, hello. You're a")
      |> mes("student of Taekwon Do,")
      |> mes("are you not? It's nice to")
      |> mes("meet you. Please call")
      |> mes("me Moogang. I too used to")
      |> mes("study this Tae Kwon Do.")
      |> next()
      |> mes("[Moogang]")
      |> mes("Um...")
      |> mes("Have you ever")
      |> mes("considered becoming...")
      |> mes("Um... No. Wait. Hmmm...")
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Huh...?")
    |> next()
    |> mes("[Moogang]")
    |> mes("Oh, dear! I always")
    |> mes("have a little bit of")
    |> mes("trouble speaking to other")
    |> mes("people. Now, why don't")
    |> mes("you speak to my good")
    |> mes("friend, Moohyun?")
    |> next()
    |> mes("[Moogang]")
    |> mes("It's just...")
    |> mes("I'm so excited!")
    |> mes("There's every chance")
    |> mes("that you might possibly")
    |> mes("be the warrior I'm seeking!")
    |> close()
  end

  defp offer_room_visit(ctx) do
    {ctx, room} =
      ctx
      |> mes("[Moogang]")
      |> mes("Oh, it's very nice to")
      |> mes("see you again. So where")
      |> mes("have you been lately? I trust")
      |> mes("that you've been to places")
      |> mes("blessed by the Sun, Moon")
      |> mes("and Stars, correct?")
      |> next()
      |> mes("[Moogang]")
      |> mes("My friend, please keep")
      |> mes("my advice in mind and ")
      |> mes("always be careful when")
      |> mes("you make decisions. I don't")
      |> mes("want to see you regreting your decision later on in your life...")
      |> next()
      |> mes("[Moogang]")
      |> mes("Ah, if you miss the")
      |> mes("Room of the Sun, the")
      |> mes("Moon Room or the Star Room,")
      |> mes("I can send you there anytime")
      |> mes("that you wish. Would you like")
      |> mes("to visit any of them now?")
      |> next()
      |> select([
        "Maybe next time.",
        "To the Room of the Sun!",
        "To the Moon Room!",
        "To the Star Room!"
      ])

    case room do
      1 ->
        ctx =
          ctx
          |> mes("[Moogang]")
          |> mes("Alright. I'll always be")
          |> mes("here, so whenever you")
          |> mes("feel like going to any of")
          |> mes("those places, just come")
          |> mes("and talk to me. Goodbye")

        ctx |> mes("for now, #{char_name(ctx, 0)}~") |> close()

      2 ->
        ctx
        |> mes("[Moogang]")
        |> mes("Ah, you must miss")
        |> mes("the glorious warmth")
        |> mes("of the sun, eh? Let")
        |> mes("me send you there")
        |> mes("right away...")
        |> close()
        |> warp("job_star", 34, 12)

      3 ->
        ctx
        |> mes("[Moogang]")
        |> mes("Hm? Have you need")
        |> mes("of the soothing light of")
        |> mes("the Moon? Then I hope")
        |> mes("that you find peace in")
        |> mes("its calming influence...")
        |> close()
        |> warp("job_star", 100, 13)

      4 ->
        ctx
        |> mes("[Moogang]")
        |> mes("Ah, there are countless")
        |> mes("reasons as to why you'd want")
        |> mes("to view the twinkling of the")
        |> mes("stars. Well, let me send you")
        |> mes("to the Star Room right away~")
        |> close()
        |> warp("job_star", 166, 29)

      _ ->
        talk_about_hiking(ctx)
    end
  end

  defp talk_about_hiking(ctx) do
    ctx
    |> mes("[Wandering Martial Artist]")
    |> mes("Do you enjoy hiking?")
    |> mes("The fresh air, the liberation")
    |> mes("found in wandering, and the")
    |> mes("beauty of natural are all")
    |> mes("welcome benefits.")
    |> next()
    |> mes("[Wandering Martial Artist]")
    |> mes("Of course, I cannot enjoy")
    |> mes("the moonlight and starlight")
    |> mes("on nighttime hikes as much")
    |> mes("as you can. Well then, may the")
    |> mes("Sun, Moon and Stars protect")
    |> mes("you on all your journeys~")
    |> close()
  end
end
