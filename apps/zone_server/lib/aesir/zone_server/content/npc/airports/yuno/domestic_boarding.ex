defmodule Aesir.ZoneServer.Content.Npc.Airports.Yuno.DomesticBoarding do
  @moduledoc """
  Guides passengers from Juno Airport to the domestic airship boarding area.

  ## Behavior

  - Warps willing passengers to the domestic airship entrance in Juno.

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
        x: 145,
        y: 63,
        dir: 5,
        sprite: 91,
        name: "Domestic Boarding",
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
      |> mes("Would you like to board the")
      |> mes("Airship that flies to Einbroch,")
      |> mes("Lighthalzen and Hugel? If so,")
      |> mes("please let me guide you to that")
      |> mes("Airship's boarding area.")
      |> next()
      |> select(["Yes", "No"])

    if choice == 1 do
      warp(ctx, "yuno", 59, 244)
    else
      ctx
      |> mes("[Boarding Staff]")
      |> mes("Very well, then.")
      |> mes("Thank you for your")
      |> mes("patronage, and I hope")
      |> mes("you enjoy your travels~")
      |> close()
    end
  end
end
