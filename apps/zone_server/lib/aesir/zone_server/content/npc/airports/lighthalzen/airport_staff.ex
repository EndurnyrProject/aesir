defmodule Aesir.ZoneServer.Content.Npc.Airports.Lighthalzen.AirportStaff do
  @moduledoc """
  Sells entry to the Lighthalzen Airport boarding area.

  ## Behavior

  - Accepts a Free Ticket for Airship or charges the 1,200 zeny boarding fee.
  - Refuses boarding when the passenger has neither a ticket nor enough zeny.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Muad_Dib

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lhz_airport",
        x: 143,
        y: 43,
        dir: 5,
        sprite: 90,
        name: "Airport Staff",
        scope: :shared,
        unique_name: "lhz_airport1"
      },
      %{
        map: "lhz_airport",
        x: 158,
        y: 43,
        dir: 5,
        sprite: 90,
        name: "Airship Staff",
        scope: :shared,
        unique_name: "Airship Staff#lhz_air1b"
      },
      %{
        map: "lhz_airport",
        x: 126,
        y: 43,
        dir: 5,
        sprite: 90,
        name: "Airship Staff",
        scope: :shared,
        unique_name: "Airship Staff#lhz_air1c"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Airport Staff]")
      |> mes("Welcome to the")
      |> mes("Lighthalzen Airport,")
      |> mes("where we offer nonstop")
      |> mes("flights to Einbroch, Juno and Hugel.")
      |> next()
      |> select(["Board the Airship.", "Cancel."])

    if choice == 1, do: offer_boarding(ctx), else: farewell(ctx)
  end

  defp offer_boarding(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Airport Staff]")
      |> mes("The boarding fee is")
      |> mes("1,200 zeny, but you can")
      |> mes("waive the fee if you redeem")
      |> mes("a Free Ticket for Airship.")
      |> next()
      |> select(["Yes", "No"])

    if choice == 1, do: board(ctx), else: farewell(ctx)
  end

  defp board(ctx) do
    cond do
      count_item(ctx, 7311) > 0 ->
        ctx |> delitem(7311, 1) |> warp("lhz_airport", 148, 51)

      zeny(ctx) >= 1200 ->
        ctx |> pay_zeny(1200) |> warp("lhz_airport", 148, 51)

      true ->
        ctx
        |> mes("[Airship Staff]")
        |> mes("I'm sorry, but you don't")
        |> mes("have 1,200 zeny to pay")
        |> mes("for the boarding fee.")
        |> close()
    end
  end

  defp farewell(ctx) do
    ctx
    |> mes("[Airport Staff]")
    |> mes("Thank you and")
    |> mes("please come again.")
    |> mes("Have a good day~")
    |> close()
  end
end
