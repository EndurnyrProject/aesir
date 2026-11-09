defmodule Aesir.ZoneServer.Content.Npc.Floating.Airports.Izlude.AirshipStaffIzlude do
  @moduledoc """
  Airship Staff who sells passage on the Izlude airship to Juno and Rachel.

  ## Behavior

  - Charges 1,200 zeny for the flight, waived when the player carries a Free
    Ticket for Airship.
  - Players who can neither pay nor show a ticket are turned away without
    boarding.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script airports/izlude.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "izlude",
        x: 202,
        y: 75,
        dir: 3,
        sprite: 90,
        name: "Airship Staff",
        scope: :renewal,
        unique_name: "Airship Staff#izlude"
      },
      %{
        map: "izlude_a",
        x: 202,
        y: 75,
        dir: 3,
        sprite: 90,
        name: "Airship Staff",
        scope: :renewal,
        unique_name: "Airship Staff#izlude_a"
      },
      %{
        map: "izlude_b",
        x: 202,
        y: 75,
        dir: 3,
        sprite: 90,
        name: "Airship Staff",
        scope: :renewal,
        unique_name: "Airship Staff#izlude_b"
      },
      %{
        map: "izlude_c",
        x: 202,
        y: 75,
        dir: 3,
        sprite: 90,
        name: "Airship Staff",
        scope: :renewal,
        unique_name: "Airship Staff#izlude_c"
      },
      %{
        map: "izlude_d",
        x: 202,
        y: 75,
        dir: 3,
        sprite: 90,
        name: "Airship Staff",
        scope: :renewal,
        unique_name: "Airship Staff#izlude_d"
      },
      %{
        map: "izlude",
        x: 206,
        y: 55,
        dir: 3,
        sprite: 90,
        name: "Airship Staff",
        scope: :pre_renewal,
        unique_name: "Airship Staff#izlude"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @fare 1_200
  @free_ticket 7311

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, answer} =
      ctx
      |> mes("[Airship Staff]")
      |> mes("Welcome! Would you like")
      |> mes("to board the Airship that")
      |> mes("departs on the flight which stops")
      |> mes("in Juno and Rachel?")
      |> next()
      |> select(["Board the Airship to Juno/Rachel.", "Cancel."])

    if answer == 1 do
      boarding(ctx)
    else
      farewell(ctx)
    end
  end

  defp boarding(ctx) do
    {ctx, answer} =
      ctx
      |> mes("[Airship Staff]")
      |> mes("The boarding fee is")
      |> mes("1,200 zeny. However, this")
      |> mes("charged is waived if you use")
      |> mes("a Free Ticket for Airship. Now,")
      |> mes("would you still like to board?")
      |> next()
      |> select(["Yes", "No"])

    if answer == 1 do
      fly(ctx)
    else
      farewell(ctx)
    end
  end

  defp fly(ctx) do
    cond do
      count_item(ctx, @free_ticket) > 0 ->
        ctx |> delitem(@free_ticket, 1) |> warp("airplane_01", 244, 58)

      zeny(ctx) >= @fare ->
        ctx |> pay_zeny(@fare) |> warp("airplane_01", 244, 58)

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
    |> mes("[Airship Staff]")
    |> mes("Thank you and")
    |> mes("please come again.")
    |> mes("Have a good day~")
    |> close()
  end
end
