defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.HenryClifford do
  @moduledoc """
  Henry Clifford, the angler of the Cat Paw outpost who buys a Marlin for two Cat Trading
  Points.

  ## Behavior

  - While the player carries a Marlin, offers two Cat Trading Points for it through a Yes/No
    menu and, on acceptance, consumes the Marlin and adds the points to `ep13_yong1`.
  - Otherwise explains the rare fish of the river and asks to be brought a Marlin.

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
        x: 66,
        y: 122,
        dir: 55,
        sprite: 712,
        name: "Henry Clifford",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @marlin 6049
  @cat_trading_points 2

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if count_item(ctx, @marlin) > 0 do
      offer_trade(ctx)
    else
      fishing_talk(ctx)
    end
  end

  defp offer_trade(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Henry Clifford]")
      |> mes("Congratulations, you've caught a precious Marlin.")
      |> mes("I'll give you 2 Cat Trading Points in exchange for your Marlin.")
      |> next()
      |> mes("[Henry Clifford]")
      |> mes("I got them from a black marketer,")
      |> mes("but I guarantee the authenticity of these points.")
      |> mes("Are you interested?")
      |> next()
      |> select(["Yes.", "No, thanks."])

    case choice do
      1 -> trade(ctx)
      2 -> declined(ctx)
      _ -> ctx
    end
  end

  defp trade(ctx) do
    ctx
    |> delitem(@marlin, 1)
    |> set_char_var(:ep13_yong1, get_char_var(ctx, :ep13_yong1, 0) + @cat_trading_points)
    |> mes("[Henry Clifford]")
    |> mes("Thank you for the Marlin.")
    |> mes("I've given you the points in return.")
    |> mes("You may go check your points through the Cat Paw Agent.")
    |> close()
  end

  defp declined(ctx) do
    ctx
    |> mes("[Henry Clifford]")
    |> mes("Alright, if you say so.")
    |> mes("But feel free to come back if you change your mind.")
    |> close()
  end

  defp fishing_talk(ctx) do
    ctx
    |> mes("[Henry Clifford]")
    |> mes("You may have hear")
    |> mes("about this already, but")
    |> mes("this river is full of rare fish.")
    |> mes("I've followed these cats")
    |> mes("to see if the rumor is true.")
    |> next()
    |> mes("[Henry Clifford]")
    |> mes("Marlin, the legendary silver")
    |> mes("fish is the best prey of all.")
    |> mes("You can also catch precious")
    |> mes("treasure floating in the river.")
    |> next()
    |> mes("[Henry Clifford]")
    |> mes("If you happen to catch a Marlin,")
    |> mes("please trade it with me.")
    |> mes("I'll give you something")
    |> mes("nice in return.")
    |> close()
  end
end
