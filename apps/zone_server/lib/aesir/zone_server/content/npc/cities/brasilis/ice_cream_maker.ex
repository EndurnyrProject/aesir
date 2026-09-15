defmodule Aesir.ZoneServer.Content.Npc.Cities.Brasilis.IceCreamMaker do
  @moduledoc """
  Sells ice cream to visitors in Brasilis.

  ## Behavior

  - Sells between one and five Ice Creams for 100 zeny each.
  - Rejects purchases when funds or carrying capacity are insufficient.
  - Explains ice cream or ends the conversation on request.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "brasilis",
        x: 137,
        y: 77,
        dir: 5,
        sprite: 85,
        name: "Ice-Cream Maker",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Ice Cream Maker]")
      |> mes("Come~come~")
      |> mes("Ice cream is the perfect snack for a hot day~")
      |> mes("It's just ^3355FF100 Zeny^000000~")
      |> mes("Ice Cream~")
      |> mes("Get 'yer Ice Cream!")
      |> next()
      |> select(["Give me one!", "Ice Cream?", "Cancel."])

    case choice do
      1 -> start_purchase(ctx)
      2 -> explain_ice_cream(ctx)
      3 -> cancel_purchase(ctx)
      _ -> ctx
    end
  end

  defp start_purchase(ctx) do
    ctx =
      ctx
      |> mes("[Ice Cream Maker]")
      |> mes(
        "Since there are so many people want to get a cool ice cream you can order only 5 at a time."
      )
      |> mes("So how many d'ya want?")
      |> next()

    case ask_amount(ctx) do
      {:cancel, ctx} -> ctx
      {:ok, ctx, amount} -> complete_purchase(ctx, amount)
    end
  end

  defp ask_amount(ctx) do
    {ctx, amount} = input(ctx, :int)

    cond do
      amount == 0 ->
        ctx =
          ctx
          |> mes("[Ice Cream Maker]")
          |> mes("None?")
          |> mes("Fine get outta the way, I have customers to serve.")
          |> close()

        {:cancel, ctx}

      amount < 0 or amount > 5 ->
        ctx =
          ctx
          |> mes("[Ice Cream Maker]")
          |> mes("Wow.")
          |> mes("You ordered too much.")
          |> mes(
            "If you eat over 5 you might need to fight with a monster in your stomach. Calm down buddy."
          )
          |> next()

        ask_amount(ctx)

      true ->
        {:ok, ctx, amount}
    end
  end

  defp complete_purchase(ctx, amount) do
    price = amount * 100

    cond do
      zeny(ctx) < price ->
        ctx
        |> mes("[Ice Cream Maker]")
        |> mes("Dood~! You don't have enough money.")
        |> mes("It's only ^3355FF100 Zeny^000000~ Seriously!")
        |> close()

      not Rathena.truthy?(checkweight(ctx, [{536, amount}])) ->
        ctx
        |> mes("[Ice Cream Maker]")
        |> mes("You seem to have too much stuff.")
        |> mes("Lighten your pack before buying this.")
        |> close()

      true ->
        ctx
        |> pay_zeny(price)
        |> give_item(536, amount)
        |> close()
    end
  end

  defp explain_ice_cream(ctx) do
    ctx
    |> mes("[Ice Cream Maker]")
    |> mes("'Ice cream is...")
    |> mes("Wait, don't you know")
    |> mes("what Ice Cream is?")
    |> mes("What rock have you")
    |> mes("been living under?")
    |> next()
    |> mes("[Ice Cream Maker]")
    |> mes("I'm not going to even start with how weird that sounds.")
    |> mes("Anyway, get 'yer Ice Cream right here while it's nice and cold.")
    |> close()
  end

  defp cancel_purchase(ctx) do
    ctx
    |> mes("[Ice Cream Maker]")
    |> mes("Don't miss your chance to eat the greatest Ice Cream in all the land~!")
    |> close()
  end
end
