defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.ArunafeltzFigure do
  @moduledoc """
  An Arunafeltz guest is hidden when the hotel initializes.

  ## Behavior

  - The guest is disabled on initialization.

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
        map: "ein_in01",
        x: 181,
        y: 285,
        dir: 0,
        sprite: 920,
        name: "Arunafeltz Figure",
        scope: :shared
      }
    ]

  @impl true
  def on_event("OnInit", ctx), do: ev_oninit(ctx)
  @impl true
  def on_talk(ctx) do
    ctx
  end

  def ev_oninit(ctx) do
    disablenpc(ctx, "Arunafeltz Figure")
  end
end
