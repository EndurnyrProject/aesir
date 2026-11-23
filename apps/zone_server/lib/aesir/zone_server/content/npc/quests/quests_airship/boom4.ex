defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAirship.Boom4 do
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
        x: 245,
        y: 59,
        dir: 0,
        sprite: 139,
        name: "boom4",
        scope: :shared,
        unique_name: "boom4#airplane"
      }
    ]

  @impl true
  def on_talk(ctx), do: ctx
end
