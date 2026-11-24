defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsJuperos.RestrictedArea do
  @moduledoc """
  Controls the timed entrance to the restricted area.

  ## Behavior

  - Announces and displays the entrance before closing it and reactivating the switches.
  - Transfers visitors through the entrance while it is active.

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
        map: "juperos_02",
        x: 130,
        y: 149,
        dir: 0,
        sprite: 139,
        name: "Restricted Area",
        scope: :shared,
        unique_name: "Restricted Area#jupe",
        trigger: {2, 2}
      }
    ]

  @impl true
  def on_talk(ctx) do
    on_event("OnInit", ctx)
  end

  @impl true
  def on_event("OnInit", ctx) do
    disablenpc(ctx, "Restricted Area#jupe")
  end

  def on_event("OnEnable", ctx) do
    ctx |> enablenpc("Restricted Area#jupe") |> initnpctimer()
  end

  def on_event("OnTimer5000", ctx) do
    mapannounce(ctx, "juperos_02", "Vroom! Vroom!", 1, "0xE559A2")
  end

  def on_event("OnTimer7000", ctx) do
    mapannounce(ctx, "juperos_02", "Attention, visitors.", 1, "0xE559A2")
  end

  def on_event("OnTimer9000", ctx) do
    mapannounce(
      ctx,
      "juperos_02",
      "You are allowed to enter the next zone for a short period of time. Please use the portal in the center of the map.",
      1,
      "0xE559A2"
    )
  end

  def on_event("OnTimer9001", ctx) do
    specialeffect(ctx, :big_portal)
  end

  def on_event("OnTimer23000", ctx) do
    specialeffect(ctx, :big_portal)
  end

  def on_event("OnTimer46000", ctx) do
    specialeffect(ctx, :big_portal)
  end

  def on_event("OnTimer69000", ctx) do
    specialeffect(ctx, :big_portal)
  end

  def on_event("OnTimer92000", ctx) do
    specialeffect(ctx, :big_portal)
  end

  def on_event("OnTimer115000", ctx) do
    specialeffect(ctx, :big_portal)
  end

  def on_event("OnTimer161000", ctx) do
    specialeffect(ctx, :big_portal)
  end

  def on_event("OnTimer184000", ctx) do
    specialeffect(ctx, :big_portal)
  end

  def on_event("OnTimer207000", ctx) do
    specialeffect(ctx, :big_portal)
  end

  def on_event("OnTimer230000", ctx) do
    specialeffect(ctx, :big_portal)
  end

  def on_event("OnTimer253000", ctx) do
    specialeffect(ctx, :big_portal)
  end

  def on_event("OnTimer276000", ctx) do
    specialeffect(ctx, :big_portal)
  end

  def on_event("OnTimer299000", ctx) do
    specialeffect(ctx, :big_portal)
  end

  def on_event("OnTimer322000", ctx) do
    specialeffect(ctx, :big_portal)
  end

  def on_event("OnTimer345000", ctx) do
    specialeffect(ctx, :big_portal)
  end

  def on_event("OnTimer368000", ctx) do
    specialeffect(ctx, :big_portal)
  end

  def on_event("OnTimer391000", ctx) do
    specialeffect(ctx, :big_portal)
  end

  def on_event("OnTimer414000", ctx) do
    specialeffect(ctx, :big_portal)
  end

  def on_event("OnTimer460000", ctx) do
    specialeffect(ctx, :big_portal)
  end

  def on_event("OnTimer483000", ctx) do
    specialeffect(ctx, :big_portal)
  end

  def on_event("OnTimer506000", ctx) do
    specialeffect(ctx, :big_portal)
  end

  def on_event("OnTimer529000", ctx) do
    specialeffect(ctx, :big_portal)
  end

  def on_event("OnTimer552000", ctx) do
    specialeffect(ctx, :big_portal)
  end

  def on_event("OnTimer556000", ctx) do
    mapannounce(
      ctx,
      "juperos_02",
      "Attention, visitors. The gate to the next zone will close shortly.",
      1,
      "0xE559A2"
    )
  end

  def on_event("OnTimer561000", ctx) do
    mapannounce(ctx, "juperos_02", "1 minute remaining until Gate Closure. ", 1, "0xE559A2")
  end

  def on_event("OnTimer598000", ctx) do
    specialeffect(ctx, :big_portal)
  end

  def on_event("OnTimer600000", ctx) do
    mapannounce(ctx, "juperos_02", "The gate is being closed...", 1, "0xE559A2")
  end

  def on_event("OnTimer603000", ctx) do
    mapannounce(ctx, "juperos_02", " Switches will reactivate shortly.", 1, "0xE559A2")
  end

  def on_event("OnTimer621000", ctx) do
    disablenpc(ctx, "Restricted Area#jupe")
  end

  def on_event("OnTimer1200000", ctx) do
    ctx |> donpcevent("3F Gate Switch#jupe::OnEnable") |> stopnpctimer()
  end

  def on_event("OnTouch_", ctx) do
    warp(ctx, "jupe_gate", 50, 167)
  end
end
