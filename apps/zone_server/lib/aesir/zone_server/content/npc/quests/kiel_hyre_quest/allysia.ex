defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.Allysia do
  @moduledoc """
  Allysia explains Kiel Hyre’s three generations of robots.

  ## Behavior

  - Rejects visitors before the mansion stage and offers a choice of robot histories afterward.
  - Falls silent after the investigation advances and clears her portrait when the conversation ends.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf (Script)
    - DZeroX (Timer)
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "kh_mansion", x: 18, y: 30, dir: 4, sprite: 894, name: "Allysia", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if get_char_var(ctx, :KielHyreQuest, 0) < 46 do
      ctx
      |> mes("[Allysia]")
      |> mes("Who are you?")
      |> mes("How did you get here?")
      |> mes("Go away")
      |> close()
    else
      ctx = cutin(ctx, "kh_ellisia", 2)

      if get_char_var(ctx, :KielHyreQuest, 0) < 70 do
        offer_history(ctx)
      else
        ctx
        |> mes("[Allysia]")
        |> mes("......")
        |> mes(".........")
        |> mes("............")
        |> close()
        |> cutin("", 255)
      end
    end
  end

  defp offer_history(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Allysia]")
      |> mes("You must be surprised")
      |> mes("by everything that's been")
      |> mes("happening. Maybe everything")
      |> mes("would be easier to understand")
      |> mes("if I explained about robots?")
      |> next()
      |> select(["Yes", "No"])

    case choice do
      1 ->
        choose_generation(ctx)

      2 ->
        finish_history(ctx)

      _ ->
        ctx
    end
  end

  defp choose_generation(ctx) do
    {ctx, generation} =
      ctx
      |> mes("[Allysia]")
      |> mes("The robots you've been")
      |> mes("encountering are automated")
      |> mes("mechanical puppets that can")
      |> mes("independantly think and operate.")
      |> mes("Many sages have tried to develop")
      |> mes("their own robots, but have failed.")
      |> next()
      |> mes("[Allysia]")
      |> mes("My master, Kiel Hyre, has")
      |> mes("been studying robotics since")
      |> mes("he was twenty years old, and")
      |> mes("has developed three different")
      |> mes("generations of robots, the first,")
      |> mes("second, and third generations.")
      |> next()
      |> select(["First Generation", "Second Generation", "Third Generation"])

    case generation do
      1 ->
        explain_first_generation(ctx)

      2 ->
        explain_second_generation(ctx)

      3 ->
        explain_third_generation(ctx)

      _ ->
        ctx
    end
  end

  defp explain_first_generation(ctx) do
    ctx
    |> mes("[Allysia]")
    |> mes("I am a good example of one")
    |> mes("of Kiel Hyre's First Generation")
    |> mes("robots. I was constructed using")
    |> mes("a heavy mechanical framework,")
    |> mes("a robotic heart, and chemically")
    |> mes("synthesized skin covering.")
    |> next()
    |> mes("[Allysia]")
    |> mes("My central processing unit,")
    |> mes("equivalent to your brain, is")
    |> mes("essentially a Memory Scroll")
    |> mes("based on the design of the")
    |> mes("Magic Spell Scrolls that you")
    |> mes("adventurers use in battle.")
    |> next()
    |> mes("[Allysia]")
    |> mes("I'm the oldest type of")
    |> mes("humanoid robot, so I weigh")
    |> mes("a lot, and my mind can only")
    |> mes("process a limited amount of")
    |> mes("data. Therefore, I can't express")
    |> mes("emotion similarly to a human.")
    |> next()
    |> finish_history()
  end

  defp explain_second_generation(ctx) do
    ctx
    |> mes("[Allysia]")
    |> mes("The First Generation robots")
    |> mes("were developed from mostly")
    |> mes("mechanical parts, but the")
    |> mes("Second Generation robots")
    |> mes("incorporated Homunculus")
    |> mes("science and technology.")
    |> next()
    |> mes("[Allysia]")
    |> mes("Second Generation robots")
    |> mes("are more life-like since they")
    |> mes("have artifically created skin")
    |> mes("and flesh, although they still")
    |> mes("are constructed from a heavy")
    |> mes("mechanical framework.")
    |> next()
    |> mes("[Allysia]")
    |> mes("Sage elemental scroll")
    |> mes("technology was also used")
    |> mes("to develop the Condensed")
    |> mes("Memory Scroll, a central")
    |> mes("processing unit superior to that")
    |> mes("used in First Generation robots.")
    |> next()
    |> mes("[Allysia]")
    |> mes("Although Condensed Memory")
    |> mes("Scrolls were 100,000 times")
    |> mes("more powerful than ordinary")
    |> mes("Memory Scrolls, they were")
    |> mes("problematic and were prone")
    |> mes("to too many error problems.")
    |> next()
    |> mes("[Allysia]")
    |> mes("Second Generation robots")
    |> mes("were capable of expressing")
    |> mes("human-like emotion, but their")
    |> mes("production halted after six")
    |> mes("years because they were")
    |> mes("considered faulty.")
    |> next()
    |> finish_history()
  end

  defp explain_third_generation(ctx) do
    ctx
    |> mes("[Allysia]")
    |> mes("Third Generation robots")
    |> mes("were mostly designed by")
    |> mes("Kiel Hyre's son, Kiehl,")
    |> mes("and don't use a mechanical")
    |> mes("framework at all: the entire")
    |> mes("body is basically a homunculus.")
    |> next()
    |> mes("[Allysia]")
    |> mes("With their organic bodies")
    |> mes("and advanced artificial hearts")
    |> mes("made from imitation Ymir Heart")
    |> mes("Pieces, they can experience")
    |> mes("physiologic phenomena")
    |> mes("just like ordinary humans.")
    |> next()
    |> mes("[Allysia]")
    |> mes("Kiehl was able to develop")
    |> mes("a more stable form of the")
    |> mes("Condensed Memory Scroll")
    |> mes("which does not suffer from")
    |> mes("critical errors, and can be")
    |> mes("cheaply mass processed.")
    |> next()
    |> mes("[Allysia]")
    |> mes("Elly is actually a Third")
    |> mes("Generation prototype. Once")
    |> mes("we optimize the prototypes,")
    |> mes("we will begin mass production.")
    |> mes("In fact, the academy is our")
    |> mes("prototype testing ground.")
    |> next()
    |> mes("[Allysia]")
    |> mes("The fact that out prototype")
    |> mes("robots can interact just like")
    |> mes("real humans is proof of our")
    |> mes("success in robotics.")
    |> next()
    |> finish_history()
  end

  defp finish_history(ctx) do
    ctx
    |> mes("[Allysia]")
    |> mes("Please let me know if")
    |> mes("you'd like to learn more")
    |> mes("about Kiel Hyre's robots.")
    |> close()
    |> cutin("", 255)
  end
end
