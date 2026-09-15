defmodule Aesir.ZoneServer.Content.Npc.Airports.Yuno.ArrivalStaff do
  @moduledoc """
  Guides arriving passengers from the Juno boarding area to the main terminal.

  ## Behavior

  - Warns that returning to the airship requires paying the boarding fee again.
  - Warps passengers to the main terminal after confirmation.

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
        y: 49,
        dir: 3,
        sprite: 90,
        name: "Arrival Staff",
        scope: :shared,
        unique_name: "y_airport2"
      },
      %{
        map: "y_airport",
        x: 126,
        y: 51,
        dir: 3,
        sprite: 90,
        name: "Arrival Staff",
        scope: :shared,
        unique_name: "Arrival Staff#y_air2b"
      },
      %{
        map: "y_airport",
        x: 158,
        y: 50,
        dir: 3,
        sprite: 90,
        name: "Arrival Staff",
        scope: :shared,
        unique_name: "Arrival Staff#y_air2c"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Airport Staff]")
      |> mes("Welcome to Juno Airport. If you've just arrived from your")
      |> mes("flight, let me guide you to the main terminal. Otherwise, please")
      |> mes("board the departing Airship to reach your intended destination.")
      |> next()
      |> select(["Exit to main terminal", "Cancel"])

    if choice == 1, do: confirm_exit(ctx), else: farewell(ctx)
  end

  defp confirm_exit(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Airport Staff]")
      |> mes("Once you're in the main terminal, you must pay the fee once again")
      |> mes("to board a departing Airship. You should only exit if your intended")
      |> mes("destination is Juno. Proceed to")
      |> mes("exit to the main terminal?")
      |> next()
      |> select(["Yes", "No"])

    if choice == 1, do: warp(ctx, "y_airport", 142, 40), else: farewell(ctx)
  end

  defp farewell(ctx) do
    ctx
    |> mes("[Airport Staff]")
    |> mes("Alright, thank you")
    |> mes("for your patronage")
    |> mes("and I hope you have")
    |> mes("a pleasant flight~")
    |> close()
  end
end
