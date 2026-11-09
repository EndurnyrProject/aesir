defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.Quests131.Laur do
  @moduledoc """
  Laur, aide to the Home Minister of Rune-Midgarts, who collects the expedition's report
  beyond the time-space gap.

  ## Behavior

  - Takes the Expedition Report from a player sent by the expedition commander, consuming
    it and advancing `ep13_1_edq` to the step that follows that delivery.
  - Completes quest 3093 into 3094 when the report closes the three-kingdom round.
  - Reminds a player who already handed in the report that the delivery is done.
  - Introduces the expedition to everyone else.

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
      %{map: "prt_cas", x: 108, y: 265, dir: 5, sprite: 57, name: "Laur", scope: :renewal},
      %{map: "prt_castle", x: 88, y: 165, dir: 3, sprite: 57, name: "Laur", scope: :pre_renewal}
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @report 11012

  # Steps in which the player is carrying the report to Laur.
  @awaiting_report [9, 111, 121, 113, 123]
  # Steps in which Laur already holds the report.
  @report_delivered [101, 102, 103, 112, 122, 13]

  # The three-kingdom round ends when the last two couriers both delivered.
  @final_steps [113, 123]
  @report_advances %{9 => 101, 111 => 112, 121 => 122}

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = mes(ctx, "[Laur]")
    step = get_char_var(ctx, :ep13_1_edq, 0)

    cond do
      step in @awaiting_report -> take_report(ctx, step)
      step in @report_delivered -> already_delivered(ctx)
      true -> introduction(ctx)
    end
  end

  defp take_report(ctx, step) do
    ctx =
      ctx
      |> mes(
        "I'm Laur, the aide of the Home Minister of the Rune-Midgarts Kingdom. Do you have any business with me?"
      )
      |> next()
      |> mes("[Laur]")
      |> mes(
        "Oh, you brought me the report from the Midgard Expedition. What took you so long? I received a message about your departure a long time ago."
      )
      |> next()
      |> mes("[Laur]")
      |> mes(
        "Well, tell the commander that I'm not happy with your tardiness. Now, give me the report."
      )
      |> next()
      |> mes("[Laur]")
      |> mes(
        "I knew it was the wrong idea to out a mercenary in the commander position. See, nothing is done on time. Gosh!"
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
    |> mes("[Laur]")
    |> mes(
      "*Ahem Ahem* Thank you for bringing me the report. I guess I was wrong about the commander. This report is actually very well done."
    )
    |> next()
    |> mes("[Laur]")
    |> mes(
      "But don't forget to tell him that I need the expedition reports on time from now on. Alright? *Ahem*"
    )
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
    |> mes(
      "Why are you back? You've delivered the report to me already. Are you suffering from amnesia or something?"
    )
    |> next()
    |> mes("[Laur]")
    |> mes("You should leave and go back to your work.")
    |> close()
  end

  defp introduction(ctx) do
    ctx
    |> mes(
      "I'm Laur, the aide of the Home Minister of the Rune-Midgarts Kingdom. Do you have any business with me?"
    )
    |> next()
    |> mes("[Laur]")
    |> mes(
      "Can you sense the great disorder occuring on the Midgard Continent and the Rune-Midgarts' Kingdom?"
    )
    |> next()
    |> mes("[Laur]")
    |> mes("Still, there always a silver lining, no matter how dangerous this world may become.")
    |> next()
    |> mes("[Laur]")
    |> mes(
      "There is hope and opportunity beyond the chaos, and I see the world beyond the time-space gap as a source of new hope."
    )
    |> close()
  end
end
