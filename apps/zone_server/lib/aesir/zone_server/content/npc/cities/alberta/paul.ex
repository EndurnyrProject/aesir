defmodule Aesir.ZoneServer.Content.Npc.Cities.Alberta.Paul do
  @moduledoc """
  Recruits adventurers for the Sunken Ship exploration team.

  ## Behavior

  - Warns travelers about the expedition's danger.
  - Charges 200 zeny before warping recruits to the Sunken Ship area.

  ## Credits

  - Original from rAthena, authors and Contributors
    - DZeroX

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [%{map: "alberta", x: 195, y: 151, dir: 2, sprite: 86, name: "Paul", scope: :shared}]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Paul]")
      |> mes("Good day~")
      |> mes("Would you like")
      |> mes("to join the")
      |> mes("exploration team")
      |> mes("of the Sunken Ship?")
      |> next()
      |> mes("[Paul]")
      |> mes(
        "Oh! Before you join, I must warn you. If you're not that strong, you may not want to go."
      )
      |> next()
      |> mes("[Paul]")
      |> mes("So, want")
      |> mes("to sign up?")
      |> mes("The admission")
      |> mes("fee is only")
      |> mes("200 Zeny.")
      |> next()
      |> select(["Sign me up!", "Uh, no thanks."])

    case choice do
      1 -> join_expedition(ctx)
      2 -> decline_expedition(ctx)
      _ -> ctx
    end
  end

  defp join_expedition(ctx) do
    if zeny(ctx) < 200 do
      ctx
      |> mes("[Paul]")
      |> mes(
        "It seems you don't have the money, my friend. But please come back when you're able to pay."
      )
      |> close()
    else
      ctx
      |> pay_zeny(200)
      |> warp("alb2trea", 62, 69)
      |> close()
    end
  end

  defp decline_expedition(ctx) do
    ctx
    |> mes("[Paul]")
    |> mes("Alright, well...")
    |> mes("I'll be around")
    |> mes("if you change")
    |> mes("your mind.")
    |> close()
  end
end
