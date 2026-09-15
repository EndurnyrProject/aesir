defmodule Aesir.ZoneServer.Content.Npc.Airports.Rachel.Toairplane do
  @moduledoc """
  Boards passengers onto the international airship from Rachel.

  ## Behavior

  - Accepts a Free Airship Ticket or charges the 1,200 zeny fare.
  - Refuses boarding when the passenger has neither a ticket nor enough zeny.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ra_fild12",
        x: 295,
        y: 208,
        dir: 0,
        sprite: 45,
        name: "toairplane",
        scope: :shared,
        unique_name: "toairplane#rachel",
        trigger: {1, 1}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch", ctx) do
    {ctx, choice} =
      ctx
      |> mes("To use the airship, you are required to pay 1,200 zeny or a Free Airship Ticket.")
      |> mes("Would you like to use the service?")
      |> next()
      |> select(["Yes", "No"])

    if choice == 1, do: board(ctx), else: farewell(ctx)
  end

  defp board(ctx) do
    cond do
      count_item(ctx, 7311) > 0 ->
        ctx |> delitem(7311, 1) |> warp("airplane_01", 245, 60)

      zeny(ctx) >= 1200 ->
        ctx |> pay_zeny(1200) |> warp("airplane_01", 245, 60)

      true ->
        ctx
        |> mes("I am sorry, but you do not have enough money.")
        |> mes("Please remember, you are required to pay 1,200 zeny to use the service.")
        |> close()
    end
  end

  defp farewell(ctx), do: ctx |> mes("Thank you, please come again.") |> close()
end
