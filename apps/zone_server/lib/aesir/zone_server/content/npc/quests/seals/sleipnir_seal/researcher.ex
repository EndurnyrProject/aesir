defmodule Aesir.ZoneServer.Content.Npc.Quests.Seals.SleipnirSeal.Researcher do
  @moduledoc """
  Hallandaute, a researcher studying the Wheel of the Unknown, gives one of the Sleipnir Seal
  quest's research assistant tasks.

  ## Behavior

  - Outside the Sleipnir seal phase, or when the player is not on one of his research steps, he
    only talks about needing the right assistant.
  - A player fresh from Kirin is assigned to him first.
  - He sends the player to visit Metto in Juno and waits for news.
  - Hearing that Metto became a mad scientist moves the task on.
  - Afterwards he is usually busy; at random he explains his research, finishes the task and
    advances the player to the next researcher.

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
        x: 66,
        y: 125,
        dir: 6,
        sprite: 89,
        name: "Researcher",
        scope: :shared,
        unique_name: "Researcher#G1"
      }
    ]

  @research_steps [11, 22, 33, 44]
  @next_step %{11 => 12, 22 => 23, 33 => 34, 44 => 50}

  @impl true
  def on_talk(ctx) do
    if get_server_var(ctx, "God1", 0) < get_server_temp_var(ctx, "god_check2", 0) do
      ctx = assign_from_kirin(ctx)

      if get_char_var(ctx, :god_sl_1, 0) in @research_steps do
        research_task(ctx, get_char_var(ctx, :god_sl_2, 0))
      else
        needs_assistant(ctx)
      end
    else
      needs_assistant(ctx)
    end
  end

  defp assign_from_kirin(ctx) do
    if get_char_var(ctx, :god_sl_1, 0) == 2, do: set_char_var(ctx, :god_sl_1, 11), else: ctx
  end

  defp research_task(ctx, 0) do
    ctx
    |> mes("[Hallandaute]")
    |> mes(
      "Ah, are you the one whom Ms. Kirin referred? Yes, she said you were going to help me in my research."
    )
    |> next()
    |> mes("[Hallandaute]")
    |> mes("Frankly, we don't really need anyone who doesn't specialize")
    |> mes("in our field of study.")
    |> next()
    |> mes("[Hallandaute]")
    |> mes(
      "But if you don't mind helping us out by doing little, menial tasks, then it'd probably bring some relief to our workload."
    )
    |> next()
    |> mes("[Hallandaute]")
    |> mes("Now...")
    |> mes("What would be")
    |> mes("a good job for you?")
    |> mes("Let me think...")
    |> next()
    |> mes("[Hallandaute]")
    |> mes("I got it!")
    |> mes(
      "Why don't you go and visit ^FF0000Metto^000000 for me? Please bring me any news that he'd like to report."
    )
    |> next()
    |> mes("[Hallandaute]")
    |> mes(
      "Since he's working on a project similar to mine, he might be in a position to help me. Metto lives in Juno, so you can easily find me."
    )
    |> set_char_var(:god_sl_2, 1)
    |> close()
  end

  defp research_task(ctx, 1), do: metto_news(ctx, get_char_var(ctx, :metto_q, 0))

  defp research_task(ctx, 2) do
    if Enum.random(1..10) == 7, do: explain_research(ctx), else: busy(ctx)
  end

  defp research_task(ctx, _god_sl_2) do
    ctx
    |> mes("[Hallandaute]")
    |> mes("Hmmm...")
    |> mes("How does this work?")
    |> mes("There's still too much we don't know about the godly artifacts. ^333333*Sigh*^000000")
    |> close()
  end

  defp metto_news(ctx, 0) do
    ctx
    |> mes("[Hallandaute]")
    |> mes(
      "I guess you haven't found Metto yet. Although he might be a little over enthusiastic at times, he's not a bad guy at all."
    )
    |> next()
    |> mes("[Hallandaute]")
    |> mes(
      "We've been friends for a long time after working in the same field for so long. I wonder how he's doing?"
    )
    |> next()
    |> mes("[Hallandaute]")
    |> mes(
      "Anyway, just ask him about any progress on his research. And if he happens to ask you for help, please lend him your assistance."
    )
    |> close()
  end

  defp metto_news(ctx, metto_q) when metto_q < 9 do
    ctx
    |> mes("[Hallandaute]")
    |> mes("Hmmm...")
    |> mes("So how's Metto?")
    |> mes("Hmm? It seems like")
    |> mes("he has changed...")
    |> close()
  end

  defp metto_news(ctx, _metto_q) do
    ctx
    |> mes("[Hallandaute]")
    |> mes("Hmmm...")
    |> mes("So how's Metto?")
    |> next()
    |> mes("[Hallandaute]")
    |> mes("A mad scientist?")
    |> mes(
      "That doesn't sound right. In my wildest dreams, I never would have suspected Metto of turning out that way..."
    )
    |> emotion(:scratch)
    |> next()
    |> mes("[Hallandaute]")
    |> mes("Huh. That's...")
    |> mes(
      "That's too bad. I don't know what to say. We used to go watch movies and celebrate our birthdays together. P-please give me a moment..."
    )
    |> emotion(:think)
    |> set_char_var(:god_sl_2, 2)
    |> close()
  end

  defp explain_research(ctx) do
    ctx
    |> mes("[Hallandaute]")
    |> mes("Ah...")
    |> mes("You came back.")
    |> mes("Alright, let me give you the gist of what I'm researching.")
    |> next()
    |> mes("[Hallandaute]")
    |> mes(
      "I'm trying to learn more about the '^FF0000Wheel of the Unknown^000000,' which was discovered to be a piece of the artifact known as ^FF0000Sleipnir^000000."
    )
    |> next()
    |> mes("[Hallandaute]")
    |> mes("It looks like")
    |> mes("a normal cogwheel...")
    |> mes("But I can't figure out how it's supposed to work.")
    |> next()
    |> mes("[Hallandaute]")
    |> mes("The most peculiar thing of all about this cogwheel is the metal")
    |> mes("of which it is composed.")
    |> next()
    |> mes("[Hallandaute]")
    |> mes(
      "It looks and feels like steel,but extreme heat and cold don't affect it. It also cannot be dented by any kind of impact or force I can apply to it."
    )
    |> next()
    |> mes("[Hallandaute]")
    |> mes(
      "Sometimes, I find that the Wheel of the Unknown resonates with certain objects, but I haven't got it to occur all of the time."
    )
    |> next()
    |> mes("[Hallandaute]")
    |> mes(
      "I'm guessing that I'm missing some sort of special condition that will make the Wheel of the Unknown resonate with specific materials."
    )
    |> next()
    |> mes("[Hallandaute]")
    |> mes(
      "Anyway, I thank you for helping me out earlier. That's basically all I needed, so please talk to the other researchers and see if they need any assistance."
    )
    |> set_char_var(:god_sl_2, 0)
    |> advance_step()
    |> close()
  end

  defp advance_step(ctx) do
    case Map.fetch(@next_step, get_char_var(ctx, :god_sl_1, 0)) do
      {:ok, step} -> set_char_var(ctx, :god_sl_1, step)
      :error -> ctx
    end
  end

  defp busy(ctx) do
    ctx
    |> mes("[Hallandaute]")
    |> mes("Oh, sorry.")
    |> mes("I'm quite busy compiling all of this information at the moment.")
    |> next()
    |> mes("[Hallandaute]")
    |> mes("Let's see...")
    |> mes("Now how would I...")
    |> mes("^333333*Mumble mumble*^000000")
    |> close()
  end

  defp needs_assistant(ctx) do
    ctx
    |> mes("[Hallandaute]")
    |> mes("It's not easy, working on this alone. Having an extra pair of hands is always good.")
    |> next()
    |> mes("[Hallandaute]")
    |> mes(
      "Right now, I just need someone with whom I can share the workload. Still, different assistants might be better depending on the project."
    )
    |> next()
    |> mes("[Hallandaute]")
    |> mes(
      "Basically, if an assistant is especially trained in the field related to my current research project, he'll probably be more useful than someone who's not."
    )
    |> next()
    |> mes("[Hallandaute]")
    |> mes(
      "Of course, there are people who are good at everything. But since those are rare, I try to choose just the right assistant for each of my projects."
    )
    |> close()
  end
end
