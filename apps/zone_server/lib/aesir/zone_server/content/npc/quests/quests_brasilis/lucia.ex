defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsBrasilis.Lucia do
  @moduledoc """
  Lucia recruits adventurers to capture the strange hydras at Brasilis beach.

  ## Behavior

  - Provides Hydra Balls and rewards captured hydras on a daily quest.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - og2
    - Euphy
    - Capuche
    - Daegaladh

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "brasilis",
        x: 192,
        y: 133,
        dir: 6,
        sprite: 478,
        name: "Lucia",
        scope: :shared,
        unique_name: "Lucia#brasilis"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_event("OnInit", ctx), do: initnpctimer(ctx)

  def on_event("OnTimer7000", ctx),
    do: ctx |> emotion(:surprise) |> stopnpctimer() |> initnpctimer()

  @impl true
  def on_talk(ctx) do
    if base_level(ctx) < 40 do
      ctx
      |> mes("[Lucia]")
      |> mes("Hello.")
      |> mes("I'm worried about ^FF0000Strange Hydra^000000's on")
      |> mes("the south beach.")
      |> mes("I hope some experienced adventurers")
      |> mes("will come to help.")
      |> emotion(:ohno)
      |> close()
    else
      ctx = set_local(ctx, :nQState1, checkquest(ctx, 9028))
      ctx = set_local(ctx, :nQState2, checkquest(ctx, 9029))
      quest_dialogue(ctx)
    end
  end

  defp quest_dialogue(ctx) do
    case get_local(ctx, :nQState1, 0) do
      -1 ->
        ctx = ctx |> mes("[Lucia]") |> mes("Hello.")
        offer_hunt(ctx, "Have you come here to hunt ^FF0000Strange Hydra^000000s?")

      state when state == 0 or state == 1 ->
        active_hunt(ctx)

      _ ->
        returning_hunter(ctx)
    end
  end

  defp offer_hunt(ctx, question) do
    {ctx, choice} =
      ctx
      |> mes(question)
      |> next()
      |> select(["Yes.", "No.", "^006400What is happening here?^000000"])

    case choice do
      1 ->
        ctx
        |> setquest(9028)
        |> give_item(12_408, 1)
        |> mes("[Lucia]")
        |> mes("Here, take this ^006400Hydra Ball^000000.")
        |> mes("Use it to capture a ^FF0000Strange Hydra^8B4513.^000000")
        |> mes("I hope you can do it~!")
        |> close()

      2 ->
        ctx |> mes("[Lucia]") |> mes("Ah, I misunderstood.") |> mes("See you then.") |> close()

      3 ->
        explain_hydras(ctx)

      _ ->
        ctx
    end
  end

  defp active_hunt(ctx) do
    if count_item(ctx, 6221) > 0 do
      ctx = ctx |> mes("[Lucia]") |> mes("Hello, you really did it!")

      if Rathena.truthy?(checkweight(ctx, [{11_502, 3}])) do
        reward(ctx)
      else
        ctx
        |> mes(" ")
        |> mes("I'd like to reward you,")
        |> mes("however your bags are full.")
        |> mes("Please make room and come back!")
        |> close()
      end
    else
      missing_capture(ctx)
    end
  end

  defp reward(ctx) do
    ctx =
      ctx
      |> mes("I hope you will come")
      |> mes("again to help me.")
      |> mes("Have a nice day~!")
      |> delitem(6221, 1)
      |> completequest(9028)

    ctx =
      if get_local(ctx, :nQState2, 0) > -1 do
        erasequest(ctx, 9029)
      else
        ctx
      end

    ctx = setquest(ctx, 9029)

    ctx =
      if Rathena.truthy?(checkre(ctx, 0)) do
        consumeitem(ctx, 607)
      else
        ctx
      end

    ctx = ctx |> consumeitem(12_070) |> consumeitem(12_055) |> consumeitem(12_065)

    ctx =
      if Rathena.truthy?(checkre(ctx, 0)) do
        give_item(ctx, 11_502, 3)
      else
        give_item(ctx, 505, 5)
      end

    close(ctx)
  end

  defp missing_capture(ctx) do
    ctx = mes(ctx, "[Lucia]")

    if count_item(ctx, 12_408) < 1 do
      ctx
      |> mes("Did you need another ^006400Hydra Ball^000000?")
      |> mes("I will give you one more.")
      |> give_item(12_408, 1)
      |> close()
    else
      {ctx, choice} =
        ctx
        |> mes("Any problems?")
        |> next()
        |> select(["No.", "^006400Tell me again what happened^000000"])

      case choice do
        1 -> ctx |> mes("[Lucia]") |> mes("Ok, please do me a favor.") |> close()
        2 -> explain_hydras(ctx)
        _ -> ctx
      end
    end
  end

  defp returning_hunter(ctx) do
    ctx = ctx |> mes("[Lucia]") |> mes("Oh, ^0000FF#{char_name(ctx, 0)}^000000 you're back.")
    ctx = set_local(ctx, :nCheckTime, checkquest(ctx, 9029, :playtime))

    if get_local(ctx, :nCheckTime, 0) == 0 or get_local(ctx, :nCheckTime, 0) == 1 do
      ctx
      |> mes("I'm so grateful for your help.")
      |> mes("Each ^006400Hydra Ball^000000 is provided ^006400every 24 hours^000000")
      |> mes("Please come at the appropriate time.")
      |> close()
    else
      ctx = if get_local(ctx, :nQState1, 0) > -1, do: erasequest(ctx, 9028), else: ctx
      ctx = completequest(ctx, 9029)
      offer_hunt(ctx, "Did you come here to hunt ^FF0000Strange Hydra^000000s?")
    end
  end

  defp explain_hydras(ctx) do
    ctx
    |> mes("[Lucia]")
    |> mes("One day ^FF0000Strange Hydra^000000s")
    |> mes("came here and surrounded the town.")
    |> mes(
      "We're not sure what attracted them but some say that it's because of you adventurers."
    )
    |> next()
    |> mes("[Lucia]")
    |> mes("In any case, to contain the ^FF0000Strange Hydra^000000s,")
    |> mes("you have to use this specially designed tool a.k.a. a ^8B4513Hydra Ball^000000")
    |> next()
    |> mes("[Lucia]")
    |> mes("If you still have the ^006400Hydra Ball^000000,")
    |> mes("please use it on the ^FF0000Strange Hydra^000000s that")
    |> mes("you can find at the beach.")
    |> mes("If you are lucky, the tool will work perfectly.")
    |> next()
    |> mes("[Lucia]")
    |> mes("I hope many adventurers")
    |> mes("volunteer for this job.")
    |> mes(" ")
    |> mes("I really hate Hydra!")
    |> emotion(:cry)
    |> close()
  end
end
