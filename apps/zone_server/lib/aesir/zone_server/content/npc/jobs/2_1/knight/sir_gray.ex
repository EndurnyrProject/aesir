defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21.Knight.SirGray do
  @moduledoc """
  Veteran Knight who runs the final Knight job test and crafts Claymores for Knights.

  ## Behavior

  - Interviews candidates who passed Sir Edmond's test about their motives and
    plans, counting points against answers that stray from Knightly virtue.
  - Passes candidates who end with 0, 5, or 10 points, advancing the quest to the
    captain's evaluation; everyone else must return for another interview.
  - Offers Knights a Claymore for 74,000 zeny and one Steel, provided they have
    room to carry it.

  ## Credits

  - Original from rAthena, authors and Contributors
    - PGRO TEAM (Aegis)
    - kobra_k88
    - Lupus
    - Vicious
    - L0ne_W0lf
    - Samuray22
    - Kisuka
    - Vali
    - Euphy
    - Joseph

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prt_in",
        x: 87,
        y: 92,
        dir: 4,
        sprite: 119,
        name: "Sir Gray",
        scope: :shared,
        unique_name: "Sir Gray#knt"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = mes(ctx, "[Sir Gray]")

    if Rathena.job_id(base_job(ctx)) != Rathena.job_id(:swordman) do
      greet_non_swordman(ctx)
    else
      talk_about_test(ctx, get_char_var(ctx, :KNIGHT_Q, 0))
    end
  end

  defp greet_non_swordman(ctx) do
    cond do
      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:knight) -> offer_claymore(ctx)
      Rathena.job_id(base_class(ctx)) == Rathena.job_id(:novice) -> greet_novice(ctx)
      true -> advise_youth(ctx)
    end
  end

  defp offer_claymore(ctx) do
    {ctx, choice} =
      ctx
      |> mes("The glint of light")
      |> mes(
        "that shines off this blade cannot be put into words. This is the weapon every Knight must have."
      )
      |> next()
      |> mes("[Sir Gray]")
      |> mes("Yes...")
      |> mes("^3355FFClaymore^000000!")
      |> mes("Every Knight")
      |> mes("would want one!")
      |> next()
      |> select(["About ^3355FFClaymore^000000", "Buy Claymore", "End Conversation"])

    case choice do
      1 -> describe_claymore(ctx)
      2 -> buy_claymore(ctx)
      3 -> reminisce_about_claymore(ctx)
      _ -> advise_youth(ctx)
    end
  end

  defp describe_claymore(ctx) do
    ctx
    |> mes("[Sir Gray]")
    |> mes(
      "Claymore, one of the best among the famous swords you can attain in Rune-Midgarts' Prontera!! Its value is priceless when considered by a Knight."
    )
    |> next()
    |> mes("[Sir Gray]")
    |> mes(
      "Now, the Prontera Chivalry is making these fabulous Claymores. For Knights, they are only ^3355FF74,000^000000 Zeny."
    )
    |> next()
    |> mes("[Sir Gray]")
    |> mes("But not only that, you need")
    |> mes(
      "1 ^3355FFSteel^000000 because of the Claymore's characteristics. If you like, I can create one for you. For the honor of the Prontera Chivalry!"
    )
    |> close()
  end

  defp buy_claymore(ctx) do
    cond do
      get_char_var(ctx, :MaxWeight, 0) - weight(ctx) < 1800 ->
        refuse_overweight(ctx)

      zeny(ctx) > 73_999 and count_item(ctx, 999) > 0 and
          Rathena.job_id(base_job(ctx)) == Rathena.job_id(:knight) ->
        craft_claymore(ctx)

      true ->
        ask_for_materials(ctx)
    end
  end

  defp refuse_overweight(ctx) do
    ctx
    |> mes("[Sir Gray]")
    |> mes("Oh no...")
    |> mes(
      "It seems that you are carrying too many things. You don't have enough space for a heavy Claymore in your inventory."
    )
    |> next()
    |> mes("[Sir Gray]")
    |> mes("Why don't you")
    |> mes("go and organize")
    |> mes("your items first.")
    |> close()
  end

  defp craft_claymore(ctx) do
    ctx
    |> mes("[Sir Gray]")
    |> mes("You are ready!")
    |> mes("You must know the")
    |> mes("true value of")
    |> mes("a Claymore!")
    |> mes("I shall make")
    |> mes("it right now!!")
    |> next()
    |> mes("[Sir Gray]")
    |> mes("The basics of")
    |> mes("making the Claymore")
    |> mes("is easy. Watch~!")
    |> next()
    |> mes("^3355FF*Stir Stir*^000000")
    |> mes("^3355FF*Ooncha Ooncha*^000000")
    |> next()
    |> mes("[Sir Gray]")
    |> mes("Okay, it's ready!")
    |> mes("Every Knight's pride:")
    |> mes("a fine ^3355FFClaymore^000000.")
    |> mes("You attained a reliable item.")
    |> mes("It'll be a good companion on your adventures.")
    |> delitem(999, 1)
    |> pay_zeny(74_000)
    |> give_item(1163, 1)
    |> close()
  end

  defp ask_for_materials(ctx) do
    ctx
    |> mes("[Sir Gray]")
    |> mes("I realize you may really want a Claymore, but I can't make it without the materials.")
    |> mes("^3355FF74,000 zeny^000000 and ^3355FF1 Steel!^000000.")
    |> next()
    |> mes("[Sir Gray]")
    |> mes("Come back when")
    |> mes("you have everything")
    |> mes("ready. I shall be")
    |> mes("waiting...")
    |> close()
  end

  defp reminisce_about_claymore(ctx) do
    ctx
    |> mes("[Sir Gray]")
    |> mes(
      "Any Knight should be able to wield a Claymore as if it were an extension of their body. I used to look forward to brandishing my Claymore in battle..."
    )
    |> close()
  end

  defp greet_novice(ctx) do
    ctx
    |> mes("Believe it")
    |> mes("or not, I was")
    |> mes("once a Novice")
    |> mes("as well.")
    |> next()
    |> mes("[Sir Gray]")
    |> mes(
      "I never really planned to become a Knight, but I did decide to become a strong person. Somehow, along my journeys, I ended up joining the Prontera Chivalry. Ha ha ha!"
    )
    |> close()
  end

  defp advise_youth(ctx) do
    ctx
    |> mes("Young one,")
    |> mes("use your time")
    |> mes("wisely.")
    |> next()
    |> mes("[Sir Gray]")
    |> mes("No point in")
    |> mes("harboring regret")
    |> mes("once time has passed.")
    |> close()
  end

  defp talk_about_test(ctx, quest) do
    cond do
      quest == 0 -> advise_youth(ctx)
      quest == 12 -> offer_interview(ctx)
      quest == 13 -> offer_second_interview(ctx)
      quest == 14 -> send_to_captain(ctx)
      true -> redirect_early_candidate(ctx)
    end
  end

  defp offer_interview(ctx) do
    {ctx, choice} =
      ctx
      |> mes("Oh...")
      |> mes("A young Swordman.")
      |> mes("Yes, what can")
      |> mes("I do for you?")
      |> next()
      |> select(["I would like to take the test to change jobs.", "Oh, nothing."])

    if choice == 1 do
      ctx
      |> mes("[Sir Gray]")
      |> mes("Hoho, I see.")
      |> mes("So you took")
      |> mes("everyone else's")
      |> mes("test?")
      |> next()
      |> mes("[Sir Gray]")
      |> mes("Then shall")
      |> mes("we begin mine?")
      |> mes("It's not really")
      |> mes("a test though.")
      |> next()
      |> mes("[Sir Gray]")
      |> mes("Let's talk")
      |> mes("casually,")
      |> mes("shall we?")
      |> next()
      |> ask_why_become_knight()
      |> interview()
    else
      ctx |> mes("[Sir Gray]") |> mes("Take care!") |> close()
    end
  end

  defp offer_second_interview(ctx) do
    {ctx, choice} =
      ctx
      |> mes("Ah, you again.")
      |> mes("What brings you")
      |> mes("to me?")
      |> next()
      |> select(["I've been thinking a lot.", "Oh, nothing."])

    if choice == 1 do
      ctx
      |> mes("[Sir Gray]")
      |> mes("Is that so...")
      |> mes("I wonder if you")
      |> mes("truly have...")
      |> next()
      |> mes("[Sir Gray]")
      |> mes("Then...")
      |> mes("Like last time,")
      |> mes("I will ask again...")
      |> next()
      |> ask_why_become_knight()
      |> interview()
    else
      wish_good_health(ctx)
    end
  end

  defp ask_why_become_knight(ctx) do
    ctx
    |> mes("[Sir Gray]")
    |> mes("First...")
    |> mes("Why did you")
    |> mes("decide to become")
    |> mes("a Knight?")
    |> next()
  end

  defp interview(ctx) do
    {ctx, motive_points} = discuss_motive(ctx)

    {ctx, plan_points} =
      ctx
      |> mes("[Sir Gray]")
      |> mes("I understand your thoughts,")
      |> mes("but there are those who wish to")
      |> mes("become Knights without thinking.")
      |> next()
      |> mes("[Sir Gray]")
      |> mes(
        "Those are the ones who instigate problems and shame the honor of Knights, bringing irreversible results."
      )
      |> next()
      |> mes("[Sir Gray]")
      |> mes(
        "The same goes for you as well. Once you become a Knight, you can never become a Swordman again. The duties and responsibilities of a Knight will always be with you."
      )
      |> next()
      |> mes("[Sir Gray]")
      |> mes("If you become a Knight right away, what are you going to do first?")
      |> next()
      |> discuss_plans()

    ctx
    |> mes("[Sir Gray]")
    |> mes("Oh no, we've been")
    |> mes("talking too much...")
    |> mes("I apologize for")
    |> mes("keeping you here")
    |> mes("for so long.")
    |> next()
    |> judge_interview(motive_points + plan_points)
  end

  defp discuss_motive(ctx) do
    {ctx, choice} =
      select(ctx, [
        "To become stronger...",
        "To help my guild...",
        "Because I'm unsatisfied with myself right now..."
      ])

    case choice do
      1 -> discuss_strength(ctx)
      2 -> discuss_guild(ctx)
      3 -> discuss_dissatisfaction(ctx)
      _ -> {ctx, 0}
    end
  end

  defp discuss_strength(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Sir Gray]")
      |> mes("To become stronger, you say?")
      |> mes("Yes, Knights are indeed strong.")
      |> mes("But why gain strength?")
      |> next()
      |> mes("[Sir Gray]")
      |> mes(
        "Is it to show off to others? To attain fame? Or do you have a diferent reason? What do you think is so good about gaining strength as a Knight?"
      )
      |> next()
      |> select([
        "Gain wealth and fame.",
        "I can protect myself.",
        "I can protect others."
      ])

    case choice do
      1 ->
        ctx =
          ctx
          |> mes("[Sir Gray]")
          |> mes(
            "Of course, wealth and fame have their place in the world. But we as Knights must live for higher virtues."
          )
          |> next()

        {ctx, 10}

      2 ->
        ctx =
          ctx
          |> mes("[Sir Gray]")
          |> mes(
            "Good thinking. You must first be able to protect yourself in order to protect others. To this end, you must constantly train, and never give in to laziness."
          )
          |> next()

        {ctx, 0}

      3 ->
        {praise_protecting_the_weak(ctx), 0}

      _ ->
        {ctx, 0}
    end
  end

  defp discuss_guild(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Sir Gray]")
      |> mes(
        "Ah, to help your guild, or maybe even your party. Our wise and benevolent King Tristram the 3rd gave us these golden words..."
      )
      |> next()
      |> mes("[Sir Gray]")
      |> mes(
        "^8B7500Beyond the calm river, lies a dangerous waterfall. Therefore, you must always be prepared for everything...^000000"
      )
      |> next()
      |> mes("[Sir Gray]")
      |> mes("So how do you")
      |> mes("think you can")
      |> mes("help your guild?")
      |> next()
      |> select([
        "My guild needs me.",
        "I can help gather funds for my guild.",
        "I can protect my guild members."
      ])

    case choice do
      1 ->
        ctx =
          ctx
          |> mes("[Sir Gray]")
          |> mes("Anyone, anywhere in this world,")
          |> mes(
            "has a place where they are needed. Never neglect someone in need, even if he is not a guild member."
          )
          |> next()

        {ctx, 0}

      2 ->
        ctx =
          ctx
          |> mes("[Sir Gray]")
          |> mes("Of course wealth is important.")
          |> mes("But we Knights must live for higher virtues.")
          |> next()

        {ctx, 10}

      3 ->
        {praise_protecting_the_weak(ctx), 0}

      _ ->
        {ctx, 0}
    end
  end

  defp praise_protecting_the_weak(ctx) do
    ctx
    |> mes("[Sir Gray]")
    |> mes(
      "Ah, a wonderful idea. A Knight's strength must be used to protect the weak and defend righteousness."
    )
    |> next()
    |> mes("[Sir Gray]")
    |> mes(
      "Sadly, there are a few Knights who shame us by forgetting the ideals that should be basic to Knighthood..."
    )
    |> next()
  end

  defp discuss_dissatisfaction(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Sir Gray]")
      |> mes("Satisfaction, you say.")
      |> mes("It seems like you are")
      |> mes("already a fine Swordman.")
      |> mes("Is there a particular reason you wish to be a Knight?")
      |> next()
      |> mes("[Sir Gray]")
      |> mes("I don't know about")
      |> mes(
        "Swordmen, but Knights do not allow self-indulgence. There are those so obsessed with gaining strength that they cannot control themselves."
      )
      |> next()
      |> mes("[Sir Gray]")
      |> mes("So...")
      |> mes("What part of yourself")
      |> mes("are you not satisfied")
      |> mes("with right now?")
      |> next()
      |> select(["Skills.", "Goal.", "Appearance."])

    case choice do
      1 ->
        ctx =
          ctx
          |> mes("[Sir Gray]")
          |> mes(
            "Skill is something you gain with experience as a Knight. It cannot be your highest goal. Otherwise, you'll never be satisfied as a Knight."
          )
          |> next()

        {ctx, 10}

      2 ->
        ctx =
          ctx
          |> mes("[Sir Gray]")
          |> mes("I see...")
          |> mes(
            "Always having a goal is very important. You may be full of ideas upon becoming a Knight, but that may change with time."
          )
          |> next()

        {ctx, 0}

      3 ->
        ctx =
          ctx
          |> mes("[Sir Gray]")
          |> mes("Oh no...")
          |> mes(
            "What you see isn't what really counts. A Swordman may be stronger than a Knight, and even Knight may grow weak if he becomes lazy."
          )
          |> next()

        {ctx, 10}

      _ ->
        {ctx, 5}
    end
  end

  defp discuss_plans(ctx) do
    {ctx, choice} =
      select(ctx, [
        "I am going to go straight to battle.",
        "There are those waiting for me.",
        "I will learn more about Knights."
      ])

    case choice do
      1 -> discuss_battle(ctx)
      2 -> discuss_who_waits(ctx)
      3 -> discuss_learning(ctx)
      _ -> {ctx, 0}
    end
  end

  defp discuss_battle(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Sir Gray]")
      |> mes("Battle...?")
      |> mes("And then?")
      |> next()
      |> select([
        "I will grow within a short period of time.",
        "I would like to test my ability as a Knight.",
        "I would like to go to more challenging places."
      ])

    case choice do
      1 ->
        ctx =
          ctx
          |> mes("[Sir Gray]")
          |> mes("Don't be in too much of a hurry to become strong. Even if you become")
          |> mes("a Knight, you are still yourself.")
          |> next()

        {ctx, 10}

      2 ->
        ctx =
          ctx
          |> mes("[Sir Gray]")
          |> mes(
            "Testing yourself is a good thing. It's okay to be happy about how you change, but don't forget about the true qualities of being a Knight."
          )
          |> next()

        {ctx, 0}

      3 ->
        ctx =
          ctx
          |> mes("[Sir Gray]")
          |> mes(
            "Even if you become a Knight, you are not changing your inner self. No need to overwork yourself."
          )
          |> mes("Relax and take things step by step.")
          |> next()

        {ctx, 0}

      _ ->
        {ctx, 0}
    end
  end

  defp discuss_who_waits(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Sir Gray]")
      |> mes("Who is")
      |> mes("waiting for you?")
      |> next()
      |> select(["My friends.", "My Guild members.", "My Lover."])

    ctx =
      case choice do
        1 ->
          ctx
          |> mes("[Sir Gray]")
          |> mes(
            "I see, they would share in the joy of your achievements. Don't ever lose your kind heart, and always give help to your friends."
          )
          |> next()

        2 ->
          ctx
          |> mes("[Sir Gray]")
          |> mes(
            "Those who would share in your happiness and hardship. As a Knight, you must always protect them."
          )
          |> next()

        3 ->
          bless_lovers(ctx)

        _ ->
          ctx
      end

    {ctx, 0}
  end

  defp bless_lovers(ctx) do
    beloved = if sex(ctx) == get_char_var(ctx, :SEX_MALE, 0), do: "her", else: "him"

    ctx
    |> mes("[Sir Gray]")
    |> mes("Oh, youth!")
    |> mes("Becoming a Knight")
    |> mes("for your beloved!")
    |> mes("Always protect #{beloved}...")
    |> mes("Even at the sacrifice")
    |> mes("of your own life!")
    |> next()
    |> mes("[Sir Gray]")
    |> mes("Also...")
    |> mes("Love them forever.")
    |> mes("Sincere affection")
    |> mes("is hard to find.")
    |> next()
  end

  defp discuss_learning(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Sir Gray]")
      |> mes("Good attitude...")
      |> mes("What do you plan")
      |> mes("on learning?")
      |> next()
      |> select([
        "Comfortable places for Knights to go...",
        "The different paths of a Knight...",
        "Ways to get more money as a Knight..."
      ])

    case choice do
      1 ->
        ctx =
          ctx
          |> mes("[Sir Gray]")
          |> mes(
            "There are many places that are comfortable or uncomfortable in this world. However Knights must"
          )
          |> mes("be able to survive anywhere.")
          |> next()

        {ctx, 5}

      2 ->
        ctx =
          ctx
          |> mes("[Sir Gray]")
          |> mes(
            "There are many similar Knights outside in the world. Think of them as your seniors and ask many questions."
          )
          |> next()

        {ctx, 0}

      3 ->
        ctx =
          ctx
          |> mes("[Sir Gray]")
          |> mes(
            "Oh no. Do you hold wealth as a priority of being a Knight? We're not meant to be that way. Come again when you have thought"
          )
          |> mes("more about it...")
          |> next()

        {ctx, 15}

      _ ->
        {ctx, 0}
    end
  end

  defp judge_interview(ctx, points) do
    cond do
      points == 0 ->
        ctx
        |> pass_interview()
        |> mes(
          "I enjoyed talking with you. You remind me of myself as a young recruit. Shall we talk to the captain and decide on your"
        )
        |> mes("job change?")
        |> next()
        |> mes("[Sir Gray]")
        |> mes("Don't worry too")
        |> mes("much, I have a very")
        |> mes("high opinion of you.")
        |> mes("Now, go~")
        |> close()

      points == 5 ->
        ctx
        |> pass_interview()
        |> mes(
          "I enjoyed speaking with you. You can think about the principles of Knighthood more once you become a Knight."
        )
        |> next()
        |> mes("[Sir Gray]")
        |> mes(
          "Then, shall we go to the captain and decide on your job change? Don't worry too much. You are good enough to be a Knight!"
        )
        |> close()

      points == 10 ->
        ctx
        |> pass_interview()
        |> mes("I enjoyed talking with you. Although, there were some")
        |> mes("things that bothered me...")
        |> next()
        |> mes("[Sir Gray]")
        |> mes("You should go")
        |> mes("to the captain")
        |> mes("so we can decide")
        |> mes("on your job change.")
        |> next()
        |> mes("[Sir Gray]")
        |> mes(
          "Don't worry too much, coming to take my test means the others have acknowledged you as well."
        )
        |> mes("Go now...!")
        |> close()

      true ->
        ctx
        |> set_char_var(:KNIGHT_Q, 13)
        |> mes("[Sir Gray]")
        |> mes("Conversing")
        |> mes("with young ones")
        |> mes("is always enjoyable...")
        |> next()
        |> mes("[Sir Gray]")
        |> mes(
          "But it seems as though your dream is elsewhere, or that your focus is hazy. Spend more time as a Swordman, and come back"
        )
        |> mes("to me later.")
        |> next()
        |> mes("[Sir Gray]")
        |> mes(
          "If you truly wish to become a Knight, you must change your outlook first. Then, we shall see."
        )
        |> close()
    end
  end

  defp pass_interview(ctx) do
    ctx
    |> set_char_var(:KNIGHT_Q, 14)
    |> changequest(9011, 9012)
    |> mes("[Sir Gray]")
  end

  defp send_to_captain(ctx) do
    ctx
    |> mes("I told you")
    |> mes("to go to")
    |> mes("the captain.")
    |> next()
    |> mes("[Sir Gray]")
    |> mes("Everyone will")
    |> mes("carefully make")
    |> mes("their decision,")
    |> mes("so go now!")
    |> close()
  end

  defp redirect_early_candidate(ctx) do
    {ctx, choice} =
      ctx
      |> mes("Oh...")
      |> mes("A young Swordman.")
      |> mes("What can I do for you?")
      |> next()
      |> select(["I would like to take the test to change jobs.", "Oh, nothing."])

    if choice == 1 do
      ctx
      |> mes("[Sir Gray]")
      |> mes("Hoho~")
      |> mes("There are many")
      |> mes("other younger")
      |> mes("Knights in here.")
      |> next()
      |> mes("[Sir Gray]")
      |> mes("If you talk")
      |> mes("to all of them,")
      |> mes("I may review")
      |> mes("you as well.")
      |> close()
    else
      wish_good_health(ctx)
    end
  end

  defp wish_good_health(ctx) do
    ctx
    |> mes("[Sir Gray]")
    |> mes("Take care!")
    |> mes("Health is")
    |> mes("every man's")
    |> mes("treasure!")
    |> close()
  end
end
