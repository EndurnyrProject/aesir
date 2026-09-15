defmodule Aesir.ZoneServer.Content.Npc.Cities.Jawaii.HoneymoonHelper do
  @moduledoc """
  Sells the Sweet Memory of Marriage keepsake in Jawaii.

  ## Behavior

  - Charges 50,000 zeny and gives item 681 when the buyer has enough funds.

  ## Credits

  - Original from rAthena, authors and Contributors
    - jAthena
    - DNett123
    - L0ne_w0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "jawaii",
        x: 214,
        y: 168,
        dir: 5,
        sprite: 71,
        name: "Honeymoon Helper",
        scope: :shared,
        unique_name: "Honeymoon Helper#Jawaii"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Helper]")
      |> mes("There is no place")
      |> mes("better for having your")
      |> mes("honeymoon than Jawaii.")
      |> next()
      |> mes("[Helper]")
      |> mes(
        "Why don't you make the best of your time here, and make a lot of sweet memories that you will cherish for years to come?"
      )
      |> next()
      |> mes("[Helper]")
      |> mes(
        "Mementos that remind you of your happy times can be your most precious possessions. Like your wedding ring, for instance, or the tuxedo and wedding dress worn during your wedding ceremony..."
      )
      |> next()
      |> mes("[Helper]")
      |> mes("Even if the wedding ceremony")
      |> mes(
        "is over, isn't it nice to look back upon the happy memories of your marriage ceremony? With the magical photo album at a cheap price, now you can!"
      )
      |> next()
      |> mes("[Helper]")
      |> mes("Its name is...")
      |> mes("'Sweet Memory of Marriage'!!")
      |> next()
      |> mes("[Helper]")
      |> mes("It will instantly bring you to the wedding hall with magic power!")
      |> mes("And it only costs 50,000 zeny...")
      |> next()
      |> select(["I shall buy it.", "No, thanks."])

    case choice do
      1 -> sell_memory(ctx)
      _ -> decline_purchase(ctx)
    end
  end

  defp sell_memory(ctx) do
    ctx = mes(ctx, "[Helper]")

    if zeny(ctx) > 49_999 do
      ctx
      |> pay_zeny(50_000)
      |> give_item(681, 1)
      |> mes("Thank you very much~!")
      |> mes("Please remember, you")
      |> mes("should use this with your")
      |> mes("partner in a place that is")
      |> mes("special to the both of you.")
      |> close()
    else
      ctx
      |> mes(
        "'Sweet Memory of Marriage' is 50,000 zeny. But don't seem to have enough money with you right now. Maybe you and your partner could help each other to buy the Sweet Memory of Marriage?"
      )
      |> close()
    end
  end

  defp decline_purchase(ctx) do
    ctx
    |> mes("[Helper]")
    |> mes("Even if your relationship ends,")
    |> mes("the memories the both of you have shared will remain forever...")
    |> close()
  end
end
