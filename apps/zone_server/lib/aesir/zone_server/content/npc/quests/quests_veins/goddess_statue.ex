defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.GoddessStatue do
  @moduledoc """
  A statue depicts the goddess Freya.

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
        map: "ra_temin",
        x: 88,
        y: 117,
        dir: 3,
        sprite: 111,
        name: "Goddess Statue",
        scope: :shared,
        unique_name: "Goddess Statue#vol1"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("^3355FFIt's a statue of Freya,")
    |> mes("a goddess revered for her")
    |> mes("clemency and wisdom.^000000")
    |> close()
  end
end
