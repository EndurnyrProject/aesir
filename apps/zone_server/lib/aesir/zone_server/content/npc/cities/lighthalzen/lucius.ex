defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Lucius do
  @moduledoc """
  Collects zeny donations for poor relief.

  ## Behavior

  - Accepts donations from 1 to 30,000 zeny when the visitor carries less than 90,000 zeny.
  - Adds successful donations to a shared server-wide total.
  - Resets totals above 260,000 zeny and awards one item 603 and one item 12016.

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
        map: "lighthalzen",
        x: 182,
        y: 102,
        dir: 3,
        sprite: 866,
        name: "Lucius",
        scope: :shared,
        unique_name: "Lucius#zen5"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if zeny(ctx) < 90_000 do
      request_donation(ctx)
    else
      caution_wealthy_visitor(ctx)
    end
  end

  defp request_donation(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Lucius]")
      |> mes("Hello youngster~")
      |> mes("Would you like to")
      |> mes("make a donation")
      |> mes("to help the hungry?")
      |> next()
      |> select(["Sure.", "No, thanks."])

    if choice == 1 do
      accept_donation(ctx)
    else
      decline_donation(ctx)
    end
  end

  defp accept_donation(ctx) do
    {ctx, amount} =
      ctx
      |> mes("[Lucius]")
      |> mes("Now, you can donate 1 to")
      |> mes("30,000 zeny that will be used")
      |> mes("to support the poor and feed")
      |> mes("starving children. If you wish")
      |> mes("to cancel, please enter ''0.''")
      |> next()
      |> input(:int)

    cond do
      amount > 30_000 or amount < 0 -> invalid_donation(ctx)
      amount == 0 -> cancel_donation(ctx)
      true -> confirm_donation(ctx, amount)
    end
  end

  defp confirm_donation(ctx, amount) do
    ctx =
      ctx
      |> mes("[Lucius]")
      |> mes("Thank you so much")
      |> mes("for your #{amount} zeny donation.")
      |> mes("I promise that your money")
      |> mes("will be put to good use in")
      |> mes("benefiting the poor and needy.")
      |> next()

    if zeny(ctx) < amount do
      ctx
      |> mes("[Lucius]")
      |> mes("Still, I'm just a little")
      |> mes("disappointed. An adventurer")
      |> mes("like you should be donating")
      |> mes("as much as you possibly can...")
      |> close()
    else
      record_donation(ctx, amount)
    end
  end

  defp record_donation(ctx, amount) do
    ctx =
      ctx
      |> pay_zeny(amount)
      |> set_server_var("donatedzeny", get_server_var(ctx, "donatedzeny", 0) + amount)
      |> mes("[Lucius]")
      |> mes("So far, I've received")

    donated_total = get_server_var(ctx, "donatedzeny", 0)

    ctx =
      ctx
      |> mes("a total of #{donated_total} zeny in")
      |> mes("donations. I'm glad to see")
      |> mes("that there are still kind and")
      |> mes("generous people in the world.")

    ctx =
      if get_server_var(ctx, "donatedzeny", 0) > 260_000 do
        ctx
        |> next()
        |> mes("[Lucius]")
        |> mes("This should be enough")
        |> mes("to send to the Poor Relief")
        |> mes("Organization. Please accept")
        |> mes("this small gift as a token of")
        |> mes("my gratitude, adventurer. Bless")
        |> mes("you, youngster and take care.")
        |> set_server_var("donatedzeny", 0)
        |> give_item(603, 1)
        |> give_item(12_016, 1)
      else
        ctx
      end

    close(ctx)
  end

  defp invalid_donation(ctx) do
    ctx
    |> mes("[Lucius]")
    |> mes("Please enter a value")
    |> mes("from 1 to 30,000 in")
    |> mes("order to make a donation")
    |> mes("to the needy, youngster.")
    |> close()
  end

  defp cancel_donation(ctx) do
    ctx
    |> mes("[Lucius]")
    |> mes("How disappointing,")
    |> mes("but I'm sure you have")
    |> mes("your reasons. Well, when")
    |> mes("you can afford to give to")
    |> mes("the needy, you're welcome")
    |> mes("to come back at any time.")
    |> close()
  end

  defp decline_donation(ctx) do
    ctx
    |> mes("[Lucius]")
    |> mes("I understand. Still,")
    |> mes("keep in mind that when")
    |> mes("you give from your heart,")
    |> mes("you will be rewarded tenfold.")
    |> mes("Though I admit, the benefits")
    |> mes("aren't always readily apparent.")
    |> close()
  end

  defp caution_wealthy_visitor(ctx) do
    ctx
    |> mes("[Lucius]")
    |> mes("Hello youngster~")
    |> mes("You seem to be fairly")
    |> mes("well-off. Money is good")
    |> mes("to have, but be careful not")
    |> mes("to become obsessed with it.")
    |> next()
    |> mes("[Lucius]")
    |> mes("When you have the chance,")
    |> mes("please show your generosity")
    |> mes("towards others who may be")
    |> mes("much less fortunate than you.")
    |> close()
  end
end
