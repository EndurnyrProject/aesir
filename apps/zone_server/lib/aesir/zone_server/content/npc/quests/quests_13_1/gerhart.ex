defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.Gerhart do
  @moduledoc """
  Gerhart of the Schwarzwald Republic, who collects the expedition's report at Lighthalzen.

  ## Behavior

  - Takes the Expedition Report from a player sent by the expedition commander, consuming it
    and advancing `ep13_1_edq` to the step that follows that delivery.
  - Completes quest 3093 into 3094 when the report closes the three-kingdom round.
  - Tells a player who already handed in the report that it is safely received.
  - Sends everyone else to his secretary on the second floor.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script quests/quests_13_1.txt
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "lhz_in01", x: 110, y: 174, dir: 5, sprite: 903, name: "Gerhart", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @report 11012

  # Steps in which the player is carrying the report to Gerhart.
  @awaiting_report [9, 101, 111, 102, 112]
  # Steps in which Gerhart already holds the report.
  @report_delivered [121, 103, 113, 123, 122, 13]

  # The three-kingdom round ends when the last two couriers both delivered.
  @final_steps [102, 112]
  @report_advances %{9 => 121, 101 => 103, 111 => 113}

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = mes(ctx, "[Gerhart]")
    step = get_char_var(ctx, :ep13_1_edq, 0)

    cond do
      step in @awaiting_report -> take_report(ctx, step)
      step in @report_delivered -> already_delivered(ctx)
      true -> no_time(ctx)
    end
  end

  defp take_report(ctx, step) do
    ctx =
      ctx
      |> mes("Welcome, #{char_name(ctx, 0)}. What took you so long?")
      |> next()
      |> mes("[Gerhart]")
      |> mes("Oh, who am I? Let's say... That you can make ends meet because of me.")
      |> mes("Make sense?")
      |> next()
      |> mes("[Gerhart]")
      |> mes("Do you know how long I waited for this report? *Sigh* ...Fine, just give it to me.")
      |> next()
      |> delitem(@report, 1)
      |> advance(step)

    ctx
    |> mes("...")
    |> next()
    |> mes("... ...")
    |> next()
    |> mes("... ... ...")
    |> next()
    |> mes("[Gerhart]")
    |> mes(
      "Hmmm... This report is a clear demonstration of Commander Hibba Agip's competence... Well, that's great."
    )
    |> next()
    |> mes("[Gerhart]")
    |> mes("Thank you for bringing the report.")
    |> mes("Please tell the commander to keep up the good work.")
    |> next()
    |> mes("[Gerhart]")
    |> mes("Now excuse me, I must go back to work.")
    |> close()
  end

  defp advance(ctx, step) when step in @final_steps do
    ctx
    |> set_char_var(:ep13_1_edq, 13)
    |> changequest(3093, 3094)
  end

  defp advance(ctx, step) do
    set_char_var(ctx, :ep13_1_edq, Map.fetch!(@report_advances, step))
  end

  defp already_delivered(ctx) do
    ctx
    |> mes("What is it? Do you still have business with me?")
    |> next()
    |> mes("[Gerhart]")
    |> mes("I've received the report safely.")
    |> mes("Please go back to the commander, and tell him to keep up the good work.")
    |> close()
  end

  defp no_time(ctx) do
    ctx
    |> mes("What is it? I don't have time for chitchat.")
    |> next()
    |> mes("[Gerhart]")
    |> mes(
      "If you have business with me. please talk to my secretary and schedule an appointment. My office is on the second floor."
    )
    |> close()
  end
end
