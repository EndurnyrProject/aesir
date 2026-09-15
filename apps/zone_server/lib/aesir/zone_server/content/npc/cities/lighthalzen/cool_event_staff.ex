defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.CoolEventStaff do
  @moduledoc """
  Explains the Cool Event Corporation headquarters and dungeon teleport election.

  ## Behavior

  - Explains why the corporation is operating from temporary headquarters.
  - Describes the dungeon teleport vote and reports eligibility based on the Lighthalzen boss variable.

  ## Credits

  - Original from rAthena, authors and Contributors
    - erKURITA
    - Au{R}oN (Translated by Alan)
    - $ephiroth

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lhz_in02",
        x: 36,
        y: 274,
        dir: 4,
        sprite: 831,
        name: "Cool Event Staff",
        scope: :shared,
        unique_name: "Cool Event Staff#Saera"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Saera]")
      |> mes("Welcome to the")
      |> mes("temporary headquarters")
      |> mes("of Cool Event Corporation.")
      |> mes("How may I help you today?")
      |> next()
      |> select(["Temporary headquarters?", "Voting", "No, thanks."])

    case choice do
      1 -> explain_headquarters(ctx)
      2 -> explain_voting(ctx)
      3 -> thank_visitor(ctx)
      _ -> ctx
    end
  end

  defp explain_headquarters(ctx) do
    ctx
    |> mes("[Saera]")
    |> mes("Our headquarters building")
    |> mes("is currently undergoing")
    |> mes("reconstruction, so we are")
    |> mes("basing our operations in")
    |> mes("this place for the meantime.")
    |> close()
  end

  defp explain_voting(ctx) do
    eligible? = get_char_var(ctx, :lhz_boss, 0) >= 17

    ctx =
      ctx
      |> mes("[Saera]")
      |> mes("Currently, Kafra Corporation")
      |> mes("and Cool Event Corp are working")
      |> mes("on a collaborative program that")
      |> mes("will provide direct teleport")
      |> mes("services to dungeons.")
      |> next()
      |> mes("[Saera]")
      |> mes("Due to technical issues,")
      |> mes("both companies cannot provide")
      |> mes("teleport services to the same")
      |> mes("dungeon. Therefore, we will be")

    if eligible? do
      ctx
      |> mes("selecting a number of valued customers to vote for their choice.")
      |> next()
      |> mes("[Saera]")
      |> mes("I've just reviewed your")
      |> mes("information and would like")
      |> mes("to inform you that you are")
      |> mes("indeed eligible to vote.")
      |> mes("Your participation in this")
      |> mes("election is much appreciated.")
      |> next()
      |> mes("[Saera]")
      |> mes("Remember that the")
      |> mes("election polls can be")
      |> mes("found in either Prontera")
      |> mes("or Juno. Thank you very much.")
      |> close()
    else
      ctx
      |> mes("selecting our valued customers to choose the company they want.")
      |> next()
      |> mes("[Saera]")
      |> mes("Only a limited number of")
      |> mes("voters will be chosen, so")
      |> mes("you can check your voting")
      |> mes("eligibility at the headquarters")
      |> mes("of both participating companies. Thank you for your patronage~")
      |> close()
    end
  end

  defp thank_visitor(ctx) do
    ctx
    |> mes("[Saera]")
    |> mes("Thank you.")
    |> mes("Have a good day.")
    |> close()
  end
end
