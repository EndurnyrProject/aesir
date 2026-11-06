defmodule Aesir.ZoneServer.Content.Npc.Floating.PrOfficerMoscovia do
  @moduledoc """
  Moscovia P.R. Officer who advertises the kingdom and sails players there.

  ## Behavior

  - Describes Moscovia's landscapes and palace, or offers the crossing.
  - The crossing costs 10,000 zeny one way; the fare is charged before the ship
    leaves and the player lands in Moscovia.
  - Cancelling either menu ends the conversation with the offer to come back
    later, except on the boarding menu, which falls through to the fare check.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script cities/moscovia.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "alberta",
        x: 246,
        y: 51,
        dir: 4,
        sprite: 960,
        name: "Moscovia P.R. Officer",
        scope: :renewal,
        unique_name: "Moscovia P.R. Officer#1"
      },
      %{
        map: "alberta",
        x: 245,
        y: 66,
        dir: 4,
        sprite: 960,
        name: "Moscovia P.R. Officer",
        scope: :pre_renewal,
        unique_name: "Moscovia P.R. Officer#1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @fare 10_000

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Moscovia P.R. Officer]")
      |> mes("Moscovia! Do you know Moscovia?")
      |> mes("the paradise spreading on the endless seas...")
      |> mes("Welcome to Moscovia")
      |> mes("It's adventurous and mystic.")
      |> next()
      |> select(["About Moscovia...", "Go to Moscovia.", "Cancel"])

    case choice do
      1 -> describe_moscovia(ctx)
      2 -> offer_the_crossing(ctx)
      3 -> come_back_later(ctx)
      _ -> ctx
    end
  end

  defp describe_moscovia(ctx) do
    ctx
    |> mes("[Moscovia P.R. Officer]")
    |> mes("Moscovia is a beautiful kingdom")
    |> mes("on an island located north of Rune-")
    |> mes("Midgarts.")
    |> next()
    |> mes("[Moscovia P.R. Officer]")
    |> mes("I'm sure that you will be")
    |> mes("absolutely fascinated")
    |> mes("by Moscovia's beautiful scenery")
    |> mes("and gorgeous palace.")
    |> next()
    |> mes("[Moscovia P.R. Officer]")
    |> mes("Now that our long winter has")
    |> mes("passed,")
    |> mes("I'm happy that I can now show you")
    |> mes("our gorgeous hometown.")
    |> next()
    |> mes("[Moscovia P.R. Officer]")
    |> mes("If you feel like visiting Moscovia")
    |> mes("take the chance now!")
    |> mes("I'll help you to have a nice trip")
    |> mes("to Moscovia!")
    |> close()
  end

  defp offer_the_crossing(ctx) do
    {ctx, answer} =
      ctx
      |> mes("[Moscovia P.R. Officer]")
      |> mes("Ok then, let us start now.")
      |> mes("You should pay me 10,000 zeny")
      |> mes("to go to Moscovia.")
      |> mes("But when you come back,")
      |> mes("you don't have to pay.")
      |> next()
      |> mes("[Moscovia P.R. Officer]")
      |> mes("Can we leave now?")
      |> next()
      |> select(["Let's go!", "Cancel"])

    if answer == 2 do
      come_back_later(ctx)
    else
      sail(ctx)
    end
  end

  defp sail(ctx) do
    if zeny(ctx) < @fare do
      ctx
      |> mes("[Moscovia P.R. Officer]")
      |> mes("I'm sorry but you don't have")
      |> mes("enough zeny now")
      |> mes("You need 10,000 zeny")
      |> mes("to go to Moscovia")
      |> mes("Thank you.")
      |> close()
    else
      ctx
      |> mes("[Moscovia P.R. Officer]")
      |> mes("Ok then, we're leaving now.")
      |> close()
      |> pay_zeny(@fare)
      |> warp("moscovia", 163, 55)
    end
  end

  defp come_back_later(ctx) do
    ctx
    |> mes("[Moscovia P.R. Officer]")
    |> mes("If you're too busy now,")
    |> mes("please tell me again whenever you want.")
    |> mes("I'm always ready to guide anyone to Moscovia.")
    |> close()
  end
end
