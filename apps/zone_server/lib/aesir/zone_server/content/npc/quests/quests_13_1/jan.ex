defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.Jan do
  @moduledoc """
  Jan, the young researcher in the camp's main building who awaits a month-old order.

  ## Behavior

  - On step 15, while the player carries the delivery, takes the parcel, sets `ep13_newbs` to
    16, hands over a Chocolate Pie and advances quest 11093 to 11094; without the parcel it
    only asks where the order is.
  - On step 16 keeps the parcel's contents a secret.
  - Below step 15 talks about the strange things he keeps finding.

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
        x: 160,
        y: 298,
        dir: 4,
        sprite: 865,
        name: "Jan",
        scope: :shared,
        unique_name: "Jan#ep13bs"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @delivery 6045
  @gift 12322

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    case get_char_var(ctx, :ep13_newbs, 0) do
      15 -> deliver(ctx)
      16 -> secret(ctx)
      _step -> research_talk(ctx)
    end
  end

  defp deliver(ctx) do
    if count_item(ctx, @delivery) > 0 do
      takes_parcel(ctx)
    else
      awaiting_parcel(ctx)
    end
  end

  defp takes_parcel(ctx) do
    ctx =
      ctx
      |> mes("[Jan]")
      |> mes("Wawa, what is this~")
      |> mes("Hey, is that for me?")
      |> next()
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Yes...")

    ctx
    |> emotion(:sweat, playerattached(ctx))
    |> next()
    |> mes("[Jan]")
    |> mes("Ahhh, it's exciting~")
    |> mes("I love it.")
    |> emotion(:cool)
    |> next()
    |> mes("[Jan]")
    |> mes("I want to unwrap it right now~")
    |> mes("Please tell the Instructor")
    |> mes("I'm grateful~")
    |> mes("Uhuhu.")
    |> delitem(@delivery, 1)
    |> set_char_var(:ep13_newbs, 16)
    |> give_item(@gift, 1)
    |> changequest(11093, 11094)
    |> close()
  end

  defp awaiting_parcel(ctx) do
    ctx
    |> mes("[Jan]")
    |> mes("Why hasn't the product")
    |> mes("that I ordered one month")
    |> mes("ago come yet?")
    |> emotion(:fret)
    |> close()
  end

  defp secret(ctx) do
    ctx =
      ctx
      |> mes("[Jan]")
      |> mes("I really wanted it.")
      |> mes("I really love it~~")
      |> next()
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("What is... it~~?")
      |> next()
      |> mes("[Jan]")
      |> mes("......")
      |> mes("......")
      |> next()

    ctx
    |> mes("[Jan]")
    |> mes("It, it's a secret...")
    |> emotion(:shy)
    |> close()
  end

  defp research_talk(ctx) do
    ctx
    |> mes("[Jan]")
    |> mes("The more I study around here,")
    |> mes("the more I find strange things.")
    |> next()
    |> mes("[Jan]")
    |> mes("It seems to stimulate my")
    |> mes("passion as a scientist?")
    |> close()
  end
end
