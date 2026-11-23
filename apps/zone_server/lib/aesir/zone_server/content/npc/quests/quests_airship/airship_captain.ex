defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAirship.AirshipCaptain do
  @moduledoc """
  Displays Captain Tarlock during the airship invasion.

  ## Behavior

  - Hides the captain on initialization and clears his portrait after dialogue.

  ## Credits

  - Original from rAthena, authors and contributors:
    - Samuray22
    - SinSloth
    - L0ne_W0lf
    - brianluau
    - Joseph
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "airplane_01",
        x: 246,
        y: 54,
        dir: 3,
        sprite: 873,
        name: "Airship Captain",
        scope: :shared,
        unique_name: "Airship Captain#02"
      }
    ]

  @impl true
  def on_event("OnInit", ctx), do: ev_oninit(ctx)
  @impl true
  def on_talk(ctx) do
    ctx
    |> cutin("fly_felrock", 2)
    |> mes("[Tarlock]")
    |> mes("I am Tarlock,")
    |> mes("captain of this")
    |> mes("Airship. Go and")
    |> mes("fight with the")
    |> mes("Gremlins!")
    |> close()
    |> cutin("", 255)
  end

  def ev_oninit(ctx) do
    hideonnpc(ctx, "Airship Captain#02")
  end
end
