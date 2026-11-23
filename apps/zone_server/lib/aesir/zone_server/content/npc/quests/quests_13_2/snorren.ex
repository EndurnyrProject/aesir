defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests132.Snorren do
  @moduledoc """
  Controls the visibility of Snorren during the dungeon encounter.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Gepard
    - Masao
    - Euphy
    - Joseph
    - Jeybla
    - Mazvi

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "nyd_dun01",
        x: 55,
        y: 223,
        dir: 5,
        sprite: 454,
        name: "Snorren",
        scope: :shared,
        unique_name: "Snorren#ep13md17"
      }
    ]

  @impl true
  def on_event("OnInit", ctx), do: disablenpc(ctx, "Snorren#ep13md17")
  def on_event("OnDisable", ctx), do: disablenpc(ctx, "Snorren#ep13md17")
  def on_event("OnEnable", ctx), do: enablenpc(ctx, "Snorren#ep13md17")
  @impl true
  def on_talk(ctx) do
    disablenpc(ctx, "Snorren#ep13md17")
  end
end
