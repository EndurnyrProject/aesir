defmodule Aesir.ZoneServer.Content.Npc.Airports.Einbroch.AirportStaff do
  @moduledoc """
  Sells entry to the Einbroch Airport boarding area.

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
        map: "airport",
        x: 143,
        y: 43,
        dir: 5,
        sprite: 90,
        name: "Airport Staff",
        scope: :shared,
        unique_name: "airport1"
      },
      %{
        map: "airport",
        x: 158,
        y: 43,
        dir: 5,
        sprite: 90,
        name: "Airport Staff",
        scope: :shared,
        unique_name: "Airport Staff#airport1b"
      },
      %{
        map: "airport",
        x: 126,
        y: 43,
        dir: 5,
        sprite: 90,
        name: "Airport Staff",
        scope: :shared,
        unique_name: "Airport Staff#airport1c"
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
      |> mes("Einbroch Airport,")
      |> mes("where we offer nonstop")
      |> mes("flights to the cities of")
      |> mes("Juno, Lighthalzen and Hugel.")
      |> next()
      |> select(["Board the Airship", "Cancel"])

    if choice == 1, do: offer_boarding(ctx), else: farewell(ctx)
  end

  defp offer_boarding(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Airport Staff]")
      |> mes("The Airship boarding fee")
      |> mes("is 1,200 zeny, but if you've")
      |> mes("got a Free Ticket for Airship,")
      |> mes("the fee will be waived. Will")
      |> mes("you board the Airship?")
      |> next()
      |> select(["Yes", "No"])

    if choice == 1, do: board(ctx), else: farewell(ctx)
  end

  defp board(ctx) do
    cond do
      count_item(ctx, 7311) > 0 ->
        ctx |> delitem(7311, 1) |> warp("airport", 148, 51)

      zeny(ctx) >= 1200 ->
        ctx |> pay_zeny(1200) |> warp("airport", 148, 51)

      true ->
        ctx
        |> mes("[Airport Staff]")
        |> mes("I'm sorry, but you don't")
        |> mes("have a Free Ticket for")
        |> mes("Airship and you don't have")
        |> mes("enough zeny for boarding")
        |> mes("the Airship. Remember, the")
        |> mes("boarding fee is 1,200 zeny.")
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
