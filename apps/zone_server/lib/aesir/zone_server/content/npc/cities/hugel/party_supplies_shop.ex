defmodule Aesir.ZoneServer.Content.Npc.Cities.Hugel.PartySuppliesShop do
  @moduledoc """
  Sells party fireworks in bundles of five.

  ## Behavior

  - Charges 500 zeny for five fireworks when the buyer has enough money.

  ## Credits

  - Original from rAthena, authors and Contributors
    - vicious_pucca
    - Poki#3
    - erKURITA
    - Munin

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "hu_in01",
        x: 23,
        y: 311,
        dir: 4,
        sprite: 898,
        name: "Party Supplies Shop",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Shopkeeper]")
      |> mes("Welcome to the party supplies")
      |> mes("shop!")
      |> mes("Why don't you enjoy some")
      |> mes("spectacular fireworks with your")
      |> mes("friends?")
      |> mes("We can provide you with 5 of them")
      |> mes("at 500 zeny.")
      |> next()
      |> select(["Buy", "Cancel"])

    case choice do
      1 -> buy_fireworks(ctx)
      2 -> cancel_purchase(ctx)
      _ -> ctx
    end
  end

  defp buy_fireworks(ctx) do
    if zeny(ctx) < 500 do
      ctx
      |> mes("[Shopkeeper]")
      |> mes("I am sorry, but you don't have")
      |> mes("enough money~")
      |> close()
    else
      ctx
      |> pay_zeny(500)
      |> give_item(12018, 5)
      |> mes("[Shopkeeper]")
      |> mes("Here you go!")
      |> mes("Have fun with them!")
      |> close()
    end
  end

  defp cancel_purchase(ctx) do
    ctx
    |> mes("[Shopkeeper]")
    |> mes("Thank you, please come again.")
    |> close()
  end
end
