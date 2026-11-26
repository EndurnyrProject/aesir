defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.RachelGuard82133 do
  @moduledoc """
  Guards the high priest and prevents entry.

  ## Behavior

  - Starts enabled and returns intruders to the hallway.

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
        x: 82,
        y: 133,
        dir: 7,
        sprite: 934,
        name: "Rachel Guard",
        scope: :shared,
        unique_name: "Rachel Guard#vol2",
        trigger: {5, 2}
      }
    ]

  @impl true
  def on_event("OnInit", ctx), do: ev_oninit(ctx)
  def on_event("OnTouch", ctx), do: ev_ontouch(ctx)
  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Guard Krodger]")
    |> mes("High Priest Vildt isn't")
    |> mes("here right now. Please")
    |> mes("come back later if you")
    |> mes("wish to see him.")
    |> close()
  end

  def ev_oninit(ctx) do
    enablenpc(ctx, "Rachel Guard#vol2")
  end

  def ev_ontouch(ctx) do
    warp(ctx, "ra_temin", 85, 137)
  end
end
