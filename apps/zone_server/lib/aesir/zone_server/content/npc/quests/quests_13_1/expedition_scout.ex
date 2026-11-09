defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.ExpeditionScout do
  @moduledoc """
  The Third Scout Party member of the expedition, who trades the report pages he found for a
  day of searching.

  ## Behavior

  - Greets every visitor and offers three options: the search results, chitchat or leaving.
  - The search results are only shared on quest step 71 or 72; anyone else is threatened with
    arrest, and while a search round is still running the scout asks the player to come back.
  - Otherwise rolls for the pages found this round (0, 2, 3 or 5), grants them as Report
    Sheets and restarts quest 3091, advancing 3090 to 3091 the first time.
  - Chitchat is refused while on duty, and quitting just closes the dialog.

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
      %{
        map: "man_fild01",
        x: 315,
        y: 95,
        dir: 3,
        sprite: 707,
        name: "Expedition Scout",
        scope: :shared,
        unique_name: "Expedition Scout#1"
      },
      %{
        map: "man_fild03",
        x: 202,
        y: 251,
        dir: 3,
        sprite: 707,
        name: "Expedition Scout",
        scope: :shared,
        unique_name: "Expedition Scout#2"
      },
      %{
        map: "spl_fild02",
        x: 295,
        y: 368,
        dir: 3,
        sprite: 707,
        name: "Expedition Scout",
        scope: :shared,
        unique_name: "Expedition Scout#3"
      },
      %{
        map: "spl_fild03",
        x: 172,
        y: 71,
        dir: 3,
        sprite: 707,
        name: "Expedition Scout",
        scope: :shared,
        unique_name: "Expedition Scout#4"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @report_page 6040
  @search_quest 3090
  @round_quest 3091

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    playtime = checkquest(ctx, @round_quest, :playtime)

    {ctx, choice} =
      ctx
      |> mes("[Expedition Scout]")
      |> mes(
        "Good day. I'm from the Third Scout Party under direct command of the commander of the Midgard Expedition."
      )
      |> next()
      |> mes("[Expedition Scout]")
      |> mes("I've been ordered by Instructor Igrid to conduct a search for something.")
      |> next()
      |> select(["Ask about search results.", "Chitchat.", "Quit."])

    case choice do
      1 -> search_results(ctx, playtime)
      2 -> on_duty(ctx)
      3 -> close(ctx)
      _ -> ctx
    end
  end

  defp search_results(ctx, playtime) do
    if get_char_var(ctx, :ep13_1_edq, 0) in [71, 72] do
      report_run(ctx, playtime)
    else
      not_a_soldier(ctx)
    end
  end

  defp report_run(ctx, playtime) do
    ctx =
      ctx
      |> mes("[Expedition Scout]")
      |> mes("Oh, you must be#{char_name(ctx, 0)}. I heard that you'll be delivering the report.")
      |> next()

    if playtime in [0, 1] do
      still_searching(ctx)
    else
      pages = pages_found()

      ctx =
        if pages > 0 do
          found_pages(ctx, pages)
        else
          ctx
          |> mes("[Expedition Scout]")
          |> mes("I'm doing my best, but I haven't found any pages yet.")
          |> next()
        end

      ctx
      |> restart_round(playtime)
      |> mes("[Expedition Scout]")
      |> mes("Well then, keep up the good work!")
      |> close()
    end
  end

  # The roll decides how many pages of the report the scout hands over on this round.
  defp pages_found do
    case Enum.random(1..6) do
      3 -> 3
      4 -> 5
      roll when roll in [1, 6] -> 2
      _empty -> 0
    end
  end

  defp found_pages(ctx, pages) do
    ctx
    |> mes("[Expedition Scout]")
    |> mes("Good news! I've found #{pages} pieces of paper that appear to be part of the report.")
    |> next()
    |> give_item(@report_page, pages)
  end

  defp restart_round(ctx, -1), do: changequest(ctx, @search_quest, @round_quest)

  defp restart_round(ctx, _playtime) do
    ctx |> erasequest(@round_quest) |> setquest(@round_quest)
  end

  defp still_searching(ctx) do
    ctx
    |> mes("[Expedition Scout]")
    |> mes(
      "Searching for lost pages was tougher then I expected. Please come back later when I'm finished making one round."
    )
    |> close()
  end

  defp not_a_soldier(ctx) do
    ctx
    |> mes("[Expedition Scout]")
    |> mes(
      "Who are you? Why do you want to know about our search results? Are you from the army?"
    )
    |> next()
    |> mes("[Expedition Scout]")
    |> mes("Man, don't you know that you can be arrested for interrupting a military operation?")
    |> next()
    |> mes("[Expedition Scout]")
    |> mes("Please leave immediately.")
    |> close()
  end

  defp on_duty(ctx) do
    ctx
    |> mes("[Expedition Scout]")
    |> mes("I'm sorry, but I'm on duty. Why don't we talk later when I'm off-duty?")
    |> close()
  end
end
