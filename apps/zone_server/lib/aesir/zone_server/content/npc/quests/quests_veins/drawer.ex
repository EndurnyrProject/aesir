defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.Drawer do
  @moduledoc """
  Describes the documents stored in the temple drawers.

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
        x: 87,
        y: 118,
        dir: 3,
        sprite: 111,
        name: "Drawer",
        scope: :shared,
        unique_name: "VeinsDrawer",
        hidden_name: "vol1"
      },
      %{
        map: "ra_temin",
        x: 83,
        y: 118,
        dir: 3,
        sprite: 111,
        name: "Drawer",
        scope: :shared,
        unique_name: "Drawer#vol2"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("^3355FFThere are some neatly")
    |> mes("printed and organized")
    |> mes("documents inside")
    |> mes("these drawers.^000000")
    |> close()
  end
end
