defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.DrunkenLady do
  @moduledoc """
  A tavern patron enjoys free drinks despite her boring companion.

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
        x: 232,
        y: 117,
        dir: 5,
        sprite: 940,
        name: "Drunken Lady",
        scope: :shared,
        unique_name: "Drunken Lady#1"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Drunken Lady]")
    |> mes("This guys' actually")
    |> mes("pretty boring, but...")
    |> mes("I get free drinks if")
    |> mes("I can put up with him~")
    |> close()
  end
end
