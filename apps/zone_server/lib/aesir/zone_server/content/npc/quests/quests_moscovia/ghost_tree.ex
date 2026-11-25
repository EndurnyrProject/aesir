defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.GhostTree do
  @moduledoc """
  Ghost Tree challenges the player to recover a stolen broom.

  ## Behavior

  - Offers two riddles followed by a dice game during the quest.
  - Confuses and expels players who demand the broom without answering.

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
        map: "pay_dun04",
        x: 163,
        y: 186,
        dir: 0,
        sprite: 111,
        name: "Ghost Tree",
        scope: :shared,
        unique_name: "Ghost Tree#rus45"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :rhea_rus_main, 0) do
      37 -> introduce_quiz(ctx)
      38 -> race_question(ctx)
      39 -> blacksmith_question(ctx)
      40 -> play_dice(ctx)
      46 -> farewell(ctx)
      _ -> ctx
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp question_answer(ctx, args) do
    {ctx, answer} = input(ctx, :string)
    ctx = set_local(ctx, :"input$", answer)
    ctx = mes(ctx, Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("", get_local(ctx, :"input$", "")), " !!"))
      |> next()

    {ctx,
     if get_local(ctx, :"input$", "") == Enum.at(args, 0, 0) do
       1
     else
       0
     end}
  end

  defp roll_dice(ctx) do
    if get_local(ctx, :rustree_turn01, 0) < 3 and get_local(ctx, :rususer_score01, 0) == 0 do
      ctx =
        ctx
        |> mes("[Ghost Tree]")
        |> mes("I cast first.")
        |> next()
        |> mes("- Ghost Tree casts a dice. The dice falls down, rotates and stops there-")
        |> specialeffect(:stunattack)
        |> next()
        |> set_local(:tree_dice01, Enum.random(1..6))
        |> mes("[Ghost Tree]")

      ctx =
        mes(
          ctx,
          Rathena.concat(
            Rathena.concat("I've got ^0000ffNumber ", get_local(ctx, :tree_dice01, 0)),
            "^000000."
          )
        )

      ctx =
        ctx
        |> emotion(Enum.at(get_local(ctx, :emo, []), get_local(ctx, :tree_dice01, 0), 0))
        |> next()

      ctx =
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", get_local(ctx, :"player_name$", "")), "]"))
        |> mes("Ok, it is my turn?")
        |> next()
        |> mes("-You cast a dice. The dice falls down, rotates and stops there-")
        |> specialeffect2(:stunattack)
        |> next()
        |> set_local(:rus_dice01, Enum.random(1..6))

      ctx =
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", get_local(ctx, :"player_name$", "")), "]"))
        |> mes("Let's see...")
        |> next()

      ctx =
        emotion(
          ctx,
          Enum.at(get_local(ctx, :emo, []), get_local(ctx, :rus_dice01, 0), 0),
          playerattached(ctx)
        )

      ctx =
        mes(ctx, Rathena.concat(Rathena.concat("[", get_local(ctx, :"player_name$", "")), "]"))

      ctx =
        if get_local(ctx, :rus_dice01, 0) == get_local(ctx, :tree_dice01, 0) do
          ctx
          |> mes(
            Rathena.concat(
              Rathena.concat(
                "Let's see... Wow, I got it! I've got ^0000ffNumber ",
                get_local(ctx, :rus_dice01, 0)
              ),
              "^000000!"
            )
          )
          |> emotion(:surprise)
          |> next()
          |> mes("[Ghost Tree]")
          |> mes("You seem lucky...")
          |> set_local(:rususer_score01, 1)
        else
          ctx
          |> mes(
            Rathena.concat(
              Rathena.concat(
                "Let's see................... It is ^0000ff ",
                get_local(ctx, :rus_dice01, 0)
              ),
              " ^000000..."
            )
          )
          |> mes("[Ghost Tree]")
          |> mes("Huuu...")
          |> emotion(:smile)
        end

      ctx
      |> set_local(:rustree_turn01, get_local(ctx, :rustree_turn01, 0) + 1)
      |> next()
      |> roll_dice()
    else
      ctx
    end
  end

  defp farewell(ctx) do
    ctx
    |> mes("[Ghost Tree]")
    |> mes("Kuhuhu, I can say that you are fun. If possible, play with me again.")
    |> close()
  end

  defp play_dice(ctx) do
    ctx =
      ctx
      |> set_local(:"player_name$", char_name(ctx, 0))
      |> mes("[Ghost Tree]")
      |> mes(
        "Kuhuhu, you did good until now. If you win over me, I will give the brooms as promisied."
      )
      |> next()
      |> mes("[Ghost Tree]")
      |> mes("The game is simple. Your number must be more than mine.")
      |> next()
      |> mes("[Ghost Tree]")
      |> mes("Cast 3 times if you win once, I will give you what you want.")
      |> next()

    ctx =
      ctx
      |> mes(
        Rathena.concat(
          Rathena.concat("[", get_local(ctx, :"player_name$", "")),
          "]"
        )
      )
      |> mes("Ok! I will do it!")
      |> next()

    ctx =
      58..63
      |> Enum.with_index(1)
      |> Enum.reduce(ctx, fn {dice_emotion, index}, ctx ->
        set_local(ctx, :emo, Rathena.put_at(get_local(ctx, :emo, []), index, dice_emotion, 0))
      end)
      |> roll_dice()

    if Rathena.truthy?(get_local(ctx, :rususer_score01, 0)) do
      ctx
      |> mes("[Ghost Tree]")
      |> mes("Ah. I lost, but it was fun.")
      |> next()
      |> mes("[Ghost Tree]")
      |> mes("For the fun play, I will give the broom to you as promised.")
      |> next()
      |> mes("[Ghost Tree]")
      |> mes("I can say that you are fun. If possible, play with me again. And take them.")
      |> next()
      |> mes("- ^0000ff You receive the best broom from Payon !!^000000 - ")
      |> set_char_var(:rhea_rus_main, 46)
      |> close()
    else
      ctx =
        ctx
        |> mes("[Ghost Tree]")
        |> mes(
          "Kuhuhu, nobody is worse than you. Remember that you have to win over me to get what you want"
        )
        |> next()

      ctx
      |> mes(
        Rathena.concat(
          Rathena.concat("[", get_local(ctx, :"player_name$", "")),
          "]"
        )
      )
      |> mes("I was not what I am! Let's do it again!")
      |> next()
      |> mes("[Ghost Tree]")
      |> mes("Ok, let's play again. If prepared, try again?")
      |> close()
    end
  end

  defp blacksmith_question(ctx) do
    ctx =
      ctx
      |> set_local(:"player_name$", char_name(ctx, 0))
      |> mes("[Ghost Tree]")
      |> mes("The second question. Listen carefully and answer!")
      |> next()
      |> mes("[Ghost Tree]")

    ctx =
      ctx
      |> mes(
        Rathena.concat(
          Rathena.concat("One day, you, ", get_local(ctx, :"player_name$", "")),
          ", upgraded your 'Hat of the Sun God', your ancestral treasure."
        )
      )
      |> next()

    {ctx, answer} =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", get_local(ctx, :"player_name$", "")), "]"))
      |> mes("Eh? I didn't...")
      |> next()
      |> mes("[Ghost Tree]")
      |> mes("Shut up! Listen to me!")
      |> mes(
        "While Aragam, Antonio, Hermanthorn, and Holgren, 4 blacksmiths, upgraded the 'Hat of the Sun God' in turn, it was broken!"
      )
      |> next()
      |> mes("[Ghost Tree]")
      |> mes("The stauts of 'Hat of the Sun God' was +7. Here, you guess who broke it!")
      |> next()
      |> mes("[Aragam]")
      |> mes("I heard that Holgren upraded it up to +7. It was overpace.")
      |> next()
      |> mes("[Antonio]")
      |> mes("...We upgraded it twice for each...")
      |> next()
      |> mes("[Hermanthorn]")
      |> mes("Hogren worked after me.")
      |> next()
      |> mes("[Holgren]")
      |> mes("I did it after Aragam!")
      |> next()
      |> mes("[Ghost Tree]")
      |> mes("Have you heard all of them? Who broke the 'Hat of the Sun God'?!")
      |> next()
      |> input(:string)

    ctx = set_local(ctx, :"input$", answer)

    ctx =
      mes(
        ctx,
        Rathena.concat(Rathena.concat("[", get_local(ctx, :"player_name$", "")), "]")
      )

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("", get_local(ctx, :"input$", "")), " !!"))
      |> next()

    if get_local(ctx, :"input$", "") != "Antonio" do
      ctx =
        ctx
        |> mes("[Ghost Tree]")
        |> mes("You are wrong, wrong!")
        |> mes("Look at this. In this way, it will take you a million years to take them back!")
        |> next()

      ctx
      |> mes(
        Rathena.concat(
          Rathena.concat("[", get_local(ctx, :"player_name$", "")),
          "]"
        )
      )
      |> mes("I was not thinking correctly!!!")
      |> mes("Again, again!")
      |> next()
      |> mes("[Ghost Tree]")
      |> mes("Kuhuhu, Ok then. You should do better next time!")
      |> close()
    else
      ctx
      |> mes("[Ghost Tree]")
      |> mes(
        "Good! Well done. The last one is to cast a dice with me! If you win over me, I will give you what you want!"
      )
      |> next()
      |> mes("[Ghost Tree]")
      |> mes("Gear yourself up and come to me again!")
      |> set_char_var(:rhea_rus_main, 40)
      |> close()
    end
  end

  defp race_question(ctx) do
    {ctx, first} =
      ctx
      |> mes("[Ghost Tree]")
      |> mes("First question. Listen to me carefully and answer the question!")
      |> next()
      |> mes("[Ghost Tree]")
      |> mes(
        "Kafra sisters had a race. Listen to what they say and guess their ranking in the race. Understand?"
      )
      |> next()
      |> mes("[Ghost Tree]")
      |> mes("Ok, then, listen to them.")
      |> next()
      |> mes("[Kafra Roxie]")
      |> mes("I am not good at running but Jasmine won over me and I won over Blossom.")
      |> next()
      |> mes("[Kafra Blossom]")
      |> mes(
        "I think that the smaller you are, the less the air disturbs you. Curly Sue was so fast that I couldn't follow her."
      )
      |> next()
      |> mes("[Kafra Jasmine]")
      |> mes("I won over Pavianne, but not Curly Sue. Huhu.")
      |> next()
      |> mes("[Kafra Curly Sue]")
      |> mes(
        "Wohuhu, it was difficult to race with the fast runners. Anyway, I am pleased to win over Roxie!"
      )
      |> next()
      |> mes("[Kafra Pavianne]")
      |> mes("...I wasn't the last one even though Roxie won over me...")
      |> next()
      |> mes("[Ghost Tree]")
      |> mes("Ok then, who was the first?!")
      |> next()
      |> scoped_call(["Curly Sue"], &question_answer/2)

    {ctx, second} =
      ctx
      |> set_local(:rus_kafra01, first)
      |> mes("[Ghost Tree]")
      |> mes("Who was the second?")
      |> next()
      |> scoped_call(["Jasmine"], &question_answer/2)

    {ctx, third} =
      ctx
      |> set_local(:rus_kafra01, get_local(ctx, :rus_kafra01, 0) + second)
      |> mes("[Ghost Tree]")
      |> mes("Who was the third?")
      |> next()
      |> scoped_call(["Roxie"], &question_answer/2)

    {ctx, fourth} =
      ctx
      |> set_local(:rus_kafra01, get_local(ctx, :rus_kafra01, 0) + third)
      |> mes("[Ghost Tree]")
      |> mes("And then who was the forth?")
      |> next()
      |> scoped_call(["Pavianne"], &question_answer/2)

    {ctx, fifth} =
      ctx
      |> set_local(:rus_kafra01, get_local(ctx, :rus_kafra01, 0) + fourth)
      |> mes("[Ghost Tree]")
      |> mes("And who was the last?!")
      |> next()
      |> scoped_call(["Blossom"], &question_answer/2)

    ctx =
      ctx
      |> set_local(:rus_kafra01, get_local(ctx, :rus_kafra01, 0) + fifth)
      |> mes("[Ghost Tree]")

    ctx =
      if get_local(ctx, :rus_kafra01, 0) > 4 do
        ctx
        |> mes("Ho, you are good!")
        |> next()
        |> mes("[Ghost Tree]")
        |> mes("Ok, let's see if you are good next time.")
        |> mes("Gear yourself up!")
        |> set_char_var(:rhea_rus_main, 39)
      else
        ctx =
          ctx
          |> mes("Ah, you are wrong, wrong!")
          |> mes("Do you really think that you can take the brooms back?")
          |> next()

        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("I was not thinking correctly! I will try it again!")
        |> next()
        |> mes("[Ghost Tree]")
        |> mes("Kuhuhu, ok. Let's do it again. Try your best.")
      end

    close(ctx)
  end

  defp introduce_quiz(ctx) do
    ctx =
      ctx
      |> mes("[Ghost Tree]")
      |> mes("Errr, a human? What are you doing here? Do you want to play with me?")
      |> next()

    {ctx, choice} =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Return the broom.")
      |> next()
      |> mes("[Ghost Tree]")
      |> mes("Kuhuhuhu, if you want it, you must give me the correct answers to my questions!")
      |> next()
      |> select(["Ok, ask me!", "No, just give it to me!"])

    if choice == 2 do
      ctx
      |> mes("[Ghost Tree]")
      |> mes("What!? You are rude to ask for what you want by doing nothing!")
      |> next()
      |> mes("[Ghost Tree]")
      |> mes("Get away! You must be punished!")
      |> sc_start(:sc_confusion, 60_000, 0)
      |> close2()
      |> warp("pay_dun04", 46, 43)
    else
      ctx
      |> mes("[Ghost Tree]")
      |> mes("Kuhuhu, you a cool kid?!")
      |> mes("I like a person confident as talented. Let's begin the test!")
      |> next()
      |> mes("[Ghost Tree]")
      |> mes("Eh.. Let's see. This will be a good start! Let's get started if you are ready!")
      |> set_char_var(:rhea_rus_main, 38)
      |> close()
    end
  end
end
