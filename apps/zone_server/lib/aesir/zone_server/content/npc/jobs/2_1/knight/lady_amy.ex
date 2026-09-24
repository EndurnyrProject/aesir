defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21.Knight.LadyAmy do
  @moduledoc """
  Cheerful Lady Knight who runs the fourth Knight job test, a quiz on etiquette.

  ## Behavior

  - Gives candidates who passed Sir Windsor's test a ten-question etiquette quiz,
    worth ten points per courteous answer.
  - Passes candidates who score 90 or more, advancing the quest to Sir Edmond's test.
  - Fails everyone else, who may retake the quiz later.

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
        x: 69,
        y: 107,
        dir: 6,
        sprite: 728,
        name: "Lady Amy",
        scope: :shared,
        unique_name: "Lady Amy#knt"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = mes(ctx, "[Lady Amy]")

    if Rathena.job_id(base_job(ctx)) != Rathena.job_id(:swordman) do
      greet_non_swordman(ctx)
    else
      talk_about_test(ctx, get_char_var(ctx, :KNIGHT_Q, 0))
    end
  end

  defp greet_non_swordman(ctx) do
    cond do
      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:knight) -> greet_knight(ctx)
      Rathena.job_id(base_class(ctx)) == Rathena.job_id(:novice) -> greet_novice(ctx)
      true -> greet_visitor(ctx)
    end
  end

  defp greet_knight(ctx) do
    ctx
    |> mes("Oh...!")
    |> mes("I wonder, why")
    |> mes("have you come")
    |> mes("to visit me?")
    |> next()
    |> mes("[Lady Amy]")
    |> mes("You're not having")
    |> mes("trouble as a Knight,")
    |> mes("are you? Well, I think")
    |> mes("you're doing well~")
    |> next()
    |> mes("[Lady Amy]")
    |> mes("Of course~")
    |> mes("You're a member of")
    |> mes("the Prontera Chivalry~")
    |> close()
  end

  defp greet_novice(ctx) do
    ctx
    |> mes("Aww~")
    |> mes("What a cute")
    |> mes("little Novice!")
    |> mes("Soooooo cute!")
    |> next()
    |> mes("[Lady Amy]")
    |> mes("Heh heh...")
    |> mes("Are you interested")
    |> mes("in becoming a Knight")
    |> mes("later on? You'd be")
    |> mes("a great Knight~")
    |> next()
    |> mes("[Lady Amy]")
    |> mes("Remember, you're")
    |> mes("going to be a Knight,")
    |> mes("alright? Promise?")
    |> close()
  end

  defp greet_visitor(ctx) do
    ctx
    |> mes("Welcome to")
    |> mes("the Prontera Chivalry~")
    |> next()
    |> mes("[Lady Amy]")
    |> mes("We're only Knights,")
    |> mes("but hope you enjoy")
    |> mes("your stay here.")
    |> mes("Heh heh~")
    |> close()
  end

  defp talk_about_test(ctx, quest) do
    cond do
      quest == 0 -> point_to_captain(ctx)
      quest >= 1 and quest <= 7 -> redirect_early_candidate(ctx)
      quest == 8 -> introduce_etiquette_test(ctx)
      quest == 9 -> offer_etiquette_retest(ctx)
      quest == 10 -> ctx |> ask_why_here() |> send_to_sir_edmond()
      quest == 14 -> send_to_evaluation(ctx)
      true -> ctx |> ask_why_here() |> urge_other_tests()
    end
  end

  defp point_to_captain(ctx) do
    ctx
    |> mes("Ooh, you're")
    |> mes("a Swordsman...?")
    |> mes("Did you come to")
    |> mes("change jobs to")
    |> mes("a Knight?")
    |> next()
    |> mes("[Lady Amy]")
    |> mes("To apply, talk")
    |> mes("to the captain")
    |> mes("all the way over")
    |> mes("there. Hee hee~")
    |> close()
  end

  defp redirect_early_candidate(ctx) do
    {ctx, choice} =
      ctx
      |> ask_why_here()
      |> select(["I would like to take the test to change jobs.", "Oh, nothing."])

    if choice == 1 do
      ctx
      |> mes("[Lady Amy]")
      |> mes("Mmm~")
      |> mes(
        "You applied to change jobs! Okay! You'll soon be a Knight with that kind of determination!"
      )
      |> next()
      |> mes("[Lady Amy]")
      |> mes("But...")
      |> mes("You have to go")
      |> mes("to the other Knights")
      |> mes("before talking to Amy.")
      |> next()
      |> mes("[Lady Amy]")
      |> mes("I'd love to test")
      |> mes("you from the beginning,")
      |> mes("but I'm not allowed to.")
      |> mes("Hee hee~")
      |> close()
    else
      ctx |> mes("[Lady Amy]") |> mes("Aww~") |> mes("Alright...") |> close()
    end
  end

  defp introduce_etiquette_test(ctx) do
    {ctx, choice} =
      ctx
      |> ask_why_here()
      |> select(["Sir Windsor told me to--", "Oh, nothing."])

    if choice == 1 do
      ctx = if checkquest(ctx, 9008) == -1, do: changequest(ctx, 9007, 9008), else: ctx

      ctx
      |> mes("[Lady Amy]")
      |> mes("Oh!")
      |> mes("No need to say")
      |> mes("anything more.")
      |> mes("Welcome! It's time")
      |> mes("to take Amy's test!")
      |> next()
      |> mes("[Lady Amy]")
      |> mes("My name is Amy Beatrice,")
      |> mes(
        "a proud Lady Knight of the Prontera Chivalry. Amy's test will test your etiquette as a Knight~"
      )
      |> next()
      |> mes("[Lady Amy]")
      |> mes("I'll tell you a story and you choose an answer whenever")
      |> mes("I ask a question. Your etiquette will be judged on your answers.")
      |> next()
      |> mes("[Lady Amy]")
      |> mes("So listen carefully")
      |> mes("and answer as if you're")
      |> mes("already a Knight, okay?")
      |> next()
      |> mes("[Lady Amy]")
      |> mes("Then,")
      |> mes("let's begin!")
      |> next()
      |> run_etiquette_quiz()
    else
      decline_test(ctx)
    end
  end

  defp offer_etiquette_retest(ctx) do
    {ctx, choice} =
      ctx
      |> ask_why_here()
      |> select(["I would like to take the test to change jobs.", "Oh, nothing."])

    if choice == 1 do
      ctx
      |> mes("[Lady Amy]")
      |> mes("Mmm~?")
      |> mes("Have you learned")
      |> mes("what you did wrong")
      |> mes("last time? If you")
      |> mes("fail again, I'm going")
      |> mes("to be mad!")
      |> next()
      |> mes("[Lady Amy]")
      |> mes("So listen carefully")
      |> mes("and answer as if you")
      |> mes("are a Knight.")
      |> mes("Well then,")
      |> mes("let's begin!")
      |> next()
      |> mes("[Lady Amy]")
      |> mes("You are a Knight and you are looking for a party in Morocc.")
      |> mes("How would you go about doing so?")
      |> next()
      |> run_etiquette_quiz()
    else
      decline_test(ctx)
    end
  end

  defp decline_test(ctx) do
    ctx |> mes("[Lady Amy]") |> mes("Aww...") |> mes("Alright~") |> close()
  end

  defp run_etiquette_quiz(ctx) do
    {ctx, choice} =
      ctx
      |> mes("You are a Knight and you are looking for a party in Morocc.")
      |> mes("How would you go about doing so?")
      |> next()
      |> select([
        "Shout out that you are looking for a party.",
        "Open a chat room and wait.",
        "Look for people seeking Knights."
      ])

    score = tally(0, ctx, choice != 1)

    {ctx, choice} =
      ctx
      |> mes("[Lady Amy]")
      |> mes(
        "You have formed a party with equal leveled players. There's a Priest, a Wizard, a Hunter, an Assassin, and a Blacksmith..."
      )
      |> next()
      |> mes("[Lady Amy]")
      |> mes("The six of you decide to go hunt and have decided to go to the Pyramids.")
      |> next()
      |> mes("[Lady Amy]")
      |> mes("You reach Level 4")
      |> mes("of the Pyramids")
      |> mes("with your party.")
      |> mes("What should you do?")
      |> next()
      |> select([
        "Check out the area and plan ahead.",
        "Gather monsters for your party members.",
        "Lead the party slowly at the front."
      ])

    score = tally(score, ctx, choice != 2)

    {ctx, choice} =
      ctx
      |> mes("[Lady Amy]")
      |> mes(
        "But some rude players came with a group of monsters and disappeared! What should you do?"
      )
      |> next()
      |> select([
        "Keep the monsters from reaching the party.",
        "Defend while the party retreats.",
        "Run away on your Peco Peco."
      ])

    score = tally(score, ctx, choice != 3)

    {ctx, choice} =
      ctx
      |> mes("[Lady Amy]")
      |> mes(
        "Luckily, you all lived through the crisis. But as you walk, you find a person, who is not in your party, collapsed on the ground."
      )
      |> next()
      |> mes("[Lady Amy]")
      |> mes("The person is asking politely for help. What should you do?")
      |> next()
      |> select([
        "Ask your party's Priest to help.",
        "Say you will help for Zeny.",
        "Ignore and move on."
      ])

    score = tally(score, ctx, choice == 1)

    {ctx, choice} =
      ctx
      |> mes("[Lady Amy]")
      |> mes("You must bid farewell to your party members because you must go somewhere else.")
      |> next()
      |> mes("[Lady Amy]")
      |> mes("But you find")
      |> mes("a rare item during")
      |> mes("the battle. What")
      |> mes("should you do?")
      |> next()
      |> select([
        "Give it to who deserves it the most.",
        "Pretend like nothing happened and keep it.",
        "Decide with party who gets it."
      ])

    score = tally(score, ctx, choice != 2)

    {ctx, choice} =
      ctx
      |> mes("[Lady Amy]")
      |> mes(
        "You end up with the item and you go to Prontera to sell it. There are many people with shops and chat rooms opened selling items."
      )
      |> next()
      |> mes("[Lady Amy]")
      |> mes("What should you")
      |> mes("do to sell your item?")
      |> next()
      |> select([
        "Shout out loud to everyone.",
        "Open a chat room and wait.",
        "Inquire if there is anyone that is interested."
      ])

    score = tally(score, ctx, choice != 1)

    {ctx, choice} =
      ctx
      |> mes("[Lady Amy]")
      |> mes("While you are waiting,")
      |> mes("someone comes and begs")
      |> mes("for items and zeny.")
      |> mes("What do you do?")
      |> next()
      |> select([
        "Give them some Zeny and items.",
        "Simply ignore them.",
        "Give suggestions for a place to hunt."
      ])

    score = tally(score, ctx, choice == 3)

    {ctx, choice} =
      ctx
      |> mes("[Lady Amy]")
      |> mes(
        "Now you decide to go to the Hidden Temple by yourself. You happily ride on your Peco Peco."
      )
      |> next()
      |> mes("[Lady Amy]")
      |> mes("But you run into")
      |> mes("someone that is lost.")
      |> mes("What should you do?")
      |> next()
      |> select([
        "Tell the person how to reach the exit.",
        "Lead the person to the exit.",
        "Give a Butterfly Wing."
      ])

    score = tally(score, ctx, choice != 3)

    {ctx, choice} =
      ctx
      |> mes("[Lady Amy]")
      |> mes("You've been hunting for a while, and now you're low on HP!")
      |> mes("It's red now, which is very dangerous.")
      |> next()
      |> mes("[Lady Amy]")
      |> mes("Ah, then a Priest")
      |> mes("happens to walk by.")
      |> mes("How would you ask")
      |> mes("the Priest for a Heal?")
      |> next()
      |> select([
        "Would it be possible to get a heal please?",
        "Can I have a heal?",
        "Heal plz!!"
      ])

    score = tally(score, ctx, choice == 1)

    {ctx, choice} =
      ctx
      |> mes("[Lady Amy]")
      |> mes("You are now very")
      |> mes("exhausted and it's time")
      |> mes("to go back to town.")
      |> next()
      |> mes("[Lady Amy]")
      |> mes("You then find")
      |> mes("a rare item on")
      |> mes("the street.")
      |> mes("What should")
      |> mes("you do?")
      |> next()
      |> select([
        "Pick it up and keep it.",
        "Ask around to find the owner.",
        "Simply walk by."
      ])

    score = tally(score, ctx, choice != 1)

    ctx
    |> mes("[Lady Amy]")
    |> mes("Okay,")
    |> mes("that was the")
    |> mes("end of my test!")
    |> next()
    |> mes("[Lady Amy]")
    |> judge_etiquette(score)
  end

  # The original kept the score in a script-local variable, whose writes are
  # ignored once the pipeline has halted; a halted ctx therefore scores nothing.
  defp tally(score, %Ctx{status: {:error, _}}, _courteous?), do: score
  defp tally(score, _ctx, true), do: score + 10
  defp tally(score, _ctx, false), do: score

  defp judge_etiquette(ctx, score) do
    cond do
      score == 100 ->
        ctx
        |> set_char_var(:KNIGHT_Q, 10)
        |> changequest(9008, 9009)
        |> mes(
          "Well done, that kind of mentality is needed for a Knight! For your next test, visit Sir Edmond, please~"
        )
        |> next()
        |> mes("[Lady Amy]")
        |> mes(
          "I'll have nice comments about you for the captain. Do well on the tests you have left, okay?"
        )
        |> close()

      score == 90 ->
        ctx
        |> set_char_var(:KNIGHT_Q, 10)
        |> changequest(9008, 9009)
        |> mes("Well, it wasn't perfect,")
        |> mes("but I think you know enough")
        |> mes("about etiquette to be")
        |> mes("a fine Knight.")
        |> next()
        |> mes("[Lady Amy]")
        |> mes(
          "Now, it's time for you to go to Sir Edmond for your next test. Do well on the rest of your tests. You better promise~"
        )
        |> close()

      true ->
        ctx
        |> set_char_var(:KNIGHT_Q, 9)
        |> mes("Mmm...")
        |> mes(
          "To be honest, I don't think your attitude is good enough to be a Knight quite yet."
        )
        |> next()
        |> mes("[Lady Amy]")
        |> mes(
          "If you really act like that, everyone will think Knights are rude! Think about how you answered my questions and come again later."
        )
        |> next()
        |> mes("[Lady Amy]")
        |> mes("If you want,")
        |> mes("I'll let you")
        |> mes("retake the test, okay?")
        |> close()
    end
  end

  defp ask_why_here(ctx) do
    ctx
    |> mes("Hmmm?")
    |> mes("Why did you")
    |> mes("come to Amy?")
    |> next()
  end

  defp send_to_sir_edmond(ctx) do
    ctx
    |> mes("[Lady Amy]")
    |> mes("You have to go to")
    |> mes("Sir Edmond for your")
    |> mes("next test, okay?")
    |> close()
  end

  defp send_to_evaluation(ctx) do
    ctx
    |> mes("Wow~")
    |> mes("Now it's time for")
    |> mes("everyone to decide")
    |> mes("on your job change!")
    |> next()
    |> mes("[Lady Amy]")
    |> mes("Let's go talk to our")
    |> mes("captain. Don't worry")
    |> mes("too much. It should")
    |> mes("be okay.")
    |> close()
  end

  defp urge_other_tests(ctx) do
    ctx
    |> mes("[Lady Amy]")
    |> mes("You still have")
    |> mes("other tests to take.")
    |> mes("Hurry and finish~")
    |> close()
  end
end
