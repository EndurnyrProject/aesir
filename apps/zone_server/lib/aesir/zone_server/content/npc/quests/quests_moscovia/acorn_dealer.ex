defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.AcornDealer do
  @moduledoc """
  The acorn dealer sells acorns to visitors.

  ## Behavior

  - Sells up to 500 acorns at 100 zeny each.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Kisuka
    - brianluau
    - Gepard
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Lemongrass
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "moscovia",
        x: 208,
        y: 182,
        dir: 7,
        sprite: 967,
        name: "Acorn Dealer",
        scope: :shared,
        unique_name: "Acorn Dealer#mos"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Acorn Dealer]")
      |> mes("We have very fresh acorns. Everyone will like them!")
      |> mes("You can buy one acorn for 100zeny!")
      |> next()
      |> select(["Buy one.", "What can I use them for?"])

    if choice == 2 do
      ctx
      |> mes("[Acorn Dealer]")
      |> mes("Well uh...")
      |> mes("You can grind them to make")
      |> mes("something to eat and you can feed squirrels.")
      |> next()
      |> mes("[Acorn Dealer]")
      |> mes("Someone can decorate their house")
      |> mes("with them but I don't know how...")
      |> mes("they've got to be highly talented.")
      |> mes("Haha.")
      |> close()
    else
      ctx
      |> mes("[Acorn Dealer]")
      |> mes("I'll bet you that they are very fresh!")
      |> mes("How many acorns do you need?")
      |> next()
      |> request_quantity()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp request_quantity(ctx) do
    {ctx, quantity} = input(ctx, :int)
    ctx = set_local(ctx, :input, quantity)

    cond do
      quantity <= 0 ->
        ctx |> mes("[Acorn Dealer]") |> mes("Do you want to cancel this trade?") |> close()

      quantity > 500 ->
        ctx
        |> mes("[Acorn Dealer]")
        |> mes("You can't buy more than 500.")
        |> next()
        |> request_quantity()

      true ->
        purchase(ctx, quantity)
    end
  end

  defp purchase(ctx, quantity) do
    cond do
      not Rathena.truthy?(checkweight(ctx, [{1026, quantity}])) ->
        ctx
        |> mes("[Acorn Dealer]")
        |> mes("Hello, I think you can't get acorns")
        |> mes("now. You're carrying too many")
        |> mes("items!")
        |> mes("Please use Kafra service. I'll be")
        |> mes("right here.")
        |> close()

      true ->
        ctx = set_local(ctx, :price, quantity * 100)

        if zeny(ctx) < quantity * 100 do
          ctx
          |> mes("[Acorn Dealer]")
          |> mes("Hello? You've turned pale! Are you ok??")
          |> mes("Do you have enough money?")
          |> close()
        else
          ctx
          |> mes("[Acorn Dealer]")
          |> mes("Oh, thank you...")
          |> mes("What do you think of them? They're fresh, aren't they?")
          |> pay_zeny(quantity * 100)
          |> give_item(1026, quantity)
          |> close()
        end
    end
  end
end
