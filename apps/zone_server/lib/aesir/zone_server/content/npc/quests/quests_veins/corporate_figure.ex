defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.CorporateFigure do
  @moduledoc """
  A corporate figure is disabled when initialized.

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
        y: 284,
        dir: 0,
        sprite: 109,
        name: "Corporate Figure",
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
    disablenpc(ctx, "Corporate Figure")
  end
end
