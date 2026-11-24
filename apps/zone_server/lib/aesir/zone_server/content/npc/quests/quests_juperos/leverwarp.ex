defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsJuperos.Leverwarp do
  @moduledoc """
  Controls a temporary checkpoint warp.

  ## Behavior

  - Enables the portal briefly and transfers visitors to the gate.

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
        map: "jupe_area1",
        x: 117,
        y: 157,
        dir: 0,
        sprite: 139,
        name: "LeverWarp",
        scope: :shared,
        unique_name: "LeverWarp#ufe",
        trigger: {2, 2}
      }
    ]

  @impl true
  def on_talk(ctx) do
    on_event("OnInit", ctx)
  end

  @impl true
  def on_event("OnInit", ctx) do
    disablenpc(ctx, "LeverWarp#ufe")
  end

  def on_event("OnEnable", ctx) do
    ctx
    |> enablenpc("LeverWarp#ufe")
    |> specialeffect(:big_portal)
    |> soundeffectall("jupe_warp.wav", 0)
    |> initnpctimer()
  end

  def on_event("OnTouch_", ctx) do
    warp(ctx, "jupe_gate", 28, 30)
  end

  def on_event("OnTimer3000", ctx) do
    ctx |> stopnpctimer() |> disablenpc("LeverWarp#ufe")
  end
end
