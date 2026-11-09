defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.Nuria do
  @moduledoc """
  Priest Nuria of Arunafeltz, who collects the expedition's report at the Rune-Midgarts
  temple.

  ## Behavior

  - Takes the Expedition Report from a player sent by the expedition commander, consuming it
    and advancing `ep13_1_edq` to the step that follows that delivery.
  - Completes quest 3093 into 3094 when the report closes the three-kingdom round.
  - Reminds a player who already handed in the report that the delivery is done.
  - Blesses everyone else.

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
      %{map: "ra_temple", x: 122, y: 174, dir: 3, sprite: 918, name: "Nuria", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @report 11012

  # Steps in which the player is carrying the report to Nuria.
  @awaiting_report [9, 101, 121, 122, 103]
  # Steps in which Nuria already holds the report.
  @report_delivered [111, 102, 112, 123, 113, 13]

  # The three-kingdom round ends when the last two couriers both delivered.
  @final_steps [122, 103]
  @report_advances %{9 => 111, 101 => 102, 121 => 123}

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = mes(ctx, "[Nuria]")
    step = get_char_var(ctx, :ep13_1_edq, 0)

    cond do
      step in @awaiting_report -> take_report(ctx, step)
      step in @report_delivered -> already_delivered(ctx)
      true -> greeting(ctx)
    end
  end

  defp take_report(ctx, step) do
    ctx =
      ctx
      |> mes("Welcome, stranger. How can I help you?")
      |> next()
      |> mes("[Nuria]")
      |> mes(
        "Oh, I see. You've brought me a report from the expedition beyond the time-space gap."
      )
      |> next()
      |> mes("[Nuria]")
      |> mes(
        "I regret admitting that you've brought it much later than I expected, but... I'm glad it is here safely. Please give it to me."
      )
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
    |> mes("[Nuria]")
    |> mes(
      "I'm happy to see that they've made good progress so far. Please tell the commander to keep up the good work."
    )
    |> next()
    |> mes("[Nuria]")
    |> mes("Excuse me, but it's time to pray now. Please be safe on your travels.")
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
    |> mes("Oh, right, I already received the report from you. Don't worry, you didn't forget.")
    |> next()
    |> mes("[Nuria]")
    |> mes("Please be safe on your way back to the expedition camp.")
    |> close()
  end

  defp greeting(ctx) do
    ctx
    |> mes("Good day, stranger. May Freya bless you.")
    |> close()
  end
end
