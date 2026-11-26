defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.RachelGuard42124 do
  @moduledoc """
  A guard who is initially disabled.

  ## Behavior

  - Starts disabled and has no dialogue.

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
        x: 42,
        y: 124,
        dir: 3,
        sprite: 934,
        name: "Rachel Guard",
        scope: :shared,
        unique_name: "Rachel Guard#vol1_1"
      }
    ]

  @impl true
  def on_event("OnInit", ctx), do: ev_oninit(ctx)
  @impl true
  def on_talk(ctx) do
    ctx
  end

  def ev_oninit(ctx) do
    disablenpc(ctx, "Rachel Guard#vol1_1")
  end
end
