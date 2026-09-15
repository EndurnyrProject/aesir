defmodule Aesir.ZoneServer.Content.Npc.Airports.Yuno.AirportStaff do
  @moduledoc """
  Sells entry to the Juno Airport boarding area.

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
        map: "y_airport",
        x: 143,
        y: 43,
        dir: 5,
        sprite: 90,
        name: "Airport Staff",
        scope: :shared,
        unique_name: "y_airport1"
      },
      %{
        map: "y_airport",
        x: 158,
        y: 43,
        dir: 5,
        sprite: 90,
        name: "Airport Staff",
        scope: :shared,
        unique_name: "Airport Staff#y_air1b"
      },
      %{
        map: "y_airport",
        x: 126,
        y: 43,
        dir: 5,
        sprite: 90,
        name: "Airport Staff",
        scope: :shared,
        unique_name: "Airport Staff#y_air1c"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Airport Staff]")
      |> mes(
        "Welcome to Juno Airport where we offer domestic flights to Einbroch, Lighthalzen and Hugel,"
      )
      |> mes("and international flights to Izlude and Rachel.")
      |> mes("How may I be of service?")
      |> next()
      |> select(["Board the Airship.", "Cancel."])

    if choice == 1, do: offer_boarding(ctx), else: farewell(ctx)
  end

  defp offer_boarding(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Airport Staff]")
      |> mes("The boarding fee for all")
      |> mes("flights is 1,200 zeny. If you")
      |> mes("use a Free Ticket for Airship,")
      |> mes("the boarding fee will be waived.So would you like to depart?")
      |> next()
      |> select(["Yes", "No"])

    if choice == 1, do: board(ctx), else: farewell(ctx)
  end

  defp board(ctx) do
    cond do
      count_item(ctx, 7311) > 0 ->
        ctx |> delitem(7311, 1) |> warp("y_airport", 148, 51)

      zeny(ctx) >= 1200 ->
        ctx |> pay_zeny(1200) |> warp("y_airport", 148, 51)

      true ->
        ctx
        |> mes("[Airport Staff]")
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
    |> mes("have a nice day.")
    |> close()
  end
end
