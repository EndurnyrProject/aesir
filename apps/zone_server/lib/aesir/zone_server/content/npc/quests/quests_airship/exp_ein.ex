defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAirship.ExpEin do
  @moduledoc """
  Provides the Cherno workshop effect marker.

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
        map: "ein_in01",
        x: 127,
        y: 94,
        dir: 3,
        sprite: 111,
        name: "",
        scope: :shared,
        unique_name: "#exp_ein"
      }
    ]

  @impl true
  def on_talk(ctx), do: ctx
end
