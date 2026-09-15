defmodule Aesir.ZoneServer.Content.Npc.Cities.Jawaii.Employee do
  @moduledoc """
  Offers access to Jawaii's Sweet Room.

  ## Behavior

  - Charges 1,000 zeny before transferring a guest to the room.

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
        x: 141,
        y: 200,
        dir: 3,
        sprite: 798,
        name: "Employee",
        scope: :shared,
        unique_name: "Employee#sroom"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Alowa]")
      |> mes("W-Welcome...?")
      |> mes("This is o-o-our")
      |> mes("s-sweet room.")
      |> mes("We, we just c-cleaned")
      |> mes("this r-room for you")
      |> mes("o-of course.")
      |> next()
      |> mes("[Alowa]")
      |> mes("Th-The charge is is")
      |> mes("1000 zeny p-p-per person?")
      |> mes("P-please pay me the fee and")
      |> mes("I,I'll let you in. I ssss...swear!")
      |> next()
      |> mes("[Alowa]")
      |> mes(
        "I, I'll also ca-carry your luggage. B-but pay me first. Otherwise, my bo-boss will be unhappy and... ^666666*Gulp*^000000"
      )
      |> next()
      |> mes("[Alowa]")
      |> mes("^333333Beat me to death...^000000")
      |> next()
      |> select(["Use.", "Cancel."])

    case choice do
      1 -> open_sweet_room(ctx)
      _ -> decline_sweet_room(ctx)
    end
  end

  defp open_sweet_room(ctx) do
    ctx = mes(ctx, "[Alowa]")

    if zeny(ctx) > 999 do
      ctx
      |> mes("T-Thank you ssso much!")
      |> mes("L-Let open the room door")
      |> mes("ffffor you. Thank y-you.")
      |> mes("Ha-have a good time.")
      |> close()
      |> pay_zeny(1000)
      |> warp("jawaii_in", 116, 64)
    else
      ctx
      |> mes("Oh no! Oh no no no no no.")
      |> mes("Th-This isn't enough money?")
      |> mes("I-I'm ssssorry, but my b-boss w-will beat me if I l-let you")
      |> mes("in without paying...")
      |> close()
    end
  end

  defp decline_sweet_room(ctx) do
    ctx
    |> mes("[Alowa]")
    |> mes("^666666*Sniff*^000000")
    |> mes(
      "B-but I promise th-that this room is the nicest and cl-cleanest room! P-Please! C-come back!"
    )
    |> emotion(:cry)
    |> close()
  end
end
