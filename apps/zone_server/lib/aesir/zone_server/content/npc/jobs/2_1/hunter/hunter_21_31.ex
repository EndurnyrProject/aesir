defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21.Hunter.Hunter2131 do
  @moduledoc """
  Hunter Guildmaster at the Archer Guild who administers the Hunter job change field test.

  ## Behavior

  - Answers questions about the test and sends ready candidates to the test arena.
  - Provides arrows to a first-time examinee; a returning examinee must bring their own.
  - Awards the proof of passing to examinees who escaped the arena and sends them back to the Hunter Guild.
  - Redirects applicants who belong to the Payon Central Palace examiner or have not gathered their materials.

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
        map: "payon_in02",
        x: 21,
        y: 31,
        dir: 1,
        sprite: 59,
        name: "Hunter",
        scope: :shared,
        unique_name: "Hunter#htnGM2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = cutin(ctx, "job_huntermaster", 2)
    quest = get_char_var(ctx, :HNTR_Q, 0)

    cond do
      quest == 11 -> first_briefing(ctx)
      quest > 1 and quest < 10 -> turn_away_early_archer(ctx)
      quest == 10 -> redirect_to_payon_palace(ctx)
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
        "Mmm. I see you're here for the Hunter job test. Let me explain the testing process. What would you like to know?"
      )
      |> next()
      |> select([
        "What is the test?",
        "What are the passing requirements?",
        "Any warnings?",
        "Begin test."
      ])

    ctx
    |> answer_from(choice, :first)
    |> mes("[Hunter Guildmaster]")
    |> mes(
      "Well, your arrows are probably still being made, so you can use mine to take the test."
    )
    |> give_item(1751, 200)
    |> next()
    |> mes("[Hunter Guildmaster]")
    |> mes("Good luck.")
    |> set_char_var(:HNTR_Q, 12)
    |> changequest(4010, 4011)
    |> warp("job_hunte", 176, 22)
  end

  defp retry_briefing(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Hunter Guildmaster]")
      |> mes(
        "Mmm? Aren't you the Archer who gave up last time? Now you're ready, right? Then I'll send you to the job change area right now."
      )
      |> next()
      |> mes("[Hunter Guildmaster]")
      |> mes("If you still")
      |> mes("have questions,")
      |> mes("feel free to ask.")
      |> next()
      |> select([
        "What is the test?",
        "What are the requirements to pass the test?",
        "Any warnings?",
        "Begin test."
      ])

    {ctx, confirm} =
      ctx
      |> answer_from(choice, :retry)
      |> mes("[Hunter Guildmaster]")
      |> mes(
        "Eh? Why don't I give you any Silver Arrows? Well, you shouldn't expect to get anything when you didn't even bring the materials."
      )
      |> next()
      |> mes("[Hunter Guildmaster]")
      |> mes("Well...")
      |> mes("I believe")
      |> mes("you're ready.")
      |> mes("Let's begin.")
      |> next()
      |> select(["Yes, let's start.", "Ah, wait a moment."])

    if confirm == 1 do
      ctx
      |> mes("[Hunter Guildmaster]")
      |> mes("Okay!! Now...")
      |> mes("Pass this time!")
      |> close()
      |> cutin("", 255)
      |> set_char_var(:HNTR_Q, 12)
      |> warp("job_hunte", 176, 22)
    else
      ctx
      |> mes("[Hunter Guildmaster]")
      |> mes("*Sigh...*")
      |> mes("Come back when")
      |> mes("you're done with")
      |> mes("your preparations.")
      |> close()
      |> cutin("", 255)
    end
  end

  defp answer_from(ctx, 1, briefing) do
    ctx
    |> mes("[Hunter Guildmaster]")
    |> mes(
      "You have to hunt down certain monsters with a particular name, but you must avoid all of the traps here at the same time."
    )
    |> next()
    |> mes("[Hunter Guildmaster]")
    |> mes(
      "This is to test your ability to move swiftly and locate targets in various situations."
    )
    |> close()
    |> cutin("", 255)
    |> answer_from(2, briefing)
  end

  defp answer_from(ctx, 2, briefing) do
    ctx
    |> mes("[Hunter Guildmaster]")
    |> mes(
      "Within the given time, you will start in the 6 o'clock direction of the map, hunt the target monsters, and hit the escape switch that will appear in the center of the map."
    )
    |> next()
    |> mes("[Hunter Guildmaster]")
    |> mes(
      "You will pass if you are able to escape in the 12 o'clock direction of the map when the switch is activated."
    )
    |> close()
    |> cutin("", 255)
    |> answer_from(3, briefing)
  end

  defp answer_from(ctx, 3, briefing) do
    ctx
    |> mes("[Hunter Guildmaster]")
    |> mes(
      "Mmm. Warnings... Well, if you fall into a trap, you have to start the test over from the beginning. And only one person can take the test at a time."
    )
    |> next()
    |> mes("[Hunter Guildmaster]")
    |> mes(
      "I'll send you to the testing place. There is a waiting room, but if someone else is taking the test, you must wait in the chatroom."
    )
    |> next()
    |> mes("[Hunter Guildmaster]")
    |> mes(
      "If the person currently taking the test passes or fails, the next person waiting in the chatroom is sent to the testing area. If nobody is waiting, the test will begin as soon as you enter the chatroom."
    )
    |> close()
    |> cutin("", 255)
    |> answer_from(4, briefing)
  end

  defp answer_from(ctx, 4, :first) do
    ctx
    |> mes("[Hunter Guildmaster]")
    |> mes(
      "...Okay. I'll send you to the testing area right now. Don't blame me if you get lost or confused because you didn't listen to the explanation."
    )
    |> next()
  end

  defp answer_from(ctx, 4, :retry) do
    ctx
    |> mes("[Hunter Guildmaster]")
    |> mes("Okay, good luck.")
    |> mes("I'll send you right now...")
    |> next()
  end

  defp answer_from(ctx, _choice, _briefing), do: ctx

  defp turn_away_early_archer(ctx) do
    ctx
    |> mes("[Hunter Guildmaster]")
    |> mes("Mmm...?")
    |> mes("Why is an Archer")
    |> mes("visiting me?")
    |> next()
    |> mes("[Hunter Guildmaster]")
    |> mes(
      "I wasn't notified by the Hunter Guild about anything. You're not trying to skip the middle part of the Hunter test, are you?"
    )
    |> next()
    |> mes("[Hunter Guildmaster]")
    |> mes("Stop by once you have gathered all the items needed for the test.")
    |> close()
    |> cutin("", 255)
  end

  defp redirect_to_payon_palace(ctx) do
    ctx
    |> mes("[Hunter]")
    |> mes("Mmm?")
    |> mes("Can I help you")
    |> mes("with something?")
    |> mes("Oh, you must be")
    |> mes("a Hunter applicant.")
    |> next()
    |> mes("[Hunter]")
    |> mes(
      "If you wish to change jobs, I think you need to go visit the person at Payon Central Palace."
    )
    |> close()
    |> cutin("", 255)
  end

  defp award_proof(ctx) do
    ctx
    |> mes("[Hunter Guildmaster]")
    |> mes("Wow. You're back in one piece!")
    |> mes(
      "I mean, good job. Well then, I'll give you the item which serves as proof that you passed the test."
    )
    |> set_char_var(:HNTR_Q, 17)
    |> savepoint("payon", 104, 99)
    |> give_item(1007, 1)
    |> changequest(4012, 4013)
    |> next()
    |> mes("[Hunter Guildmaster]")
    |> mes("Well...")
    |> mes("There you go.")
    |> mes("Now hurry back to the Hunter Guild, and join us~")
    |> close()
    |> cutin("", 255)
  end

  defp remind_to_return(ctx) do
    ctx
    |> mes("[Hunter Guildmaster]")
    |> mes(
      "I see you're not in a hurry to become a Hunter. I was running around with joy, wildly brandishing my bow the first month I became a Hunter. Hehe~"
    )
    |> next()
    |> mes("[Hunter Guildmaster]")
    |> mes("Now hurry~")
    |> mes("They're waiting")
    |> mes("for you back")
    |> mes("at the Hunter Guild.")
    |> close()
    |> cutin("", 255)
  end

  defp busy(ctx) do
    ctx
    |> mes("[Hunter]")
    |> mes(
      "What do you want? I'm on an official trip and am busy at the moment. Now if you'll excuse me."
    )
    |> close()
    |> cutin("", 255)
  end
end
