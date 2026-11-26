defmodule Aesir.ZoneServer.Content.Npc.Quests.Seals.SleipnirSeal.Researcher11136 do
  @moduledoc """
  Aadin studies the Feather of Angel Wing and sends the player to Payon to learn the origin
  of Sleipnir during the Sleipnir Seal quest.

  ## Behavior

  - Outside the Sleipnir seal phase, or before the player is assigned to him, he only talks
    about how myths change over time.
  - A newly assigned assistant is asked to travel to Payon and memorize the story of
    Sleipnir's origin; he reminds the player while they have not yet gone.
  - The first retelling is judged incomplete and the player is sent back to Payon.
  - The complete retelling is accepted and the player's research task is marked done.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - L0ne_W0lf
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "que_god01",
        x: 11,
        y: 136,
        dir: 6,
        sprite: 742,
        name: "Researcher",
        scope: :shared,
        unique_name: "Researcher#G2"
      }
    ]

  @assigned_stages [21, 32, 43, 14]
  @completed_stage %{21 => 22, 32 => 33, 43 => 44, 14 => 50}

  @impl true
  def on_talk(ctx) do
    if get_server_var(ctx, "God1", 0) < get_server_temp_var(ctx, "god_check2", 0) do
      ctx = assign_first_task(ctx)

      if get_char_var(ctx, :god_sl_1, 0) in @assigned_stages do
        research(ctx, get_char_var(ctx, :god_sl_2, 0))
      else
        myths(ctx)
      end
    else
      myths(ctx)
    end
  end

  defp assign_first_task(ctx) do
    if get_char_var(ctx, :god_sl_1, 0) == 2, do: set_char_var(ctx, :god_sl_1, 21), else: ctx
  end

  defp research(ctx, 0) do
    ctx
    |> mes("[Aadin]")
    |> mes("^333333*Yawn~*^000000")
    |> mes("Hmmmmm?")
    |> mes("Ah...")
    |> next()
    |> mes("[Aadin]")
    |> mes("Nice to meet you.")
    |> mes(
      "You're the temporary assistant, right? That's great, all of us are having a hard time working"
    )
    |> mes("without much help.")
    |> next()
    |> mes("[Aadin]")
    |> mes("Okay...")
    |> mes("Let me explain")
    |> mes("to you the project")
    |> mes("that I'm working on.")
    |> next()
    |> mes("[Aadin]")
    |> mes(
      "I'm trying to find out everything I can about the '^FF0000Feather of Angel Wing^000000.' Supposedly, it's one of"
    )
    |> mes("the parts of 'Sleipnir.'")
    |> next()
    |> mes("[Aadin]")
    |> mes("Right now, I'm")
    |> mes("focusing on studying")
    |> mes("the background story of this feather, as well as how it came")
    |> mes("to be a material for a godly artifact.")
    |> next()
    |> mes("[Aadin]")
    |> mes(
      "I was recently told that there is a person in Payon who actually knows this story. Very few people in the world are privy to having such knowledge."
    )
    |> next()
    |> mes("[Aadin]")
    |> mes("Now, we don't have enough")
    |> mes(
      "staff for me to send someone to Payon. Also, I don't feel safe taking this feather around with me."
    )
    |> next()
    |> mes("[Aadin]")
    |> mes(
      "It shouldn't be that difficult to find the person who knows about Sleipnir's origin. However, you must memorize every single"
    )
    |> mes("word of the story.")
    |> next()
    |> mes("[Aadin]")
    |> mes("The results of this research could be affected by the words you deliver to me.")
    |> next()
    |> mes("[Aadin]")
    |> mes("Thank you for the trouble.")
    |> mes(
      "There's no real time limit for this task, but the sooner you complete it, the better."
    )
    |> next()
    |> mes("[Aadin]")
    |> mes("Have a safe trip~")
    |> set_char_var(:god_sl_2, 1)
    |> close()
  end

  defp research(ctx, 1) do
    ctx
    |> mes("[Aadin]")
    |> mes("Mmm...?")
    |> mes("You haven't left for Payon yet to find the man who knows of Sleipnir's origin?")
    |> next()
    |> mes("[Aadin]")
    |> mes("Please leave for")
    |> mes("Payon as soon as")
    |> mes(
      "possible so that I can get the information that I need for my research. Thank you, and have"
    )
    |> mes("a safe trip.")
    |> close()
  end

  defp research(ctx, 2) do
    ctx
    |> mes("[Aadin]")
    |> mes("Ah, you're back. So have you memorized the story?")
    |> listen_to_story()
    |> mes("[Aadin]")
    |> mes("Hmm, I see.")
    |> mes("Fascinating.")
    |> mes("However, I'm sure")
    |> mes("you've missed some")
    |> mes("important detail.")
    |> next()
    |> mes("[Aadin]")
    |> mes(
      "Are you sure you've listened to the tale in its entirety? I'm sorry to ask this of you, but would you go to Payon and listen to this story once more?"
    )
    |> set_char_var(:god_sl_2, 3)
    |> close()
  end

  defp research(ctx, 3) do
    ctx
    |> mes("[Aadin]")
    |> mes("Mm...?")
    |> mes("You haven't left")
    |> mes("for Payon yet...?")
    |> mes("I hope you can")
    |> mes("tell me the rest")
    |> mes("of the story soon.")
    |> next()
    |> mes("[Aadin]")
    |> mes("In the meantime, I will try to complete as much of my research")
    |> mes("as I can with the story details that you've already brought.")
    |> close()
  end

  defp research(ctx, 4) do
    {ctx, choice} =
      ctx
      |> mes("[Aadin]")
      |> mes("Ah, you're back.")
      |> mes("So have you")
      |> mes("memorized the story?")
      |> listen_to_story()
      |> mes("[Aadin]")
      |> mes("Hmm, I see.")
      |> mes("Fascinating.")
      |> mes("you've missed some")
      |> mes("important detail.")
      |> next()
      |> select(["Well, um...", "Impossible!"])

    case choice do
      1 ->
        ctx
        |> mes("[Aadin]")
        |> mes("Hmm.")
        |> mes("No, wait...")
        |> mes("That was the")
        |> mes("complete story.")
        |> mes("My apologies~")
        |> accept_story()

      2 ->
        ctx
        |> mes("[Aadin]")
        |> mes("Ah~")
        |> mes("I stand corrected.")
        |> mes("Thank you for pointing")
        |> mes("out my error in judgment.")
        |> accept_story()

      _ ->
        ctx
    end
  end

  defp research(ctx, _stage), do: ctx

  defp listen_to_story(ctx) do
    ctx
    |> next()
    |> mes("[Aadin]")
    |> mes(
      "I know it'd be much easier if this tale was already written, but you must understand that many stories regarding the gods are only orally transmitted."
    )
    |> next()
    |> mes("[Aadin]")
    |> mes("Alright,")
    |> mes("I'm listening.")
    |> mes("Please let me")
    |> mes("know what you've learned.")
    |> next()
    |> mes("[Aadin]")
    |> mes("...")
    |> mes("......")
    |> next()
    |> mes("[Aadin]")
    |> mes("...")
    |> mes("......")
    |> mes(".........")
    |> next()
    |> mes("[Aadin]")
    |> mes("...")
    |> mes("......")
    |> mes(".........")
    |> mes("............")
    |> next()
  end

  defp accept_story(ctx) do
    ctx =
      ctx
      |> next()
      |> mes("[Aadin]")
      |> mes(
        "Yes, it seems that the story you've just told me should be authentic. Of course, it's understandable if little changes are made, depending on the storyteller."
      )
      |> next()
      |> mes("[Aadin]")
      |> mes(
        "Surely, I'll be able to answer some of my most important questions with the information you've brought to me, though it still won't be easy."
      )
      |> next()
      |> mes("[Aadin]")
      |> mes(
        "After all, finding answers tends to cause new questions to arise. Nonetheless, I thank you for your help."
      )
      |> set_char_var(:god_sl_2, 0)

    case Map.fetch(@completed_stage, get_char_var(ctx, :god_sl_1, 0)) do
      {:ok, stage} -> ctx |> set_char_var(:god_sl_1, stage) |> close()
      :error -> close(ctx)
    end
  end

  defp myths(ctx) do
    ctx
    |> mes("[Aadin]")
    |> mes("Sometimes, different versions of the same myth or legend arise.")
    |> next()
    |> mes("[Aadin]")
    |> mes(
      "Although myths, as they change with time, may conflict with each other, the fundamental basis of these stories is what makes them timeless."
    )
    |> close()
  end
end
