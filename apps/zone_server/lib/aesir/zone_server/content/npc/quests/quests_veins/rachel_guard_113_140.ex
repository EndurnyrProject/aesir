defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.RachelGuard113140 do
  @moduledoc """
  A guard cleaning up a broken vase.

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
        x: 113,
        y: 140,
        dir: 1,
        sprite: 934,
        name: "Rachel Guard",
        scope: :shared,
        unique_name: "Rachel Guard#vol2_1"
      }
    ]

  @impl true
  def on_event("OnInit", ctx), do: ev_oninit(ctx)
  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Guard Krodger]")
    |> mes("What's with this vase?")
    |> mes("They always send me out")
    |> mes("here to clean up this mess!")
    |> mes("I mean, it happens so often,")
    |> mes("I don't think it's accidental.")
    |> mes("You think it's vandals?")
    |> close()
  end

  def ev_oninit(ctx) do
    disablenpc(ctx, "Rachel Guard#vol2_1")
  end
end
