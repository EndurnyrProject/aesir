defmodule Aesir.ZoneServer.Content.Npc.Cities.Jawaii.Employee112173 do
  @moduledoc """
  Offers access to Jawaii's Villa Room.

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
        x: 112,
        y: 173,
        dir: 7,
        sprite: 93,
        name: "Employee",
        scope: :shared,
        unique_name: "Employee#villroom"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Larks Rania]")
      |> mes("Hello dear,")
      |> mes("how are you?")
      |> mes("Are you looking for")
      |> mes("a room to stay in?")
      |> next()
      |> mes("[Larks Rania]")
      |> mes("This is called the Villa Room.")
      |> mes("I recommend this room to people")
      |> mes("who prefer to stay in a place with")
      |> mes("a comfortable atmosphere")
      |> mes("much like home.")
      |> next()
      |> mes("[Larks Rania]")
      |> mes("Just like all the other rooms,")
      |> mes("the lodging charge is 1,000 zeny.")
      |> mes("I can guide you to the Villa Room")
      |> mes("right now, if you wish. Would you")
      |> mes("like to stay?")
      |> next()
      |> select(["Use.", "Cancel."])

    case choice do
      1 -> open_villa_room(ctx)
      _ -> decline_villa_room(ctx)
    end
  end

  defp open_villa_room(ctx) do
    ctx = mes(ctx, "[Larks Rania]")

    if zeny(ctx) > 999 do
      ctx
      |> mes("Thank you~")
      |> mes("Enjoy your stay.")
      |> close()
      |> pay_zeny(1000)
      |> warp("jawaii_in", 87, 75)
    else
      ctx
      |> mes("Oh what a shame!")
      |> mes("You don't seem")
      |> mes("to have enough money...?")
      |> mes("Why don't you ask your")
      |> mes("partner to help you")
      |> mes("with the charge?")
      |> close()
    end
  end

  defp decline_villa_room(ctx) do
    ctx
    |> mes("[Larks Rania]")
    |> mes("No problem~")
    |> mes(
      "If you like, you may wish to check the Honey Room. Although the roomkeeper, Sharkie, is a shy girl, the room is really beautiful."
    )
    |> close()
  end
end
