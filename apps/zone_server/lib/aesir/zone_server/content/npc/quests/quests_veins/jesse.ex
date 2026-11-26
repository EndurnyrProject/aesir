defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.Jesse do
  @moduledoc """
  Jesse is hidden when the NPC initializes.

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
        map: "ra_in01",
        x: 58,
        y: 389,
        dir: 0,
        sprite: 707,
        name: "Jesse",
        scope: :shared,
        unique_name: "Jesse#sch"
      }
    ]

  @impl true
  def on_event("OnInit", ctx), do: ev_oninit(ctx)
  @impl true
  def on_talk(ctx), do: ctx

  def ev_oninit(ctx), do: disablenpc(ctx, "Jesse#sch")
end
