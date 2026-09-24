defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21.Hunter.Hunter do
  @moduledoc """
  Hunter Guildmaster who administers the Hunter job change field test.

  ## Behavior

  - Answers questions about the test and sends ready candidates to the test arena.
  - Provides arrows to a first-time examinee; a returning examinee must bring their own.
  - Awards the proof of passing to examinees who escaped the arena and sends them back to the Hunter Guild.
  - Turns away Archers who have not yet reached this stage of the job quest.

  ## Credits

  - Original from rAthena, authors and Contributors
    - EREMES THE CANIVALIZER
    - yoshiki
    - kobra_k88
    - Lupus
    - celest
    - Poki#3
    - Vicious
    - Silent
    - FlavioJS
    - Samuray22
    - L0ne_W0lf
    - Kisuka
    - Vali

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "payon_in03",
        x: 131,
        y: 7,
        dir: 3,
        sprite: 59,
        name: "Hunter",
        scope: :shared,
        unique_name: "Hunter#htnGM"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    quest = get_char_var(ctx, :HNTR_Q, 0)

    cond do
      quest == 10 -> first_briefing(ctx)
      quest > 1 and quest < 10 -> turn_away_early_archer(ctx)
      quest == 11 -> redirect_to_archer_guild(ctx)
      quest > 11 and quest < 16 -> retry_briefing(ctx)
      quest == 16 -> award_proof(ctx)
      quest == 17 -> remind_to_return(ctx)
      true -> busy(ctx)
    end
  end

  defp first_briefing(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Hunter Guildmaster]")
      |> mes(
        "Hmpf. You must be here for the Hunter job test. Let me tell you about the testing process. What would you like to know?"
      )
      |> next()
      |> select(test_questions())

    case choice do
      1 ->
        ctx
        |> mes("[Hunter Guildmaster]")
        |> mes(
          "You have to hunt down certain monsters with a particular name. But you must avoid all the traps while you're at it."
        )
        |> next()
        |> mes("[Hunter Guildmaster]")
        |> mes(
          "This is to test your ability to move swiftly and locate targets in various situations."
        )
        |> close()

      2 ->
        ctx
        |> mes("[Hunter Guildmaster]")
        |> mes(
          "Within the time limit, starting in the 6 o'clock direction of the map, you must hunt the target monsters and then hit the escape switch that will appear in the center of the map."
        )
        |> next()
        |> explain_escape()

      3 ->
        ctx
        |> mes("[Hunter Guildmaster]")
        |> mes(
          "Hmm. Warnings... Well, if you fall into a trap, you have to start from the beginning. Also, only one person can take the test at a time."
        )
        |> next()
        |> mes("[Hunter Guildmaster]")
        |> mes(
          "I will send you to the testing place. There will be a waiting room, but if someone else is taking the test, you must wait in the chatroom."
        )
        |> next()
        |> explain_queue()

      4 ->
        ctx
        |> mes("[Hunter Guildmaster]")
        |> mes(
          "Okay. I'll send you to the testing area right now. Don't blame me if you get lost or confused because you didn't listen to my explanation."
        )
        |> next()
        |> lend_arrows()

      _ ->
        lend_arrows(ctx)
    end
  end

  defp lend_arrows(ctx) do
    ctx
    |> mes("[Hunter Guildmaster]")
    |> mes(
      "Well, then. Your arrows are probably still being made, so you can use mine to take the test."
    )
    |> set_char_var(:HNTR_Q, 12)
    |> changequest(4009, 4011)
    |> give_item(1751, 200)
    |> close()
    |> warp("job_hunte", 176, 22)
  end

  defp turn_away_early_archer(ctx) do
    ctx
    |> mes("[Hunter Guildmaster]")
    |> mes("Mmm...?")
    |> mes("What is an Archer")
    |> mes("visiting me for?")
    |> next()
    |> mes("[Hunter Guildmaster]")
    |> mes(
      "I wasn't notified about anything in particular from the Hunter Guild. You're not trying to skip the middle part of the Hunter test, are you?"
    )
    |> next()
    |> mes("[Hunter Guildmaster]")
    |> mes(
      "Go gather the items for the test, and come back after you've visited the Hunter Guild."
    )
    |> close()
  end

  defp redirect_to_archer_guild(ctx) do
    ctx
    |> mes("[Hunter]")
    |> mes(
      "Hmm? Can I help you? If you wish to change jobs, you should visit the person at the Archer Guild, not me."
    )
    |> close()
  end

  defp retry_briefing(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Hunter Guildmaster]")
      |> mes(
        "Hmm. You're the Archer that almost gave up on changing jobs. You do have everything ready, right? Then I'll send you to take the test right away."
      )
      |> next()
      |> mes("[Hunter Guildmaster]")
      |> mes("If you have any")
      |> mes("questions, ask now.")
      |> next()
      |> select(test_questions())

    case choice do
      1 ->
        ctx
        |> mes("[Hunter Guildmaster]")
        |> mes(
          "You have to hunt down certain monsters with a particular name, but you also avoid all the traps at the same time. This is to test your ability to move swiftly and locate targets in various situations."
        )
        |> close()

      2 ->
        ctx
        |> mes("[Hunter Guildmaster]")
        |> mes(
          "Within the given time, you will start at the 6 o'clock direction of the map, hunt the target monsters, and then hit the escape switch that will appear in the center of the map."
        )
        |> next()
        |> explain_escape()

      3 ->
        ctx
        |> mes("[Hunter Guildmaster]")
        |> mes(
          "Hmm. Warnings... Well, if you fall into a trap, you have to start from the beginning. Also, only one person can take the test at a time."
        )
        |> next()
        |> mes("[Hunter Guildmaster]")
        |> mes(
          "I'll send you to the testing place. There is a waiting room, but if someone else is taking the test, you must wait in the chatroom."
        )
        |> next()
        |> explain_queue()

      4 ->
        ctx
        |> mes("[Hunter Guildmaster]")
        |> mes("Okay. Good luck.")
        |> mes("I'll send you right now.")
        |> next()
        |> confirm_own_arrows()

      _ ->
        confirm_own_arrows(ctx)
    end
  end

  defp confirm_own_arrows(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Hunter Guildmaster]")
      |> mes(
        "Eh? Why won't I give you Silver Arrows? Don't expect anything when you don't bring any materials."
      )
      |> next()
      |> mes("[Hunter Guildmaster]")
      |> mes("Anyway, I believe you've prepared it yourself. Let's begin now.")
      |> next()
      |> select(["Okay. Let's start...", "Ah, wait a sec."])

    if choice == 1 do
      ctx
      |> mes("[Hunter Guildmaster]")
      |> mes("Okay!! I hope")
      |> mes("you will pass this time!")
      |> close()
      |> set_char_var(:HNTR_Q, 12)
      |> warp("job_hunte", 176, 22)
    else
      ctx
      |> mes("[Hunter Guildmaster]")
      |> mes("Then hurry and finish")
      |> mes("all of your preparations.")
      |> close()
    end
  end

  defp award_proof(ctx) do
    ctx
    |> mes("[Hunter Guildmaster]")
    |> mes("Wow, you came back in one piece!")
    |> mes("I mean, good job. I'll give you the item which proves that you have passed the test.")
    |> set_char_var(:HNTR_Q, 17)
    |> savepoint("payon", 104, 99)
    |> give_item(1007, 1)
    |> changequest(4012, 4013)
    |> next()
    |> mes("[Hunter Guildmaster]")
    |> mes(
      "Okay, here it is. Now, go back to the Hunter Guild. I have some more business left to do here, but I hope you can become a Hunter soon."
    )
    |> close()
  end

  defp remind_to_return(ctx) do
    ctx
    |> mes("[Hunter Guildmaster]")
    |> mes(
      "I see you aren't in a hurry to become a Hunter? When I first became a Hunter, I ran around for a month wildly brandishing my bow because I was so happy. Hehe~"
    )
    |> next()
    |> mes("[Hunter Guildmaster]")
    |> mes("Now, you should go back to the Hunter Guild~")
    |> close()
  end

  defp busy(ctx) do
    ctx
    |> mes("[Hunter]")
    |> mes("...Can I help you?")
    |> mes("I'm here for official business and am busy at the moment. If you'll excuse me...")
    |> close()
  end

  defp test_questions do
    ["What is the test?", "What are the passing requirements?", "Any warnings?", "Begin test."]
  end

  defp explain_escape(ctx) do
    ctx
    |> mes("[Hunter Guildmaster]")
    |> mes(
      "You will pass if you are able to escape in the 12 o'clock direction of the map after you hit the switch."
    )
    |> close()
  end

  defp explain_queue(ctx) do
    ctx
    |> mes("[Hunter Guildmaster]")
    |> mes(
      "If the person in front succeeds, resigns or fails, the next person waiting in the chatroom is sent to the testing area. If nobody is waiting, the test will begin as soon as you enter the chatroom."
    )
    |> close()
  end
end
