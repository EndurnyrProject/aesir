defmodule Aesir.ZoneServer.Content.Npc.Airports.Einbroch.ArrivalStaff do
  @moduledoc """
  Guides arriving passengers from the Einbroch boarding area to the main terminal.

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
        map: "airport",
        x: 143,
        y: 49,
        dir: 3,
        sprite: 90,
        name: "Arrival Staff",
        scope: :shared,
        unique_name: "airport2"
      },
      %{
        map: "airport",
        x: 126,
        y: 51,
        dir: 3,
        sprite: 90,
        name: "Arrival Staff",
        scope: :shared,
        unique_name: "Arrival Staff#airport2b"
      },
      %{
        map: "airport",
        x: 158,
        y: 50,
        dir: 3,
        sprite: 90,
        name: "Arrival Staff",
        scope: :shared,
        unique_name: "Arrival Staff#airport2c"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Arrival Staff]")
      |> mes("Welcome to Einbroch Airport.")
      |> mes("If you are arriving from your")
      |> mes("flight, let me guide you to the")
      |> mes("main terminal. Otherwise, please board the Airship to depart to")
      |> mes("Juno, Lighthalzen and Hugel.")
      |> next()
      |> select(["Exit to main terminal.", "Cancel."])

    if choice == 1, do: confirm_exit(ctx), else: farewell(ctx)
  end

  defp confirm_exit(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Arrival Staff]")
      |> mes("Once you're in the main terminal, you will need to pay the fee again")
      |> mes("to board an Airship. You should")
      |> mes("only exit if the city of Einbroch")
      |> mes("is your intended destination.")
      |> mes("Proceed to the main terminal?")
      |> next()
      |> select(["Yes", "No"])

    if choice == 1, do: warp(ctx, "airport", 142, 40), else: farewell(ctx)
  end

  defp farewell(ctx) do
    ctx
    |> mes("[Arrival Staff]")
    |> mes("Alright, thank you")
    |> mes("for your patronage")
    |> mes("and I hope you have")
    |> mes("a pleasant flight~")
    |> close()
  end
end
