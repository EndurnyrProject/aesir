defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21.Priest.HighBishop do
  @moduledoc """
  Bishop Paul, head of the Prontera Parish, who runs the Priest job change quest.

  ## Behavior

  - Turns away transcended characters, greets Novices and other visitors, and explains the
    Priesthood.
  - Lets Priests heal themselves or, with a Rosary, join an Acolyte's spiritual training.
  - Registers Acolytes of Job Level 40 or higher with no unused skill points and explains the
    Three Trials; Job Level 50 Acolytes skip the pilgrimage.
  - Tracks the pilgrimage, sends candidates to the spiritual training, and points them to
    Sister Cecilia for the oath.
  - Promotes candidates who swore the oath to Priest, clearing job quest variables and giving
    a book, or a bible at Job Level 50.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Pgro Team (OwNaGe)
    - kobra_k88
    - Lupus
    - Vicious
    - KarLaeda
    - L0ne_W0lf
    - Samuray22
    - Kisuka

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prt_church",
        x: 16,
        y: 41,
        dir: 4,
        sprite: 60,
        name: "High Bishop",
        scope: :shared,
        unique_name: "High Bishop#prst"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FClearjobvar
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      upper(ctx) == 1 ->
        ctx
        |> mes("[Bishop Paul]")
        |> mes("Hm...?")
        |> mes(
          "Ah, I sense that you are a warrior that has been to Valhalla. You who have been reborn... We are here to look after you."
        )
        |> next()
        |> mes("[Bishop Paul]")
        |> mes(
          "Do not let evil conquer your soul. You have enough courage and power to overcome the hardest situation. May God bless you..."
        )
        |> close()

      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:acolyte) ->
        quest_progress(ctx)

      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:priest) ->
        priest_visit(ctx)

      Rathena.job_id(base_class(ctx)) == Rathena.job_id(:novice) ->
        novice_visit(ctx)

      true ->
        visitor(ctx)
    end
  end

  defp male?(ctx), do: sex(ctx) == get_char_var(ctx, :SEX_MALE, 0)

  defp priest_visit(ctx) do
    ctx = ctx |> mes("[Bishop Paul]") |> mes("Ah...")

    ctx =
      if male?(ctx) do
        mes(
          ctx,
          "It is good to see you again, Brother #{char_name(ctx, 0)}. Once again, God's grace has caused our paths to cross."
        )
      else
        mes(
          ctx,
          "It is good to see you once again, Sister #{char_name(ctx, 0)}. The grace of God has brought you once more before me."
        )
      end

    {ctx, choice} =
      ctx
      |> next()
      |> mes("[Bishop Paul]")
      |> mes(
        "I'm pleased to see that you are continuing to lead the children of God on the right path. Is there anything I can help you with today?"
      )
      |> next()
      |> select([
        "How is your health?",
        "I want to help this Acolyte.",
        "Father, I need your help."
      ])

    priest_choice(choice, ctx)
  end

  defp priest_choice(1, ctx) do
    ctx
    |> mes("[Bishop Paul]")
    |> mes(
      "Thank you for your concern. I'm doing fine and am in good health. Please give my regards to your brothers and sisters."
    )
    |> next()
    |> mes("[Bishop Paul]")
    |> mes(
      "Keep in mind that we are God's messengers on this Earth. Always remember that we must always help others."
    )
    |> close()
  end

  defp priest_choice(2, ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Bishop Paul]")
      |> mes(
        "Ah, that's a good idea. Helping young Acolytes should also be one of a Priest's priorities."
      )
      |> next()
      |> mes("[Bishop Paul]")
      |> mes(
        "However, there are certain things that an Acolyte must do alone. All Acolytes must complete their divine test by themselves."
      )
      |> next()
      |> mes("[Bishop Paul]")
      |> mes(
        "I hope you will assist your Acolyte friend in the second test, the spiritual training."
      )
      |> next()
      |> mes("[Bishop Paul]")
      |> mes(
        "You need to bring ^0000FF1 Rosary^000000 in order to accompany an Acolyte in spiritual training. If you have one of those, I can send you to the test area now."
      )
      |> next()
      |> mes("[Bishop Paul]")
      |> mes("Do you wish to help him out during the spiritual training?")
      |> next()
      |> select(["Yes, I do.", "Give me a second."])

    cond do
      choice != 1 ->
        ctx
        |> mes("[Bishop Paul]")
        |> mes("I see, take your time. Don't forget to bring a ^0000FFRosary^000000...")
        |> close()

      count_item(ctx, 2608) > 0 ->
        ctx
        |> mes("[Bishop Paul]")
        |> mes(
          "I will now send you to the training place for Acolytes. Please send my regards to Brother Peter..."
        )
        |> next()
        |> mes("[Bishop Paul]")
        |> mes("I hope you will assist this Acolyte in becoming a Priest.")
        |> close()
        |> warp("job_prist", 26, 178)

      true ->
        ctx
        |> mes("[Bishop Paul]")
        |> mes(
          "Unfortunately you didn't bring a ^0000FFRosary^000000. You need one of those in order to be in the testing area."
        )
        |> close()
    end
  end

  defp priest_choice(3, ctx) do
    ctx
    |> mes("[Bishop Paul]")
    |> mes(
      "You must be strong. Have faith, as you are loved by God. I pray the wounds of the body are healed soon..."
    )
    |> next()
    |> percent_heal(hp: 90, sp: 0)
    |> mes("[Bishop Paul]")
    |> mes(
      "God, please look after your poor children. Help them overcome their hardships and difficulties. Refresh their spirits..."
    )
    |> next()
    |> percent_heal(hp: 0, sp: 90)
    |> mes("[Bishop Paul]")
    |> mes(
      "I hope my invocation has eased your pain. Now please go forth and spread God's message. May God be with you..."
    )
    |> close()
  end

  defp priest_choice(_, ctx), do: quest_progress(ctx)

  defp novice_visit(ctx) do
    ctx = ctx |> mes("[Bishop Paul]") |> mes("May God be")
    ctx = mes(ctx, if(male?(ctx), do: "with you, brother.", else: "with you, sister."))

    {ctx, choice} =
      ctx
      |> next()
      |> mes("[Bishop Paul]")
      |> mes("You are in")
      |> mes("the Sanctuary.")
      |> mes("What brings you here?")
      |> next()
      |> select([
        "I want to be an Acolyte.",
        "I want to be a Priest.",
        "Nothing, really."
      ])

    ctx =
      case choice do
        1 ->
          ctx
          |> mes("[Bishop Paul]")
          |> mes("Oh I see...")
          |> mes("If you wish to become an Acolyte, please visit the other room.")

        2 ->
          ctx
          |> mes("[Bishop Paul]")
          |> mes(
            "Oh I see. However, you must first become an Acolyte before becoming a Priest. Please visit the other room."
          )

        3 ->
          ctx
          |> mes("[Bishop Paul]")
          |> mes("Please make yourself at home. On Earth, nowhere is safer than this Sanctuary.")

        _ ->
          ctx
      end

    ctx |> next() |> mes("[Bishop Paul]") |> mes("May God bless you.") |> close()
  end

  defp visitor(ctx) do
    ctx = ctx |> mes("[Bishop Paul]") |> mes("May God be")
    ctx = mes(ctx, if(male?(ctx), do: "with you, brother.", else: "with you, sister."))

    {ctx, choice} =
      ctx
      |> next()
      |> mes("[Bishop Paul]")
      |> mes("What brings you here")
      |> mes("to Prontera Sanctuary?")
      |> next()
      |> select(["Information about Priests.", "Nothing."])

    ctx =
      case choice do
        1 ->
          ctx
          |> mes("[Bishop Paul]")
          |> mes("Priests have the authority to perform and administer religious rites.")
          |> next()
          |> mes("[Bishop Paul]")
          |> mes(
            "You must first be thoroughly disciplined as an Acolyte before you can be promoted to the position of Priest."
          )
          |> next()
          |> mes("[Bishop Paul]")
          |> mes(
            "When you reach Acolyte Job level 40, you will be able to apply for the Priest test."
          )
          |> next()
          |> mes("[Bishop Paul]")
          |> mes(
            "If you pass the test, you will be able to use more powerful skills that will be effective against Demon and Undead creatures..."
          )
          |> next()
          |> mes("[Bishop Paul]")
          |> mes(
            "With all of your ability, you will play an important role in towns and dungeons."
          )
          |> next()
          |> mes("[Bishop Paul]")
          |> mes(
            "Our duty and obligation as Priests is to devote ourselves to helping others without expecting reward."
          )
          |> next()
          |> mes("[Bishop Paul]")
          |> mes(
            "As we help others, we must not expect to treat us in a similar fashion. To be a great Priest is your choice and responsibility, not anyone else's."
          )
          |> next()
          |> mes("[Bishop Paul]")
          |> mes(
            "However, those who receive should be polite. You should give an outstanding example, but you should also have your limits as a human."
          )
          |> next()
          |> mes("[Bishop Paul]")
          |> mes(
            "I hope I explained enough of the class. Why don't you go outside and talk to some of the other Priests if you want to learn more about our way of life?"
          )
          |> next()

        2 ->
          ctx
          |> mes("[Bishop Paul]")
          |> mes(
            "Please make yourself at home. Nowhere on Earth is safer than the Prontera Sanctuary."
          )
          |> next()

        _ ->
          ctx
      end

    ctx
    |> mes("[Bishop Paul]")
    |> mes("Well...")
    |> mes("May God")
    |> mes("bless you.")
    |> close()
  end

  defp quest_progress(ctx) do
    case get_char_var(ctx, :PRIEST_Q, 0) do
      0 -> first_visit(ctx)
      1 -> pilgrimage_reminder(ctx)
      2 -> after_rubalkabara(ctx)
      3 -> after_mathilda(ctx)
      4 -> pilgrimage_done(ctx)
      5 -> training_ready(ctx)
      6 -> training_retry(ctx)
      7 -> after_training(ctx)
      8 -> oath_pending(ctx)
      9 -> promotion(ctx)
      _ -> ctx
    end
  end

  defp first_visit(ctx) do
    ctx = ctx |> mes("[Bishop Paul]") |> mes("May God bless")
    ctx = mes(ctx, if(male?(ctx), do: "you, Brother.", else: "you, Sister."))

    {ctx, choice} =
      ctx
      |> mes("What brings")
      |> mes("you to me?")
      |> next()
      |> select(["I want to be a Priest.", "How are you, Father?"])

    case choice do
      1 ->
        apply_for_priest(ctx)

      2 ->
        ctx =
          ctx
          |> mes("[Bishop Paul]")
          |> mes("I see...")
          |> mes("I am doing fine")
          |> mes("and am in good health.")
          |> mes("Thank you for asking.")
          |> next()
          |> mes("[Bishop Paul]")

        ctx =
          if male?(ctx) do
            mes(
              ctx,
              "I hope you will continue to go on your mission as God's servant, brother."
            )
          else
            mes(
              ctx,
              "I hope you will continue to go on your mission as God's servant, sister."
            )
          end

        ctx
        |> next()
        |> mes("[Bishop Paul]")
        |> mes("Hopefully, our paths")
        |> mes("will cross again.")
        |> mes("May God bless you...")
        |> close()

      _ ->
        ctx
    end
  end

  defp apply_for_priest(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Bishop Paul]")
      |> mes(
        "I see. So you wish to be a Priest. God will be delighted by your decision and will bless you."
      )
      |> next()
      |> mes("[Bishop Paul]")
      |> mes("I am Bishop Paul Cervantes, and am in charge of the Prontera Parish.")
      |> mes("I am glad to meet a person as eager and devoted to God such as yourself.")
      |> next()
      |> mes("[Bishop Paul]")
      |> mes(
        "If you set your mind on becoming a Priest, you must undergo several tests. Only Acolytes who reach job level 40 are qualified for testing."
      )
      |> next()
      |> mes("[Bishop Paul]")
      |> mes(
        "If you satisfy the requirements, I suggest that you apply for the Priest job first. Do you wish to apply now?"
      )
      |> next()
      |> select(["Yes, I do.", "I need some time to think about it..."])

    cond do
      choice != 1 ->
        ctx
        |> mes("[Bishop Paul]")
        |> mes("Please take your time.")
        |> mes("You are always welcomed.")
        |> mes("May God bless you...")
        |> close()

      job_level(ctx) < 40 ->
        ctx
        |> mes("[Bishop Paul]")
        |> mes(
          "You are not yet qualified to be a Priest. Please go out into the world and broaden your experiences."
        )
        |> next()
        |> mes("[Bishop Paul]")
        |> mes(
          "There are still things that you must learn as an Acolyte. However, I look forward to meeting you again very soon."
        )
        |> close()

      Rathena.truthy?(skill_point(ctx)) ->
        ctx
        |> mes("[Bishop Paul]")
        |> mes("You have skill points left.")
        |> mes(
          "I strongly recommend that you use all of these skill points before you apply for the Priest job change test."
        )
        |> close()

      true ->
        explain_trials(ctx)
    end
  end

  defp explain_trials(ctx) do
    ctx = ctx |> set_char_var(:PRIEST_Q, 1) |> setquest(8009) |> mes("[Bishop Paul]")
    sibling = if male?(ctx), do: "Brother", else: "Sister"

    ctx =
      ctx
      |> mes(
        "Now I will explain the Three Trials of Priesthood. These tribulations will bring you much suffering, but I hope you can complete them, #{sibling} #{char_name(ctx, 0)}."
      )
      |> next()
      |> mes("[Bishop Paul]")
      |> mes(
        "For the First Trial, you will make a pilgrimage, and visit three acscetic Priests in a specific order."
      )
      |> next()
      |> mes("[Bishop Paul]")
      |> mes(
        "The Second Trial will consist of spiritual training. You must resist the temptations of Demons and the Undead."
      )
      |> next()
      |> mes("[Bishop Paul]")
      |> mes(
        "In the Final Trial, you will promise your devotion to God. Your willingness to sacrifice yourself will also be questioned."
      )
      |> next()
      |> mes("[Bishop Paul]")
      |> mes(
        "Acolytes that have reached Job Level 50 will be exempt from the First Trial, the pilgrimage, as they have already demonstrated their enthusiasm and devotion."
      )
      |> next()

    if job_level(ctx) == 50, do: skip_pilgrimage(ctx), else: pilgrimage_order(ctx)
  end

  defp skip_pilgrimage(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Bishop Paul]")
      |> mes(
        "I can see the great effort you have exerted to reach job level 50. You have been a loyal servant to God."
      )
      |> next()
      |> mes("[Bishop Paul]")
      |> mes(
        "Now, you may go directly go to the Second Trial: Spiritual Training. For this training, you may bring a Priest with you."
      )
      |> next()
      |> mes("[Bishop Paul]")
      |> mes(
        "I have no doubt that you will do a good job by yourself. However, it will be easier with the aid of a Brother or Sister that has already become a Priest."
      )
      |> next()
      |> set_char_var(:PRIEST_Q, 5)
      |> changequest(8009, 8011)
      |> mes("[Bishop Paul]")
      |> mes("Well, are you ready for the Spiritual Training?")
      |> next()
      |> select(["I am ready.", "Give me a minute."])

    if choice == 1 do
      send_to_training(ctx)
    else
      ctx
      |> mes("[Bishop Paul]")
      |> mes("No problem, take your time.")
      |> mes("May God give you the strength to overcome your fears...")
      |> close()
    end
  end

  defp pilgrimage_order(ctx) do
    ctx
    |> mes("[Bishop Paul]")
    |> mes(
      "Well, let me tell you the order of the ascetic Priests that you must visit for your pilgrimage."
    )
    |> next()
    |> mes("[Bishop Paul]")
    |> mes("First, please visit Father")
    |> mes("Rubalkabara who is Northeast")
    |> mes("of the Prontera Ruins.")
    |> next()
    |> mes("[Bishop Paul]")
    |> mes("Second, please visit Sister Mathilda. She is located in")
    |> mes("an area near Morocc, Southwest of Prontera.")
    |> next()
    |> mes("[Bishop Paul]")
    |> mes(
      "The third Priest you must visit is Father Yosuke. He is in a field Northwest of Prontera."
    )
    |> next()
    |> mes("[Bishop Paul]")
    |> mes(
      "Well then, I wish you a safe journey. If you have any questions, please ask Sister Cecilia."
    )
    |> next()
    |> mes("[Bishop Paul]")
    |> mes("When you return from your pilgrimage, I will let you know")
    |> mes("of the next test.")
    |> next()
    |> mes("[Bishop Paul]")
    |> mes("May God")
    |> mes("bless you...")
    |> changequest(8009, 8010)
    |> close()
  end

  defp pilgrimage_reminder(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Bishop Paul]")
      |> mes(
        "May I ask you the reason you're still here? You didn't forget your pilgrimage, did you?"
      )
      |> next()
      |> select(["Sorry father, I need to check the order.", "No no no, not at all."])

    if choice == 1 do
      ctx
      |> mes("[Bishop Paul]")
      |> mes(
        "Ah, I see. I will let you know the order of pilgrimage again, and hope that you will have a safe journey."
      )
      |> next()
      |> mes("[Bishop Paul]")
      |> mes("First, meet Father Rubalkabara. He's at the Northeast of the Prontera ruins.")
      |> next()
      |> mes("[Bishop Paul]")
      |> mes(
        "Then, remember to meet Sister Mathilda. She's somewhere near the town of Morocc, Southwest of Prontera."
      )
      |> next()
      |> mes("[Bishop Paul]")
      |> mes(
        "And lastly, please seek out Father Yosuke. He is in the a field Northwest of Prontera."
      )
      |> next()
      |> mes("[Bishop Paul]")
      |> mes(
        "Well then, I shall pray for your safe journey. If you want more information, please ask Sister Cecilia."
      )
      |> next()
      |> mes("[Bishop Paul]")
      |> mes("When you get back from the pilgrimage, I will let you know the next test.")
      |> next()
      |> mes("[Bishop Paul]")
      |> mes("May God bless you...")
      |> close()
    else
      ctx
      |> mes("[Bishop Paul]")
      |> mes(
        "I see. But still, if you have any questions, you may wish to ask Sister Cecilia. She will address any of your concerns."
      )
      |> next()
      |> mes("[Bishop Paul]")
      |> mes("Well then, I shall pray for your safe journey. May God bless you...")
      |> close()
    end
  end

  defp after_rubalkabara(ctx) do
    ctx
    |> mes("[Bishop Paul]")
    |> mes(
      "I see you have returned from your meeting with Father Rubalkabara. How is he doing? I am worried about his health, since he's been there all alone... "
    )
    |> next()
    |> mes("[Bishop Paul]")
    |> mes(
      "For your next quest, you should meet Sister Mathilda. I shall be awaiting your safe return."
    )
    |> close()
  end

  defp after_mathilda(ctx) do
    ctx
    |> mes("[Bishop Paul]")
    |> mes(
      "I see that you have returned from your journey to meet Sister Mathilda. She has been meditating in the hot, dry desert for a long time."
    )
    |> next()
    |> mes("[Bishop Paul]")
    |> mes(
      "Finally, it is now time for you to meet Father Yosuke. He is doing penance somewhere around a field Northwest of Prontera. Please seek him out, and then return here to me."
    )
    |> close()
  end

  defp pilgrimage_done(ctx) do
    {ctx, choice} =
      ctx
      |> set_char_var(:PRIEST_Q, 5)
      |> changequest(8010, 8011)
      |> mes("[Bishop Paul]")
      |> mes("You've accomplished")
      |> mes("your pilgrimage.")
      |> mes("Congratulations.")
      |> next()
      |> mes("[Bishop Paul]")
      |> mes(
        "Now it is time to begin your spiritual training. As I mentioned before, you may bring a Priest to help you during this training."
      )
      |> next()
      |> mes("[Bishop Paul]")
      |> mes(
        "Although you cannot receive their help throughout all of the testing, they can at least help you during the spiritual training."
      )
      |> next()
      |> mes("[Bishop Paul]")
      |> mes("Well, are you ready for")
      |> mes("the spiritual training?")
      |> next()
      |> select(["I'm ready.", "Give me a minute."])

    if choice == 1, do: send_to_training(ctx), else: take_your_time(ctx)
  end

  defp training_ready(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Bishop Paul]")
      |> mes("You seem confident about the spiritual training. Shall we begin?")
      |> next()
      |> select(["I'm ready.", "Give me a minute."])

    if choice == 1, do: send_to_training(ctx), else: take_your_time(ctx)
  end

  defp training_retry(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Bishop Paul]")
      |> mes(
        "You look tired and exhausted. However, you must endure even more suffering once you become a Priest."
      )
      |> next()
      |> mes("[Bishop Paul]")
      |> mes(
        "Please endure these trials for the sake of your dream. Why don't you challenge the spiritual training again?"
      )
      |> next()
      |> select(["I'll try again.", "Give me a minute."])

    if choice == 1 do
      ctx
      |> mes("[Bishop Paul]")
      |> mes(
        "Good. I will send you to the training ground. Please ask for help from Brother Peter."
      )
      |> next()
      |> warp("job_prist", 24, 180)
    else
      take_your_time(ctx)
    end
  end

  defp send_to_training(ctx) do
    ctx
    |> mes("[Bishop Paul]")
    |> mes(
      "Good. I will send you to the training ground. When you get there, please speak to Brother Peter who is in charge of the training."
    )
    |> next()
    |> warp("job_prist", 24, 180)
  end

  defp take_your_time(ctx) do
    ctx
    |> mes("[Bishop Paul]")
    |> mes("No problem,")
    |> mes("take your time.")
    |> mes("May God grant you")
    |> mes("the strength to")
    |> mes("overcome your fears...")
    |> close()
  end

  defp after_training(ctx) do
    ctx
    |> mes("[Bishop Paul]")
    |> mes(
      "I am glad that you've done well with the spiritual training. Congratulations. You are now qualified to be called a Priest."
    )
    |> next()
    |> mes("[Bishop Paul]")
    |> mes(
      "Now, you must go and swear your devotion to God with Sister Cecilia. Don't be nervous..."
    )
    |> next()
    |> mes("[Bishop Paul]")
    |> mes(
      "Just answer honestly, and listen to the voice of God that speaks quietly in your heart."
    )
    |> next()
    |> mes("[Bishop Paul]")
    |> mes("Well then...")
    |> mes("I will be here")
    |> mes("waiting for you.")
    |> close()
  end

  defp oath_pending(ctx) do
    ctx
    |> mes("[Bishop Paul]")
    |> mes(
      "Hmm? You haven't made your oath yet...? Without the conviction of an oath to God, you may be tempted by evil at anytime."
    )
    |> next()
    |> mes("[Bishop Paul]")
    |> mes(
      "You should go to sister Cecilia and promise your devotion to God. Return here with honor, and listen to the voice of God that speaks quietly in your heart."
    )
    |> close()
  end

  defp promotion(ctx) do
    if Rathena.truthy?(skill_point(ctx)) do
      ctx
      |> mes("[Bishop Paul]")
      |> mes(
        "You have remaining skills points. Please use these skill points to upgrade your skills, and then return to me."
      )
      |> close()
    else
      change_to_priest(ctx)
    end
  end

  defp change_to_priest(ctx) do
    ctx =
      ctx
      |> mes("[Bishop Paul]")
      |> mes(
        "Congratulations, you have completed the trials required of all Priests. Let me promote you to the position of Priest right away."
      )
      |> next()
      |> mes("[Bishop Paul]")
      |> mes("God, grant your power to your servant standing before you.")
      |> changequest(8015, 8016)

    pronoun = if male?(ctx), do: "him", else: "her"

    ctx =
      ctx
      |> mes("Let #{pronoun} send your message throughout the ends of the earth.")
      |> next()
      |> mes("[Bishop Paul]")
      |> mes("Make this servant of yours an instrument of your miraculous works...")
      |> next()

    job_level_before_change = if match?({:error, _}, ctx.status), do: 0, else: job_level(ctx)

    {ctx, _} =
      ctx
      |> completequest(8016)
      |> jobchange(:priest)
      |> FClearjobvar.call([])

    ctx =
      ctx
      |> mes("[Bishop Paul]")
      |> mes(
        "Now you are born again as a Priest. I congratulate you, and hope you will greatly help other people for the rest of your life."
      )
      |> next()
      |> mes("[Bishop Paul]")

    ctx =
      if job_level_before_change < 50 do
        ctx
        |> give_item(1550, 1)
        |> mes(
          "This book is for you. I hope it will aid you in spreading God's message on earth."
        )
      else
        ctx
        |> give_item(1551, 1)
        |> mes(
          "In commemoration of your job change, I am giving you a bible. This will lighten your way to the path of righteousness."
        )
      end

    ctx
    |> next()
    |> mes("[Bishop Paul]")
    |> mes(
      "You've shown great effort, and have made admirable progress in your personal quest for holiness. Please lead your life as a sincere Priest..."
    )
    |> close()
  end
end
