defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.DrunkenLady234115 do
  @moduledoc """
  A tavern patron complains about the quality of the drinks.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Toms
    - Euphy
    - Joseph
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ve_in",
        x: 234,
        y: 115,
        dir: 3,
        sprite: 940,
        name: "Drunken Lady",
        scope: :shared,
        unique_name: "Drunken Lady#2"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Drunken Lady]")
    |> mes("This tavern might look")
    |> mes("luxurious and gorgeous,")
    |> mes("but the drinks here stink!")
    |> mes("I can mix better drinks")
    |> mes("at home, no sweat at all~")
    |> close()
  end
end
