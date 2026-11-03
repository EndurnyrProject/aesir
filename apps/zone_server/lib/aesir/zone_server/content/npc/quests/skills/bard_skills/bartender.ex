defmodule Aesir.ZoneServer.Content.Npc.Quests.Skills.BardSkills.Bartender do
  @moduledoc """
  The Morocc pub bartender who sells the drinks used in the Bard Pang Voice skill quest.

  ## Behavior

  - Sells a Tropical Sograt or a Vermilion on the Beach for 1,000 zeny each.
  - Refuses to serve players without inventory space, weight capacity, or enough zeny.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Lupus
    - Reddozen
    - L0ne_W0lf
    - DracoRPG

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
    quests/skills/bard_skills.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "morocc_in",
        x: 166,
        y: 76,
        dir: 7,
        sprite: 46,
        name: "Bartender",
        scope: :shared,
        unique_name: "Bartender#bard_qskill"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @tropical_sograt 12112
  @vermilion_on_the_beach 12113
  @price 1000

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if checkweight(ctx, [{1201, 1}]) == 0 do
      ctx
      |> mes("^3355FFHold it right there!")
      |> mes(
        "You're carrying too many items and don't have enough inventory space to receive any rewards. Please make more inventory space available and come back to take this challenge."
      )
      |> close()
    else
      take_order(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp take_order(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Bartender]")
      |> mes("So what would")
      |> mes("you like to order?")
      |> next()
      |> select(["Tropical Sograt", "Vermilion on the Beach", "Nothing, thanks."])

    case choice do
      1 -> order(ctx, @tropical_sograt)
      2 -> order(ctx, @vermilion_on_the_beach)
      3 -> farewell(ctx)
      _ -> ctx
    end
  end

  defp farewell(ctx) do
    ctx |> mes("[Bartender]") |> mes("Alright, then.") |> mes("I'll see you around.") |> close()
  end

  defp order(ctx, drink) do
    cond do
      get_char_var(ctx, :MaxWeight, 0) - weight(ctx) < 2000 ->
        too_heavy(ctx)

      zeny(ctx) < @price ->
        cannot_afford(ctx, drink)

      true ->
        ctx
        |> serve(drink)
        |> pay_zeny(@price)
        |> give_item(drink, 1)
        |> close()
    end
  end

  defp too_heavy(ctx) do
    ctx
    |> mes("[Bartender]")
    |> mes("You sure you can carry")
    |> mes("any more stuff with you?")
    |> mes("Damn, it doesn't look that")
    |> mes("way to me. Take a load off,")
    |> mes("and put some stuff with in")
    |> mes("your Kafra Storage, alright?")
    |> close()
  end

  defp cannot_afford(ctx, drink) do
    opening =
      if drink == @tropical_sograt,
        do: " You sure you can afford",
        else: "You sure you can afford"

    ctx
    |> mes("[Bartender]")
    |> mes(opening)
    |> mes("this now? This drink's")
    |> mes("1,000 zeny, so you better")
    |> mes("check the cash you have")
    |> mes("onhand. Eh, just come back")
    |> mes("later when you have the money.")
    |> close()
  end

  defp serve(ctx, @tropical_sograt) do
    ctx
    |> mes("[Bartender]")
    |> mes("Here you are,")
    |> mes("1 Tropical Sograt.")
    |> mes("It tastes sweet and")
    |> mes("mild, but if you're not")
    |> mes("careful, you'll pass out")
    |> mes("in no time flat. Take it easy.")
  end

  defp serve(ctx, @vermilion_on_the_beach) do
    ctx
    |> mes("[Bartender]")
    |> mes("Here you go.")
    |> mes("Be sure that you")
    |> mes("enjoy your drinking")
    |> mes("without going crazy.")
  end
end
