defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.YoungMan do
  @moduledoc """
  Gaanan administers Arian’s quiz for The Sign quest.

  ## Behavior

  - Asks five questions and records whether the player passes.
  - Directs the player back to Arian for the result.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Kargha
    - L0ne_W0lf
    - Kazukin
    - Kisuka
    - CalciumKid
    - tr0n
    - Euphy
    - Joseph
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "morocc_in",
        x: 114,
        y: 162,
        dir: 4,
        sprite: 118,
        name: "Young Man",
        scope: :shared,
        unique_name: "Young Man#sign"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FUpdatesignvars

  @impl true
  def on_talk(ctx) do
    {ctx, _} = FUpdatesignvars.call(ctx, [])
    ctx = mes(ctx, "[Gaanan]")
    progress = get_char_var(ctx, :sign_q, 0)

    cond do
      progress < 11 -> hot_weather(ctx)
      progress == 11 -> first_question(ctx)
      progress < 14 -> result_reminder(ctx)
      true -> wish_for_cool_weather(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp hot_weather(ctx) do
    ctx
    |> mes("The weather here in")
    |> mes("Morocc is too hot for me.")
    |> mes("I'm having a hard time just")
    |> mes("trying to live here. Do you")
    |> mes("know a nice and cool place")
    |> mes("where I can work?")
    |> emotion(:profusely_sweat)
    |> close()
  end

  defp result_reminder(ctx) do
    ctx
    |> mes("Hm...?")
    |> mes("Arian is the one")
    |> mes("who's grading your")
    |> mes("test. But I understand.")
    |> mes("If you failed, I'd want")
    |> mes("to avoid him too...")
    |> close()
  end

  defp wish_for_cool_weather(ctx) do
    ctx
    |> mes("^333333*Sigh...*^000000")
    |> mes("I wish the weather'd")
    |> mes("cool down, even just a little.")
    |> mes("While I'm asking for miracles,")
    |> mes("I may as well wish for a billion kajillion zeny. And maybe a yacht.")
    |> close()
  end

  defp first_question(ctx) do
    {ctx, choice} =
      ctx
      |> mes("Oh, Arian sent you to me,")
      |> mes("right? I'm sorry, but he takes")
      |> mes("a little getting used to. Even")
      |> mes("though I still have to get used")
      |> mes("to his... mannerisms.")
      |> next()
      |> mes("[Gaanan]")
      |> mes("Anyway, since he thinks it's")
      |> mes("boring, Arian put me in charge")
      |> mes("of the quiz portion of your test. Please carefully choose an")
      |> mes("answer when I ask you a")
      |> mes("question. Are you ready?")
      |> next()
      |> mes("[Gaanan]")
      |> mes("Now, the first question.")
      |> mes("Let's say that you just")
      |> mes("found yourself on a deserted")
      |> mes("island. What is the very first")
      |> mes("thing that you should do?")
      |> next()
      |> select([
        "Look for fresh water.",
        "Just wait for rescue.",
        "Forage for food.",
        "Explore the island."
      ])

    score_answer(ctx, choice, [7, 1, 4, 10], &second_question/1)
  end

  defp second_question(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Gaanan]")
      |> mes("The second question is...")
      |> mes("You happen to be stuck in")
      |> mes("a narrow place inside some")
      |> mes("collapsed building. What")
      |> mes("do you plan to do first?")
      |> next()
      |> select([
        "Scream for help.",
        "Stay quiet.",
        "Wait for death to come.",
        "Find a way out."
      ])

    score_answer(ctx, choice, [3, 7, 1, 7], &third_question/1)
  end

  defp third_question(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Gaanan]")
      |> mes("Now, the third question.")
      |> mes("You're on some dungeon")
      |> mes("expedition with your friends,")
      |> mes("but you got lost somehow.")
      |> mes("How do you handle it?")
      |> next()
      |> select([
        "Try to find my friends.",
        "Find a way out.",
        "Stay put.",
        "Continue exploring the dungeon."
      ])

    score_answer(ctx, choice, [0, 5, 10, 1], &fourth_question/1)
  end

  defp fourth_question(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Ganaan]")
      |> mes("Here's the fourth question.")
      |> mes("You're with your friends inside")
      |> mes("a mansion with no exit. What do")
      |> mes("you do first when a murder happens inside the mansion?")
      |> next()
      |> select([
        "Wait for the case to get solved.",
        "Try to find my friends first.",
        "Find a way out.",
        "Solve the murder case on my own.",
        "Kill the others before they kill me."
      ])

    score_answer(ctx, choice, [5, 7, 3, 1, 1], &fifth_question/1)
  end

  defp fifth_question(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Gaanan]")
      |> mes("The fifth question is...")
      |> mes("You hear that the end of")
      |> mes("the world is in one week.")
      |> mes("So what do you do during")
      |> mes("this final week?")
      |> next()
      |> select([
        "Wait to see the end.",
        "Plant an apple tree.",
        "Look to move to a different world.",
        "What else? Save the world.",
        "What else? Go on a crime spree."
      ])

    score_answer(ctx, choice, [5, 3, 7, 10, 1], &finish_quiz/1)
  end

  defp score_answer(ctx, choice, scores, next_question) when choice > 0 do
    case Enum.at(scores, choice - 1) do
      nil ->
        ctx

      0 ->
        next_question.(ctx)

      points ->
        ctx
        |> set_local(:point_s, get_local(ctx, :point_s, 0) + points)
        |> next_question.()
    end
  end

  defp score_answer(ctx, _choice, _scores, _next_question), do: ctx

  defp finish_quiz(ctx) do
    ctx
    |> mes("[Gaanan]")
    |> mes("Oh! We're done!")
    |> mes("Okay, let me give")
    |> mes("these answers to Arian.")
    |> mes("Sooo... Talk to him and")
    |> mes("he'll let you know how")
    |> mes("you did.")
    |> set_char_var(:sign_q, if(get_local(ctx, :point_s, 0) > 33, do: 13, else: 12))
    |> close()
  end
end
