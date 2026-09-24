defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21.Priest.SisterCecilia do
  @moduledoc """
  Sister Cecilia, who guides Acolytes through the Priest job quest and hears the final oath.

  ## Behavior

  - Greets Priests, Novices, and other classes and explains the Priesthood.
  - Tells Acolytes where each step of the pilgrimage and the spiritual training takes place.
  - Administers the oath of devotion after the spiritual training, advancing the quest log;
    a wrong answer sends the Acolyte away to reflect before trying again.

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
        x: 27,
        y: 24,
        dir: 1,
        sprite: 79,
        name: "Sister Cecilia",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  # {question lines, options, wrong choice, rebuke, advice lines}
  @oath_questions [
    {["Are you willing", "to give your life to God?"], ["Yes.", "No!"], 2,
     "Aw...? How could you give me that kind of answer? I assume you're not ready to be a Priest yet...",
     [
       "You should reflect a little more on the teachings of holiness and come back later. You can't be a Priest if your spirit is weak."
     ]},
    {[
       "[Sister Cecilia]",
       "Will you take advantage of the holy abilities given by God for selfish, destructive or greedy ends?"
     ], ["Yes.", "No."], 1,
     "Aw...? God won't grant you the power of holiness if your goals aren't just and pure. Meditate on your motivations for a while, and then come back to me.",
     [
       "Think about the qualities that make Priests people of respect. You can't be a Priest if your spirit is not in accordance with God."
     ]},
    {[
       "[Sister Cecilia]",
       "Will you help aid others, even complete strangers, in battles by easing their suffering?"
     ], ["Yes.", "No."], 2,
     "No, no. You've got the wrong idea. God authorizes us to use his power to support his children. You must help people in danger: it is your obligation.",
     [
       "Go and observe the adventurers that are fighting for peace in this world. They will teach you what you must do in order to help them."
     ]},
    {["[Sister Cecilia]", "Are you willing to sacrifice yourself for the sake of others?"],
     ["Yes.", "No."], 2,
     "How can you say no...? That's one of the basic principles of Priesthood. You must value the welfare of others over your own safety.",
     [
       "Go and think about the value of suffering and the meaning of sacrifice. When you think you understand more about helping those in need, come back to me."
     ]},
    {[
       "[Sister Cecilia]",
       "Will you repeatly say the same phrase in public in order to send God's message to his children?"
     ], ["Yes.", "No."], 1,
     "No no no... You've got it wrong. Even though your purpose is to spread God's message, no one will eagerly accept what you say when you spam text.",
     [
       "Remember...",
       "You must be a moral person, and display maturity and respect to other players. This kind of attitude applies for all classes,",
       "I believe."
     ]},
    {["[Sister Cecilia]", "Will you lure many monsters to help your party members level up?"],
     ["Yes.", "No."], 1,
     "No, you won't. Luring many monsters does more harm than good. There is no exception. That behavior is totally unacceptable.",
     [
       "Even if it looks like you are aiding your party members, such action results in bad karma. Please reflect on that for a while."
     ]},
    {[
       "[Sister Cecilia]",
       "Will you follow God, no matter what it takes, even if he demands you to kill yourself?"
     ], ["Yes.", "No."], 2,
     "With that spirit, you can't be a Priest. If it is God's will to sacrifice yourself for a good purpose, you must carry out God's will as his servant.",
     [
       "Besides, God has also given Priests the resurrection power. Think about the meaning of life and death again, and then come back to me."
     ]}
  ]

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = mes(ctx, "[Sister Cecilia]")

    if Rathena.job_id(base_job(ctx)) != Rathena.job_id(:acolyte) do
      ctx |> greet_non_acolyte() |> close()
    else
      guide_acolyte(ctx)
    end
  end

  defp greet_non_acolyte(ctx) do
    cond do
      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:priest) ->
        mes(
          ctx,
          "May god bless you, #{sibling(ctx)}. It brings my heart joy to see that you working hard to carry out the will of God."
        )

      Rathena.job_id(class(ctx)) == Rathena.job_id(:novice) ->
        ctx
        |> mes("May god bless you, #{sibling(ctx)}.")
        |> mes("Prontera parish welcomes you.")
        |> next()
        |> mes("[Sister Cecilia]")
        |> mes(
          "Oh, you haven't chosen a job yet? Why don't you consider devoting your life to God?"
        )
        |> next()
        |> mes("[Sister Cecilia]")
        |> mes("You can lead a fulfilling life as an Acolyte, helping out other people in need.")
        |> next()
        |> mes("[Sister Cecilia]")
        |> mes(
          "If you're interested, please ask the Priest in the other room. You won't ever regret the choice to become an Acolyte."
        )
        |> next()
        |> mes("[Sister Cecilia]")
        |> mes("When you reach Job level 40 as an Acolyte, you can be promoted to a Priest.")
        |> next()
        |> mes("[Sister Cecilia]")
        |> mes("But please...")
        |> mes("Take your time, and decide what job will be the best for you.")

      true ->
        describe_priests(ctx)
    end
  end

  defp describe_priests(ctx) do
    {ctx, choice} =
      ctx
      |> mes("May god bless you, #{sibling(ctx)}.")
      |> mes("Welcome to Prontera parish. How may I help you?")
      |> next()
      |> select(["Tell me more about Priests.", "Nothing."])

    if choice == 1 do
      ctx
      |> mes("[Sister Cecilia]")
      |> mes(
        "Messengers of God are usually known as Priests. After becoming an Acolyte, you can train with the goal of becoming a Priest."
      )
      |> next()
      |> mes("[Sister Cecilia]")
      |> mes(
        "Servants of God are prohibited to use weapons based on blades. For us, the meaning of battle with monsters is not in the killing, but in the enlightening of their souls."
      )
    else
      ctx
      |> mes("[Sister Cecilia]")
      |> mes(
        "I see. Well, feel free to relax and make yourself at home. Nowhere on earth is safer than the Prontera Sanctuary."
      )
      |> next()
      |> mes("[Sister Cecilia]")
      |> mes("May God bless you...")
    end
  end

  defp guide_acolyte(ctx) do
    quest = get_char_var(ctx, :PRIEST_Q, 0)

    cond do
      quest == 0 -> introduce_trials(ctx)
      quest == 1 -> direct_to_rubalkabara(ctx)
      quest == 2 -> direct_to_mathilda(ctx)
      quest == 3 -> direct_to_yosuke(ctx)
      quest == 4 -> encourage_training(ctx)
      quest == 5 -> hint_training(ctx)
      quest == 6 -> console_after_failure(ctx)
      quest == 7 or quest == 8 -> begin_oath(ctx, quest)
      quest == 9 -> congratulate(ctx)
      true -> ctx
    end
  end

  defp introduce_trials(ctx) do
    {ctx, choice} =
      ctx
      |> mes("May God bless you, #{sibling(ctx)}.")
      |> mes("May I ask what brings you here?")
      |> next()
      |> select(["I wish to become a Priest.", "Nothing."])

    case choice do
      1 ->
        ctx
        |> mes("[Sister Cecilia]")
        |> mes(
          "I see. You've devoted yourself to God. Many Acolytes wish to become Priests to continue on their personal journey towards holiness."
        )
        |> next()
        |> mes("[Sister Cecilia]")
        |> mes(
          "Let me introduce myself. I am Cecilia Margarita, and I am in charge of part of the Priest job change process."
        )
        |> next()
        |> mes("[Sister Cecilia]")
        |> mes(
          "I've been supporting many people in becoming Priests ever since I joined the Prontera Parish. That is one of my main responsibilities."
        )
        |> next()
        |> mes("[Sister Cecilia]")
        |> mes(
          "In order to become a Priest, you must complete 3 trials. A pilgrimage, a session of spiritual training, and an oath of devotion to God."
        )
        |> next()
        |> mes("[Sister Cecilia]")
        |> mes(
          "If you wish to become a servant of God, please apply for the Priest job with Bishop Paul, and complete all 3 trials."
        )
        |> next()
        |> mes("[Sister Cecilia]")
        |> mes(
          "If you experience a problem during any of your trials, feel free to visit me. I will help you as much as I can."
        )
        |> close()

      2 ->
        ctx
        |> mes("[Sister Cecilia]")
        |> mes(
          "Make yourself at home. I insist that you recover and take a rest in this Sanctuary. May God bless you..."
        )
        |> close()

      _ ->
        ctx
    end
  end

  defp direct_to_rubalkabara(ctx) do
    ctx
    |> mes(
      "Ah, you've started your pilgrimage. Please do your best to accomplish this first trial."
    )
    |> next()
    |> mes("[Sister Cecilia]")
    |> mes(
      "The first Priest you must meet is Father Rubalkabara. He is in the ruins Northeast of Prontera."
    )
    |> next()
    |> mes("[Sister Cecilia]")
    |> mes(
      "Travel one field North from Prontera, and then three fields East, and you will arrive at the ruins."
    )
    |> next()
    |> mes("[Sister Cecilia]")
    |> mes(
      "Of course, you can also head 1 field East from Prontera, then go 1 field north, and then go 2 fields East..."
    )
    |> next()
    |> mes("[Sister Cecilia]")
    |> mes(
      "Father Rubalkabara will be at the entrance of the Prontera Ruins. Be careful. That place is a habitat for aggressive Chocos."
    )
    |> next()
    |> mes("[Sister Cecilia]")
    |> mes(
      "After meeting Father Rubalkabara, please visit Sister Mathilda and Father Yosuke. You can check your quest progress with me if you have any questions later."
    )
    |> next()
    |> mes("[Sister Cecilia]")
    |> mes(
      "Well then, have a good journey. Please don't give up to short lived tribulations, and I hope that you accomplish your goals."
    )
    |> close()
  end

  defp direct_to_mathilda(ctx) do
    ctx
    |> mes(
      "Oh, you've met Father Rubalkabara. Now it's time for you to visit Sister Mathilda. She is near a town named Morocc."
    )
    |> next()
    |> mes("[Sister Cecilia]")
    |> mes(
      "She has been training her religious discipline somewhere in a field North of Morocc. If you look around that field, you will be able to find her."
    )
    |> next()
    |> mes("[Sister Cecilia]")
    |> mes(
      "Of course, sometimes I want to devote myself to training like those other Priests, but I have my duty to assist those Acolytes applying for the Priest job."
    )
    |> next()
    |> mes("[Sister Cecilia]")
    |> mes(
      "But I believe this is God's will, and that this is the work he has intended me to do as his servant. Have a safe journey, and come back safely."
    )
    |> close()
  end

  defp direct_to_yosuke(ctx) do
    ctx
    |> mes(
      "Now, the final Priest that you must meet is Father Yosuke. I've heard that he is training near a lake located Northwest of Prontera."
    )
    |> next()
    |> mes("[Sister Cecilia]")
    |> mes(
      "From Prontera, travel one field North, and then two fields towards the West. You may also travel two fields West first, and then travel one field to the North."
    )
    |> next()
    |> mes("[Sister Cecilia]")
    |> mes(
      "Although there are still two trials awaiting you, I have faith that you will be able to accomplish your goal of becoming a Priest..."
    )
    |> close()
  end

  defp encourage_training(ctx) do
    ctx
    |> mes(
      "Welcome. You demonstrated great effort to accomplish your first trial. Now, speak to Bishop Paul so that you can begin your next trial on your path to Priesthood."
    )
    |> next()
    |> mes("[Sister Cecilia]")
    |> mes("#{sibling_title(ctx)} #{char_name(ctx, 0)}...")
    |> mes(
      "The spiritual training is much more difficult than the pilgrimage, but I believe in you."
    )
    |> next()
    |> mes("[Sister Cecilia]")
    |> mes(
      "I hope that you find someone who has already become a Priest to help during the spiritual training. Good luck, and have faith."
    )
    |> close()
  end

  defp hint_training(ctx) do
    ctx
    |> mes("Oh, you haven't finished the spiritual training yet?")
    |> next()
    |> mes("[Sister Cecilia]")
    |> mes(
      "I cannot let you know the specific details, but as long as you believe in yourself and have faith in all that is good, you will succeed."
    )
    |> next()
    |> mes("[Sister Cecilia]")
    |> mes(
      "Please speak to Father Peter in the test hall for more details. He is a close friend of Bishop Paul and may give you some useful tips for the spiritual training."
    )
    |> close()
  end

  defp console_after_failure(ctx) do
    ctx
    |> mes(
      "Yes, I understand that you've been through a really difficult situation. However, do not give up and succumb to temptation. You must be able to resist evil to become a Priest."
    )
    |> next()
    |> mes("[Sister Cecilia]")
    |> mes(
      "If you know somebody who has already become a Priest, ask them to help you during your spiritual training."
    )
    |> next()
    |> mes("[Sister Cecilia]")
    |> mes(
      "May God give you guidance and protection. When you complete your training, please come back to me."
    )
    |> close()
  end

  defp begin_oath(ctx, quest) when quest == 7 do
    ctx =
      if checkquest(ctx, 8014) == -1 do
        changequest(ctx, 8013, 8014)
      else
        ctx
      end

    ctx
    |> mes(
      "Welcome! I'm so glad to see you've come back! Now, there is one last trial left for you to complete."
    )
    |> start_oath()
  end

  defp begin_oath(ctx, _quest) do
    ctx
    |> mes("...")
    |> next()
    |> mes("[Sister Cecilia]")
    |> mes("Welcome back.")
    |> mes(
      "I hope that you've reflected on what you've said last time, and that you now have the attitude to become a Priest."
    )
    |> start_oath()
  end

  defp start_oath(ctx) do
    name = char_name(ctx, 0)

    ctx
    |> next()
    |> mes("[Sister Cecilia]")
    |> mes("#{sibling_title(ctx)} #{name}...")
    |> mes(
      "We will now begin your formal oath for the Priesthood. Make yourself comfortable, and just answer with your heart."
    )
    |> next()
    |> mes("[Sister Cecilia]")
    |> mes("#{sibling_title(ctx)} #{name},")
    |> ask_oath_questions(@oath_questions)
  end

  defp ask_oath_questions(ctx, []), do: final_vow(ctx)

  defp ask_oath_questions(ctx, [{lines, options, wrong, rebuke, advice} | rest]) do
    {ctx, choice} =
      ctx
      |> mes_lines(lines)
      |> next()
      |> select(options)

    if choice == wrong do
      ctx
      |> mes("[Sister Cecilia]")
      |> mes(rebuke)
      |> next()
      |> set_char_var(:PRIEST_Q, 8)
      |> mes("[Sister Cecilia]")
      |> mes_lines(advice)
      |> close()
    else
      ask_oath_questions(ctx, rest)
    end
  end

  defp final_vow(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Sister Cecilia]")
      |> mes("#{sibling_title(ctx)} #{char_name(ctx, 0)}...")
      |> mes(
        "You have demonstrated your devotion to God. Will you swear to adhere to his teachings for the rest of your days?"
      )
      |> next()
      |> select(["I do.", "No."])

    if choice == 1 do
      ctx
      |> set_char_var(:PRIEST_Q, 9)
      |> changequest(8014, 8015)
      |> mes("[Sister Cecilia]")
      |> mes(
        "Now, you have completed your oath of Priesthood and accomplished all three trials required to become a Priest."
      )
      |> next()
      |> mes("[Sister Cecilia]")
      |> mes(
        "Now go to Bishop Paul. And remember, we are all brothers and sisters in the eyes of God. Peace be with you..."
      )
      |> close()
    else
      ctx
      |> mes("[Sister Cecilia]")
      |> mes("...")
      |> next()
      |> mes("[Sister Cecilia]")
      |> mes("...")
      |> mes("......")
      |> next()
      |> set_char_var(:PRIEST_Q, 8)
      |> mes("[Sister Cecilia]")
      |> mes("You've come so far...")
      |> mes("Why would you want")
      |> mes("to throw this all away...?")
      |> close()
    end
  end

  defp congratulate(ctx) do
    ctx
    |> mes("Congratulations.")
    |> mes(
      "You've completed all three trials required for the Priesthood. Bishop Paul is now waiting for you."
    )
    |> next()
    |> mes("[Sister Cecilia]")
    |> mes("Peace be with you...")
    |> close()
  end

  defp mes_lines(ctx, lines), do: Enum.reduce(lines, ctx, &mes(&2, &1))

  defp sibling(ctx) do
    if sex(ctx) == get_char_var(ctx, :SEX_MALE, 0), do: "brother", else: "sister"
  end

  defp sibling_title(ctx) do
    if sex(ctx) == get_char_var(ctx, :SEX_MALE, 0), do: "Brother", else: "Sister"
  end
end
