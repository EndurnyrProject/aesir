defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22.Monk.SenseiMoohae do
  @moduledoc """
  Sensei Moohae, who opens and concludes the Monk job quest.

  ## Behavior

  - Refuses to proceed while the player has unspent skill points.
  - Assigns job level 40+ Acolytes a random item-gathering task and takes the items on return.
  - Points candidates to their next trial while their training is in progress.
  - Questions candidates on the monk's vows and changes them into Monks when they answer correctly.
  - Gives new Monks a Waghnak, or Knuckle Dusters when they changed job at job level 50.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Dino9021
    - Celest
    - L0ne_W0lf
    - Samuray22
    - Kisuka
    - Lupus
    - Yor
    - Zephiris
    - Vicious
    - Silent

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "monk_in",
        x: 99,
        y: 58,
        dir: 1,
        sprite: 60,
        name: "Sensei Moohae",
        scope: :shared,
        unique_name: "Sensei Moohae#mk"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FClearjobvar
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @tasks %{
    3 => {3017, [{938, 5}, {1055, 10}, {511, 20}]},
    4 => {3018, [{942, 20}, {1002, 5}, {510, 3}]},
    5 => {3019, [{905, 30}, {909, 5}, {955, 10}]},
    6 => {3020, [{943, 5}, {935, 20}, {912, 5}]},
    7 => {3021, [{7053, 5}, {509, 10}, {508, 10}]},
    8 => {3022, [{913, 10}, {948, 5}, {7033, 20}]},
    9 => {3023, [{1027, 5}, {1025, 20}, {1042, 10}]}
  }

  @touha_directions [
    "Let's see who is to see you next..",
    "Ah... go find elder Touha.",
    "He is in the north west."
  ]

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx =
      ctx
      |> mes("[Sensei Moohae]")
      |> mes("Greetings, you seem to be on a pure path.")
      |> mes("Come in, come in, what can I do for you today?")
      |> next()

    if Rathena.truthy?(skill_point(ctx)) do
      ctx
      |> mes("[Sensei Moohae]")
      |> mes("If you have free skill points, you will lose them during a job change.")
      |> mes("Make sure to use any skill points you have.")
      |> close()
    else
      respond_to_progress(ctx)
    end
  end

  defp respond_to_progress(ctx) do
    quest = get_char_var(ctx, :MONK_Q, 0)
    task_stage = Enum.find(3..9, &(&1 == quest))

    cond do
      acolyte?(ctx) and quest == 2 and job_level(ctx) > 39 ->
        offer_training(ctx)

      task_stage ->
        review_task(ctx, task_stage)

      quest > 9 and quest < 14 ->
        ctx
        |> mes("[Sensei Moohae]")
        |> mes("I told you already.")
        |> mes("Go find ^CC0000Touha^000000.")
        |> mes("He is a little north west of here.")
        |> close()

      quest > 13 and quest < 26 ->
        ctx
        |> mes("[Sensei Moohae]")
        |> mes("Oh, are you still in the process of training?")
        |> mes("Hurry and finish!")
        |> close()

      quest > 25 and quest < 27 ->
        ctx
        |> mes("[Sensei Moohae]")
        |> mes("I hear good things coming from your training.")
        |> mes("Good luck and work hard. You will do great things as a monk.")
        |> close()

      quest == 27 and acolyte?(ctx) ->
        ctx
        |> mes("[Sensei Moohae]")
        |> mes(".......Hmmm.....")
        |> mes(
          "Go to Tomoon, get a special potion from him. It will look like a green potion, but it isn't. Bring it to me..."
        )
        |> close()

      quest == 28 and acolyte?(ctx) ->
        check_potion(ctx)

      acolyte?(ctx) ->
        ctx
        |> mes("[Sensei Moohae]")
        |> mes("You are...an acolyte..?")
        |> mes(
          "If you seek consultation, go to the Sanctuary in Prontera. This place is for Monks, not for you."
        )
        |> mes("Unless you intend to become a monk....please leave.")
        |> close()

      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:monk) ->
        ctx
        |> mes("[Sensei Moohae]")
        |> mes("How's your practice going?")
        |> mes("I hope you are still training and keeping your vows.")
        |> next()
        |> mes("[Sensei Moohae]")
        |> mes("We must always continue our training in life and stay true to our path.")
        |> mes("Otherwise evil will come and taint our mind with impurities.")
        |> next()
        |> mes("[Sensei Moohae]")
        |> mes("Don't forget your vows, stay on your path and")
        |> mes("do not let any evil taint your pure heart.")
        |> close()

      true ->
        ctx
        |> mes("[Sensei Moohae]")
        |> mes("If you seek consultation, go to the Sanctuary in Prontera.")
        |> mes(
          "We do not have anything of interest to you here, please leave and do not disturb the other monks."
        )
        |> close()
    end
  end

  defp offer_training(ctx) do
    {ctx, answer} =
      ctx
      |> mes("[Sensei Moohae]")
      |> mes("I sense a fighting spirit, do you wish to become a monk? ")
      |> next()
      |> select(["Yes.", "No."])

    if answer == 2 do
      ctx
      |> mes("[Sensei Moohae]")
      |> mes("My apologies... It has been some time since")
      |> mes("I have sensed someone with your strength.")
      |> mes("I hope you find your path young one.")
      |> close()
    else
      ctx
      |> mes("[Sensei Moohae]")
      |> mes("There are still those who wish to follow the old ways.")
      |> mes_by_sex(
        "A strong young man. I am pleased of your will to join us.",
        "Such a delicate flower. I am pleased to see your will to join us."
      )
      |> next()
      |> mes("[Sensei Moohae]")
      |> mes("Oh, you are the new pupil that wishes to join us...")
      |> mes("Well there are a few things that you should know prior to beginning your training.")
      |> next()
      |> mes("[Sensei Moohae]")
      |> mes("We monks are on a path of inner peace and enlightenment.")
      |> mes("We strive to bring such peace to all others with great care.")
      |> next()
      |> mes("[Sensei Moohae]")
      |> mes("We monks achieve this from mental and physical training.")
      |> mes("We search for enlightenment in our surroundings and in nature.")
      |> next()
      |> mes("[Sensei Moohae]")
      |> mes("It is, of course, important to always keep our original faith in God.")
      |> next()
      |> mes("[Sensei Moohae]")
      |> mes(
        "This is not an easy life and the true test of becoming a monk is having the ability to endure all of which I said..."
      )
      |> mes(
        "The life of a monk is not for everybody, only those strong enough can become a monk."
      )
      |> next()
      |> mes("[Sensei Moohae]")
      |> mes("Now, that you understand all of this,")
      |> mes("prepare yourself to train")
      |> mes("your strength and spirit.")
      |> next()
      |> mes("[Sensei Moohae]")
      |> mes("Let us start with a simple task.")
      |> next()
      |> assign_task(Enum.random(1..7) + 2)
    end
  end

  defp assign_task(ctx, stage) do
    {quest_id, [first, second, third]} = Map.fetch!(@tasks, stage)

    ctx
    |> changequest(3016, quest_id)
    |> mes("[Sensei Moohae]")
    |> mes(item_request(first, ","))
    |> mes(item_request(second, ","))
    |> mes(item_request(third, "."))
    |> mes("Find these items and return to me.")
    |> set_char_var(:MONK_Q, stage)
    |> next()
    |> mes("[Sensei Moohae]")
    |> mes(task_encouragement(stage))
    |> next()
    |> mes("[Sensei Moohae]")
    |> mes(
      "If you are unable to return with these items, you are not yet ready to become a monk."
    )
    |> mes("Be sure to collect all the items I listed.")
    |> mes("May God be with you.")
    |> close()
  end

  defp item_request({item_id, amount}, punctuation) do
    amount
    |> Rathena.concat(" ")
    |> Rathena.concat(Rathena.getitemname(item_id))
    |> Rathena.concat(punctuation)
  end

  defp task_encouragement(3), do: "Why the face? This is a test of your abilities."
  defp task_encouragement(4), do: "What's wrong? This is a test of your abilities."

  defp task_encouragement(5),
    do: "You do understand don't you? This is a test of your abilities."

  defp task_encouragement(6), do: "Don't look at me like that. This is a test of your abilities."

  defp task_encouragement(7),
    do:
      "You don't seem concerned, this is a test of your abilities You should take this seriously."

  defp task_encouragement(8),
    do: "It is a test of your abilities so make sure you acquire these on your own."

  defp task_encouragement(9),
    do: "Don't be concerned, I believe you can do it. This is only to test your abilities."

  defp review_task(ctx, stage) do
    {quest_id, items} = Map.fetch!(@tasks, stage)
    lines = task_review_lines(stage)
    ctx = ctx |> mes("[Sensei Moohae]") |> mes(lines.greeting) |> next()

    if Enum.all?(items, fn {item_id, amount} -> count_item(ctx, item_id) >= amount end) do
      ctx
      |> mes("[Sensei Moohae]")
      |> mes(lines.praise)
      |> mes("I will tell this to the elders.")
      |> set_char_var(:MONK_Q, 10)
      |> changequest(quest_id, 3024)
      |> remove_items(items)
      |> next()
      |> mes("[Sensei Moohae]")
      |> mes_lines(lines.directions)
      |> close()
    else
      ctx
      |> mes("[Sensei Moohae]")
      |> mes(lines.complaint)
      |> mes("You do not have what I asked for!")
      |> mes_lines(lines.shopping_list)
      |> mes("These are the items I require, go find them all.")
      |> close()
    end
  end

  defp task_review_lines(3) do
    %{
      greeting: "You are back, did you bring what I asked?",
      praise: "Well done, you found all the items.",
      directions: @touha_directions,
      complaint: "How can you think to be done?",
      shopping_list: ["5 Sticky Mucus,", "10 Earthworm Peeling,", "20 Green Herb."]
    }
  end

  defp task_review_lines(4) do
    %{
      greeting: "...eh?",
      praise: "Very good, you found all the items.",
      directions: @touha_directions,
      complaint: "Why did you return?",
      shopping_list: ["20 Yoyo Tail,", "5 Iron Ore,", "3 Blue Herb."]
    }
  end

  defp task_review_lines(5) do
    %{
      greeting: "Hmm?",
      praise: "See, that wasn't so bad you real found all the items.",
      directions: ["The next step will be given", "to you by Touha.", "He is in the north west."],
      complaint: "How can you think to be done?",
      shopping_list: ["30 Stem,", "5 Jellopy", "10 Worm Peelings"]
    }
  end

  defp task_review_lines(6) do
    %{
      greeting: "I have been waiting for you.",
      praise: "Impressive, you really found all the items.",
      directions: [
        "Your next step will be with..",
        "elder Touha. Go find him.",
        "He is in the north west."
      ],
      complaint: "How can you think to be done?",
      shopping_list: ["5 Solid Shell,", "20 Shell,", "5 Zargon."]
    }
  end

  defp task_review_lines(7) do
    %{
      greeting: "Hello again. Back so soon?",
      praise: "Very nice, you found all the items.",
      directions: @touha_directions,
      complaint: "Where are the items...?",
      shopping_list: ["5 Cyfar,", "10 White Herb,", "10 Yellow Herb."]
    }
  end

  defp task_review_lines(8) do
    %{
      greeting: "Hmm?",
      praise: "Excellent, all the items I asked for.",
      directions: @touha_directions,
      complaint: "How can you think to be done?",
      shopping_list: ["10 Tooth of Bat,", "5 Bear's Foot skin", "20 Poison Spore"]
    }
  end

  defp task_review_lines(9) do
    %{
      greeting: "Welcome back.",
      praise: "Wow, you found all the items!!",
      directions: @touha_directions,
      complaint: "How can you think to be done?",
      shopping_list: ["5 Porcupine Quill,", "20 Cobweb,", "10 Bug Leg."]
    }
  end

  defp check_potion(ctx) do
    potions = count_item(ctx, 506)

    cond do
      potions > 0 ->
        ctx
        |> mes("[Sensei Moohae]")
        |> mes("Do you still have the medicine you were supposed to bring?")
        |> mes("You must drink that green potion to strengthen yourself for becoming a monk.")
        |> close()

      potions == 0 ->
        vow_purity(ctx)

      true ->
        close(ctx)
    end
  end

  defp vow_purity(ctx) do
    {ctx, answer} =
      ctx
      |> mes("[Sensei Moohae]")
      |> mes("Have you finished the task? Good, so you do have what it takes to become a monk.")
      |> mes("You didn't throw away the precious potion did you?")
      |> next()
      |> mes("[Sensei Moohae]")
      |> mes("The potion you drank earlier must be taking its effect by now.")
      |> mes("Now that you drank the potion your training to become a monk will begin shortly...")
      |> next()
      |> mes("[Sensei Moohae]")
      |> mes("But first, answer me these questions.")
      |> mes("Do you dedicate the remainder of your life to the pursuit of purity?")
      |> ask_yes_no()

    if answer == 2 do
      ctx
      |> mes("[Sensei Moohae]")
      |> mes("....with that kind of reply...")
      |> mes("Have you not enough heart to become a monk?")
      |> mes("Do you feel you have not suffered enough?")
      |> next()
      |> mes("[Sensei Moohae]")
      |> mes("Think about it a little more and return!")
      |> mes("We cannot accept a monk who is tainted with doubt...")
      |> close()
    else
      vow_selflessness(ctx)
    end
  end

  defp vow_selflessness(ctx) do
    {ctx, answer} =
      ctx
      |> mes("[Sensei Moohae]")
      |> mes(
        "Will you take advantage of the abilities gained through our training to use for personal benefit?"
      )
      |> ask_yes_no()

    if answer == 1 do
      ctx
      |> mes("[Sensei Moohae]")
      |> mes(
        "...then we cannot accept you as a monk. We, monks do not practice for personal benefit."
      )
      |> mes("We lead our lives honorably and as holy executioners to the damned.")
      |> next()
      |> mes("[Sensei Moohae]")
      |> mes("Go back where you're from and reconsider what it means to be a monk...")
      |> mes(
        "How you stand before me now, you will never last as a monk and will be tainted by that which is evil..."
      )
      |> close()
    else
      vow_justice(ctx)
    end
  end

  defp vow_justice(ctx) do
    {ctx, answer} =
      ctx
      |> mes("[Sensei Moohae]")
      |> mes("Will you punishing those who are against")
      |> mes("veritas and aequitas? ^CCCCCC(Truth and Justice)^000000")
      |> ask_yes_no()

    if answer == 2 do
      ctx
      |> mes("[Sensei Moohae]")
      |> mes("Who do you think we, the monks are for!")
      |> mes("Any creature that is against the will of such spawns from the dregs of the world!")
      |> mes("They are not worthy to exist!")
      |> next()
      |> mes("[Sensei Moohae]")
      |> mes("Return when you are ready to face and eliminate that which is evil.")
      |> mes("Then you will know what you have to do next without my instructions.")
      |> close()
    else
      vow_cooperation(ctx)
    end
  end

  defp vow_cooperation(ctx) do
    {ctx, answer} =
      ctx
      |> mes("[Sensei Moohae]")
      |> mes(
        "Will you cooperate with others who have the same goal as yours and sacrifice yourself as a means to an end?"
      )
      |> ask_yes_no()

    if answer == 2 do
      ctx
      |> mes("[Sensei Moohae]")
      |> mes("Did you say no...? This is unacceptable...")
      |> mes(
        "If you can help your comrades by sacrificing yourself that is a true display of purity."
      )
      |> next()
      |> mes("[Sensei Moohae]")
      |> mes(
        "Go back and contemplate upon what it means to sacrifice yourself for those you care for."
      )
      |> mes(
        "Sacrificing yourself for others may seem easy, but it's the most difficult thing to do as a human being."
      )
      |> close()
    else
      vow_no_mob_trains(ctx)
    end
  end

  defp vow_no_mob_trains(ctx) do
    {ctx, answer} =
      ctx
      |> mes("[Sensei Moohae]")
      |> mes("Will you assist your comrades by gathering monsters to follow you?")
      |> ask_yes_no()

    if answer == 1 do
      ctx
      |> mes("[Sensei Moohae]")
      |> mes(
        "That is not acceptable. Purposely taunting monsters to follow you can be very dangerous and harmful to others. This is not the way of a monk."
      )
      |> mes("... that behavior is regarded as careless and is not tolerated.")
      |> next()
      |> mes("[Sensei Moohae]")
      |> mes(
        "Even though you may be nearly invincible when hardening your body that skill is meant to be used for emergency situation not to be used for such disrespectful use!"
      )
      |> next()
      |> mes("[Sensei Moohae]")
      |> mes("You might feel that's helping others, but it's not true.")
      |> mes("Consider what it is you must do as a monk for others again.")
      |> close()
    else
      vow_no_shouting(ctx)
    end
  end

  defp vow_no_shouting(ctx) do
    {ctx, answer} =
      ctx
      |> mes("[Sensei Moohae]")
      |> mes("Will you yell and shout the same things over and over again in towns or in fields?")
      |> ask_yes_no()

    if answer == 1 do
      ctx
      |> mes("[Sensei Moohae]")
      |> mes("You are not allowed to do so. This doesn't apply only to monks but to everyone.")
      |> mes("Nobody wants their peace disturbed!")
      |> mes("Even if you mean well by it, it is disrespectful and not allowed.")
      |> close()
    else
      vow_sacrifice(ctx)
    end
  end

  defp vow_sacrifice(ctx) do
    {ctx, answer} =
      ctx
      |> mes("[Sensei Moohae]")
      |> mes("Are you willing to die for others on your monk's path of being a holy executioner?")
      |> ask_yes_no()

    if answer == 2 do
      ctx
      |> mes("[Sensei Moohae]")
      |> mes("You cannot become a monk with such an attitude!!!")
      |> mes(
        "If we can eliminate at least one more enemy of ours by sacrificing ourselves, that's what is expected of you as a holy executioner in whom we are trained to be."
      )
      |> next()
      |> mes("[Sensei Moohae]")
      |> mes("If you are unwilling to sacrifice yourself for those you care about,")
      |> mes("how can you expect to reach true enlightenment?")
      |> mes("Ponder upon the real meaning of life and death!!")
      |> close()
    else
      swear_oath(ctx)
    end
  end

  defp swear_oath(ctx) do
    {ctx, answer} =
      ctx
      |> mes("Lastly, make your oath that you will keep these vows.")
      |> next()
      |> select([" I vow to keep these oaths.", "...eh...no..."])

    if answer == 2 do
      refuse_oath(ctx)
    else
      ordain(ctx)
    end
  end

  defp refuse_oath(ctx) do
    ctx
    |> mes("[Sensei Moohae]")
    |> mes("..............")
    |> next()
    |> mes("[Sensei Moohae]")
    |> mes("Then your training isn't completed.")
    |> mes_by_sex(
      "You will not be accepted as a monk my boy.",
      "You will not be accepted as a monk little girl."
    )
    |> next()
    |> mes("[Sensei Moohae]")
    |> mes("In light of this, your training will start again from the beginning....")
    |> next()
    |> mes(
      "Calm down yourself... I reconsidered... perhaps you are simply not ready for the commitment yet."
    )
    |> mes("Come back later when you're ready...")
    |> next()
    |> mes("[Sensei Moohae]")
    |> mes_by_sex(
      "I hope that you are able to realize what you are to become soon my boy...",
      "I hope that you are able to realize what you are to become soon my girl..."
    )
    |> close()
  end

  defp ordain(ctx) do
    ctx =
      ctx
      |> mes("[Sensei Moohae]")
      |> mes("Then your training is complete...")
      |> mes("Please come closer.")
      |> mes_by_sex(
        "We welcome you brother, in our holy battle against evil!",
        "We welcome you sister, in our holy battle against evil!"
      )
      |> next()
      |> mes("[Sensei Moohae]")
      |> mes_by_sex(
        "My brother, your oath has been heard by all around us.",
        "My sister, your oath has been heard by all around us."
      )
      |> next()
      |> mes("[Sensei Moohae]")
      |> mes("I will now perform the ultimate techniques upon your body...")
      |> next()
      |> mes("[Sensei Moohae]")
      |> mes(
        "I will use these ancient techniques to amplify your strength through the use of pressure points on your body."
      )
      |> next()
      |> mes("[Sensei Moohae]")
      |> mes("Close your eyes.........")
      |> next()
      |> mes("[Sensei Moohae]")
      |> mes("And relax your body.......")
      |> next()
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("^00CCCC- You breathe in deeply -^000000")
      |> next()
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("^CC0000- You feel fingers poking you all over your body with swiftness -^000000")
      |> next()
      |> mes("[Sensei Moohae]")
      |> mes("Kiiii~~~Yahahhhhhhh!!!")
      |> next()
      |> mes("[Sensei Moohae]")
      |> mes("Ooooohaaa!!!")
      |> next()
      |> mes("[Sensei Moohae]")
      |> mes("Kiii~~~Yahahhhhhhh!!!")
      |> next()
      |> mes("[Sensei Moohae]")
      |> mes("Haa~ Haa~ Haa~!!!!!")
      |> next()
      |> mes("[Sensei Moohae]")
      |> mes(".... now open your eyes......")
      |> next()
      |> mes("[Sensei Moohae]")
      |> mes("....and see life through the eyes of a monk.")
      |> next()

    former_job_level = job_level(ctx)

    {ctx, _} =
      ctx
      |> completequest(3032)
      |> jobchange(:monk)
      |> FClearjobvar.call([])

    ctx
    |> mes("[Sensei Moohae]")
    |> mes("....You are a monk.")
    |> next()
    |> mes("[Sensei Moohae]")
    |> mes("...heh.")
    |> next()
    |> mes("[Sensei Moohae]")
    |> mes("Well...I guess I am too old to do that anymore...I was better when I was younger...")
    |> next()
    |> mes("[Sensei Moohae]")
    |> mes("...anyways, you are a monk now.")
    |> mes("Welcome!")
    |> next()
    |> mes("[Sensei Moohae]")
    |> mes("I hope you will keep your vow..")
    |> next()
    |> mes("[Sensei Moohae]")
    |> mes("continue your training on your path and practice harder.")
    |> next()
    |> mes("[Sensei Moohae]")
    |> mes("Now...you may leave where the wind may take you.")
    |> mes("Oh and I have a gift for you before you leave.")
    |> give_item(if(former_job_level == 50, do: 1804, else: 1801), 1)
    |> close()
  end

  defp ask_yes_no(ctx), do: ctx |> next() |> select(["Yes.", "No."])

  defp mes_lines(ctx, lines), do: Enum.reduce(lines, ctx, &mes(&2, &1))

  defp remove_items(ctx, items) do
    Enum.reduce(items, ctx, fn {item_id, amount}, ctx -> delitem(ctx, item_id, amount) end)
  end

  defp mes_by_sex(ctx, male_line, female_line) do
    if sex(ctx) == get_char_var(ctx, :SEX_MALE, 0) do
      mes(ctx, male_line)
    else
      mes(ctx, female_line)
    end
  end

  defp acolyte?(ctx), do: Rathena.job_id(base_job(ctx)) == Rathena.job_id(:acolyte)
end
