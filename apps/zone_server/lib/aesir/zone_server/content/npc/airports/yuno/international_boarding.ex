defmodule Aesir.ZoneServer.Content.Npc.Airports.Yuno.InternationalBoarding do
  @moduledoc """
  Guides passengers from Juno Airport to the international airship boarding area.

  ## Behavior

  - Warps willing passengers to the international airship entrance in Juno.

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
        x: 140,
        y: 63,
        dir: 5,
        sprite: 91,
        name: "International Boarding",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Boarding Staff]")
      |> mes("Would you like to board")
      |> mes("the Airship which flies to")
      |> mes("Juno, Izlude and Rachel?")
      |> mes("If so, let me guide")
      |> mes("you to the boarding area.")
      |> next()
      |> select(["Yes", "No"])

    if choice == 1 do
      warp(ctx, "yuno", 47, 244)
    else
      ctx
      |> mes("[Boarding Staff]")
      |> mes("Alright, then.")
      |> mes("Thank you for flying")
      |> mes("with us, and I hope you")
      |> mes("enjoy your travels on our")
      |> mes("state of the art Airships.")
      |> close()
    end
  end
end
