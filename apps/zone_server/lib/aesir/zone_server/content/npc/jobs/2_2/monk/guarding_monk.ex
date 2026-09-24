defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22.Monk.GuardingMonk do
  @moduledoc """
  Tohobu, the abbey gatekeeper who starts the Monk job quest.

  ## Behavior

  - Asks newcomers their name and job level, then their reason for visiting.
  - Sends job level 40+ Acolytes who wish to become monks to sensei Moohae.
  - Turns away visitors who ignore him and greets others according to their quest progress.
  - Comments on quest progress when players walk past him.

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
        map: "prt_monk",
        x: 59,
        y: 247,
        dir: 1,
        sprite: 120,
        name: "Guarding Monk",
        scope: :shared,
        unique_name: "Guarding Monk#mk",
        trigger: {6, 2}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch", ctx) do
    quest = get_char_var(ctx, :MONK_Q, 0)

    cond do
      quest == 0 ->
        ctx
        |> mes("[Tohobu]")
        |> mes("How dare you set foot in")
        |> mes("this holy building! ! !")
        |> mes("Where is your respect?!")
        |> next()
        |> mes("[Tohobu]")
        |> mes("Leave this place ! ! !")
        |> close()

      quest == 1 ->
        ctx
        |> mes("[Tohobu]")
        |> mes("Hmmm... come in.")
        |> mes("You may learn something...")
        |> close()

      acolyte?(ctx) and quest == 2 ->
        ctx
        |> mes("[Tohobu]")
        |> mes("Hmm.....you wish to see our sensei Moohae?")
        |> mes("He is in the south east section of this building.")
        |> close()

      acolyte?(ctx) and quest > 2 ->
        ctx
        |> mes("[Tohobu]")
        |> mes("I look forward to seeing you become a monk and joining us.")
        |> close()

      true ->
        ctx
    end
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    quest = get_char_var(ctx, :MONK_Q, 0)

    cond do
      upper(ctx) == 1 -> mistake_for_acquaintance(ctx)
      acolyte?(ctx) and quest == 0 -> greet_acolyte(ctx)
      quest == 1 and acolyte?(ctx) -> ask_about_visit(ctx)
      true -> respond_to_progress(ctx)
    end
  end

  defp mistake_for_acquaintance(ctx) do
    ctx
    |> mes("[Tohobu]")
    |> mes("Hmm? What business do you have here?")
    |> mes("If you wish to enter this sacred area,")
    |> mes("you must give me your name and job level!")
    |> next()
    |> mes("[Tohobu]")
    |> mes("....Eh?")
    |> mes("Oh!^FF0000gosh^000000! I am sorry, I think I misunderstood you from someone I know.")
    |> next()
    |> mes("[Tohobu]")
    |> mes(".......")
    |> mes("........")
    |> next()
    |> mes("[Tohobu]")
    |> mes("It is odd...I never misunderstand people...oh, well. Have a good day.")
    |> close()
  end

  defp greet_acolyte(ctx) do
    {ctx, reply} =
      ctx
      |> mes("[Tohobu]")
      |> mes("Hmm? What business do you have here?")
      |> mes("If you wish to enter this sacred area,")
      |> mes("you must give me your name and job level!")
      |> next()
      |> mes("[Tohobu]")
      |> mes("Now, please tell me your name and job level.")
      |> next()
      |> select(["Ignore him.", "Tell him."])

    if reply == 1 do
      turn_away(ctx)
    else
      {ctx, reason} = confirm_identity(ctx, "Very well... why have you come here")

      case reason do
        1 -> describe_monks(ctx, "We monks live our lives for spiritual enlightenment.")
        2 -> request_training(ctx, &approve_training/1, &decline_first_visit/1)
        3 -> offer_rest(ctx)
        _ -> ctx
      end
    end
  end

  defp greet_visitor(ctx) do
    {ctx, reply} =
      ctx
      |> mes("[Tohobu]")
      |> mes("Hmm? What business do you have here?")
      |> mes("If you wish to enter this sacred area,")
      |> mes("You must give me your name, job level, and level!")
      |> next()
      |> mes("[Tohobu]")
      |> mes("Now, please tell me your name as well as your job level!")
      |> next()
      |> select(["Ignore.", "Tell him."])

    if reply == 1 do
      turn_away(ctx)
    else
      {ctx, reason} = confirm_identity(ctx, "Okay, Now, why have you come here")

      case reason do
        1 -> describe_monks(ctx, "We monks live our lives for God and spiritual enlightenment.")
        2 -> request_training(ctx, &approve_visitor_training/1, &decline_training/1)
        3 -> offer_rest(ctx)
        _ -> ctx
      end
    end
  end

  defp ask_about_visit(ctx) do
    {ctx, answer} =
      ctx
      |> mes("[Tohobu]")
      |> mes("What do you think? Did your visit reveal anything to your spirit?")
      |> next()
      |> select(["No...", "I wish to become a monk.", "I need to rest..."])

    case answer do
      1 ->
        ctx
        |> mes("[Tohobu]")
        |> mes("I see, there is no shame in that.")
        |> mes("I hope that your experience here with")
        |> mes("our brothers has helped you become one")
        |> mes("step closer to true enlightenment.")
        |> set_char_var(:MONK_Q, 1)
        |> close()

      2 ->
        request_training(ctx, &approve_training/1, &decline_training/1)

      3 ->
        offer_rest(ctx)

      _ ->
        respond_to_progress(ctx)
    end
  end

  defp respond_to_progress(ctx) do
    quest = get_char_var(ctx, :MONK_Q, 0)

    cond do
      quest == 0 ->
        greet_visitor(ctx)

      quest == 1 ->
        ctx
        |> mes("[Tohobu]")
        |> mes("Listen carefully on your journey.")
        |> mes("There is much to learn.")
        |> close()

      acolyte?(ctx) and quest == 2 ->
        ctx
        |> mes("[Tohobu]")
        |> mes("Hmm... would you like to meet sensei Moohae?")
        |> mes("He is in the south east area in 'The Hall of Monks'.")
        |> close()

      acolyte?(ctx) and quest > 2 ->
        ctx
        |> mes("[Tohobu]")
        |> mes("I hope you do well in your training and I look forward to seeing you again.")
        |> close()

      true ->
        ctx
        |> mes("[Tohobu]")
        |> mes("Welcome to the central chamber of our Church.")
        |> mes("Please, try not to disturb the other monks.")
        |> mes("Even if you are a monk yourself.")
        |> close()
    end
  end

  defp turn_away(ctx) do
    ctx
    |> mes("[Tohobu]")
    |> mes("To ignore another is disrespectful, get out!")
    |> close()
    |> warp("prt_fild03", 357, 256)
  end

  defp confirm_identity(ctx, question) do
    ctx
    |> mes("[Tohobu]")
    |> mes(Rathena.concat(Rathena.concat("Hmm... ", char_name(ctx, 0)), " is your name?"))
    |> mes("...did I say it right?")
    |> mes(
      Rathena.concat(Rathena.concat("Okay, and your job level is ", job_level(ctx)), " correct?")
    )
    |> next()
    |> mes("[Tohobu]")
    |> mes(question)
    |> mes(Rathena.concat(Rathena.concat("", char_name(ctx, 0)), "?"))
    |> next()
    |> select([
      "To visit and learn about monks.",
      "I wish to become a monk...",
      "I'm tired and need to rest..."
    ])
  end

  defp describe_monks(ctx, creed) do
    ctx
    |> mes("[Tohobu]")
    |> mes("I see...")
    |> mes(creed)
    |> mes("We improve our bodies as well as our minds to reach true inner peace.")
    |> mes("May you find your inner peace as well.")
    |> set_char_var(:MONK_Q, 1)
    |> close()
  end

  defp request_training(ctx, approve, decline) do
    cond do
      acolyte?(ctx) and job_level(ctx) > 39 -> approve.(ctx)
      acolyte?(ctx) and job_level(ctx) < 40 -> decline.(ctx)
      true -> ctx |> mes("[Tohobu]") |> mes("Hahahha that was a good joke!") |> close()
    end
  end

  defp approve_training(ctx) do
    ctx
    |> mes("[Tohobu]")
    |> mes("Hmm you seem as though you have been training for this...")
    |> mes("That is good. Go see our sensei Moohae. Speak with him.")
    |> mes("He will help you start your training.")
    |> set_char_var(:MONK_Q, 2)
    |> setquest(3016)
    |> close()
  end

  defp approve_visitor_training(ctx) do
    ctx
    |> mes("[Tohobu]")
    |> mes("Hmm you seem as though you have been training for this...")
    |> mes("That is good. Go see our sensei Moohae, speak with him")
    |> mes("and he will help you start new training.")
    |> set_char_var(:MONK_Q, 2)
    |> setquest(3016)
    |> close()
  end

  defp decline_first_visit(ctx) do
    ctx
    |> mes("[Tohobu]")
    |> mes("Hmm, you do not seem ready to become a monk.")
    |> mes("To become a monk you must be,")
    |> mes("at least a job level 40 Acolyte.")
    |> mes("If not, you are not yet ready to become a monk.")
    |> next()
    |> mes("[Tohobu]")
    |> mes("Come back to me when you have trained more")
    |> mes("and I will let you know if you are ready.")
    |> next()
    |> mes("[Tohobu]")
    |> mes("I hope that you will soon join us on our")
    |> mes("path of inner peace and enlightenment.")
    |> mes("I'll be waiting here for you.")
    |> set_char_var(:MONK_Q, 1)
    |> close()
  end

  defp decline_training(ctx) do
    ctx
    |> mes("[Tohobu]")
    |> mes("Hmm, you do not seem ready to become a monk.")
    |> mes("To become a monk you must be,")
    |> mes("at least a job level 40 Acolyte.")
    |> mes("If not, you are not yet ready to become a monk.")
    |> next()
    |> mes("[Tohobu]")
    |> mes("Come back to me when you have trained more on your own")
    |> mes("and I will let you know if you are ready.")
    |> next()
    |> mes("[Tohobu]")
    |> mes("I hope that you will soon join us in our")
    |> mes("path to inner peace and enlightenment.")
    |> mes("I'll be waiting here for you.")
    |> set_char_var(:MONK_Q, 1)
    |> close()
  end

  defp offer_rest(ctx) do
    ctx
    |> mes("[Tohobu]")
    |> mes("Yes, we all need to take a rest once in a while...")
    |> mes("It is a good idea not to stress your self.")
    |> mes("Come in and make yourself comfortable.")
    |> mes("Rest as long as you need to.")
    |> next()
    |> mes("[Tohobu]")
    |> mes("I hope that you become energized")
    |> mes("when observing our brothers in their")
    |> mes("pursuit of spiritual enlightenment.")
    |> mes("I hope you reach it too.")
    |> set_char_var(:MONK_Q, 1)
    |> close()
  end

  defp acolyte?(ctx), do: Rathena.job_id(base_job(ctx)) == Rathena.job_id(:acolyte)
end
