defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.VolTime2 do
  @moduledoc """
  Restores the temple scene after the guard finishes cleaning.

  ## Behavior

  - Announces the cleanup and restores the guard and vase after a timer.

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
      %{map: "ra_temin", x: 5, y: 5, dir: 1, sprite: 844, name: "vol_time2", scope: :shared}
    ]

  @impl true
  def on_event("OnInit", ctx), do: ev_oninit(ctx)
  def on_event("OnEnable", ctx), do: ev_onenable(ctx)
  def on_event("OnTimer30000", ctx), do: ev_ontimer30000(ctx)
  @impl true
  def on_talk(ctx) do
    ev_oninit(ctx)
  end

  def ev_oninit(ctx) do
    stopnpctimer(ctx)
  end

  def ev_onenable(ctx) do
    initnpctimer(ctx)
  end

  def ev_ontimer30000(ctx) do
    ctx
    |> mapannounce(
      "ra_temin",
      "Guard Krodger: Phew~, now I'm done cleaning up this mess.",
      1,
      "0xFFCE00"
    )
    |> stopnpctimer()
    |> disablenpc("Rachel Guard#vol2_1")
    |> enablenpc("Rachel Guard#vol2")
    |> enablenpc("Flower Vase#vol")
  end
end
