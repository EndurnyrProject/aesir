defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAirship.Boom0 do
  @moduledoc """
  Provides an invisible airship effect marker.

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
        x: 249,
        y: 50,
        dir: 0,
        sprite: 139,
        name: "boom0",
        scope: :shared,
        unique_name: "boom0#airplane"
      }
    ]

  @impl true
  def on_talk(ctx), do: ctx
end
