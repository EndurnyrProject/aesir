defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.CatPawMiningAgent do
  @moduledoc """
  The Cat Paw mining agent at the outpost, who trades three unidentified minerals for
  expedition experience and a Cat Trading Point.

  ## Behavior

  - While the mining quest's playtime is unset, takes three Unidentified Minerals and the
    player's tenth Cat Trading Point as the price of a delivery, granting the mode's
    experience, starting quest 12062 and adding a Cat Trading Point behind a one-option menu.
  - With the playtime running, asks the player to come back the next day.
  - After the playtime lapses, clears the quest and offers the work again.

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
        x: 88,
        y: 100,
        dir: 55,
        sprite: 876,
        name: "Cat Paw Mining Agent",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @mining_quest 12062
  @unidentified_mineral 6048
  @minerals_per_delivery 3

  @renewal_exp 20_000
  @pre_renewal_exp 30_000

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    case checkquest(ctx, @mining_quest, :playtime) do
      -1 -> offer_delivery(ctx)
      0 -> wait_for_tomorrow(ctx)
      1 -> wait_for_tomorrow(ctx)
      _past -> reopen_offer(ctx)
    end
  end

  defp offer_delivery(ctx) do
    if count_item(ctx, @unidentified_mineral) >= @minerals_per_delivery and
         get_char_var(ctx, :ep13_yong1, 0) > 9 do
      take_minerals(ctx)
    else
      cold_weather(ctx)
    end
  end

  defp take_minerals(ctx) do
    exp = if Rathena.truthy?(checkre(ctx, 3)), do: @renewal_exp, else: @pre_renewal_exp

    ctx =
      ctx
      |> mes("[Cat Paw Mining Agent]")
      |> mes("Oh, wow~")
      |> mes("Thank you for collecting minerals for me.")
      |> next()
      |> delitem(@unidentified_mineral, @minerals_per_delivery)
      |> getexp(exp, 0)
      |> setquest(@mining_quest)
      |> set_char_var(:ep13_yong1, get_char_var(ctx, :ep13_yong1, 0) + 1)

    {ctx, _} = ctx |> select(["I'm freezing! Take them quickly."])

    ctx
    |> mes("[Cat Paw Mining Agent]")
    |> mes("Yes, yes~ I've received the mineral samples.")
    |> mes("I'll go ahead and add points to your credit.")
    |> close()
  end

  defp cold_weather(ctx) do
    ctx
    |> mes("[Cat Paw Mining Agent]")
    |> mes("To collect minerals,")
    |> mes("we have to go to the")
    |> mes("frozen land to the east.")
    |> mes("But for short-haired cats")
    |> mes("like me, the weather")
    |> mes("is unbearable.")
    |> next()
    |> mes("[Cat Paw Mining Agent]")
    |> mes("If the weather")
    |> mes("is good tomorrow,")
    |> mes("I might try to go,")
    |> mes("but not today.")
    |> mes("It looks freezing to")
    |> mes("you too, doesn't it?")
    |> close()
  end

  defp wait_for_tomorrow(ctx) do
    ctx
    |> mes("[Cat Paw Mining Agent]")
    |> mes("I hope you'll bring me minerals again tomorrow...")
    |> mes("If you can. It's much better to wait for you to do it than go there on my own.")
    |> close()
  end

  defp reopen_offer(ctx) do
    ctx
    |> erasequest(@mining_quest)
    |> mes("[Cat Paw Mining Agent]")
    |> mes("Umm... It's time to collect minerals.")
    |> mes("How'd you like to collect minerals for me?")
    |> close()
  end
end
