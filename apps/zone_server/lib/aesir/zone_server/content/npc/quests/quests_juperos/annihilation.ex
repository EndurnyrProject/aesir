defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsJuperos.Annihilation do
  @moduledoc """
  Expels players after the reception guard encounter times out.

  ## Behavior

  - Drains health and SP on touch and warps players out.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - SinSloth
    - L0ne_W0lf
    - Zephyrus
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "jupe_ele_r",
        x: 50,
        y: 89,
        dir: 0,
        sprite: -1,
        name: "Annihilation",
        scope: :shared,
        unique_name: "Annihilation#ufe",
        trigger: {35, 50}
      }
    ]

  @impl true
  def on_talk(ctx) do
    on_event("OnInit", ctx)
  end

  @impl true
  def on_event("OnInit", ctx) do
    disablenpc(ctx, "Annihilation#ufe")
  end

  def on_event("OnEnable", ctx) do
    ctx |> enablenpc("Annihilation#ufe") |> initnpctimer()
  end

  def on_event("OnTouch_", ctx) do
    percent_heal(ctx, hp: -99, sp: -100)
  end

  def on_event("OnTimer1000", ctx) do
    mapwarp(ctx, "jupe_ele_r", "jupe_gate", 49, 138)
  end

  def on_event("OnTimer1600", ctx) do
    enablenpc(ctx, "Elevator Escape#ufe")
  end

  def on_event("OnTimer3000", ctx) do
    ctx |> disablenpc("Annihilation#ufe") |> disablenpc("Elevator Escape#ufe")
  end
end
