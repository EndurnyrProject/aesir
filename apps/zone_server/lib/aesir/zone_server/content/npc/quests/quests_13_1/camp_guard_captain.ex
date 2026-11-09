defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.CampGuardCaptain do
  @moduledoc """
  Captain of the expedition camp guard, who takes reports of the fairy and tree giant
  sightings.

  ## Behavior

  - Asks for the visit's business first, then checks the two report quests.
  - Accepts the small fairy sighting (quest 2158) or the tree giant sighting (quest 2159)
    and rewards 90,000/70,000 base experience depending on the mechanics mode.
  - Brushes off a player who has nothing to report, already filed both reports, or never
    took either quest.

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
        map: "mid_camp",
        x: 212,
        y: 237,
        dir: 5,
        sprite: 852,
        name: "Camp Guard Captain",
        scope: :shared,
        unique_name: "Camp Guard Captain#man1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @fairy_report 2158
  @tree_giant_report 2159

  @renewal_exp 90_000
  @pre_renewal_exp 70_000

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx =
      ctx
      |> mes("[Captain]")
      |> mes("Good day. I'm here to protect the")
      |> mes("peace and safety of explorers")
      |> mes("working for United Midgard.")
      |> mes("How may I help you?")
      |> next()

    cond do
      both_reports_filed?(ctx) ->
        nothing_to_report(ctx)

      checkquest(ctx, @fairy_report) == 1 ->
        ctx
        |> report(
          @fairy_report,
          "- You report your encounter with a small fairy in the Splandid area to the guard captain. -"
        )

      checkquest(ctx, @fairy_report) == -1 ->
        nothing_to_report(ctx)

      checkquest(ctx, @tree_giant_report) == 1 ->
        ctx
        |> report(
          @tree_giant_report,
          "- You report your encounter with a tree giant in the Manuk area to the guard captain. -"
        )

      true ->
        nothing_to_report(ctx)
    end
  end

  defp both_reports_filed?(ctx) do
    checkquest(ctx, @fairy_report) == 2 and checkquest(ctx, @tree_giant_report) == 2
  end

  defp report(ctx, quest, opening_line) do
    exp = if Rathena.truthy?(checkre(ctx, 3)), do: @renewal_exp, else: @pre_renewal_exp

    ctx
    |> mes(opening_line)
    |> next()
    |> mes("[Captain]")
    |> mes("That sounds very important.")
    |> mes(
      "It's too early to say this, but we might have to dispatch an investigation group to the area."
    )
    |> next()
    |> mes("[Captain]")
    |> mes("I'll discuss this more with the expedition management.")
    |> mes("Thank you for your valuable information.")
    |> completequest(quest)
    |> getexp(exp, 0)
    |> close()
  end

  defp nothing_to_report(ctx) do
    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Oh, nothing.")
    |> mes("Sorry to bother you.")
    |> close()
  end
end
