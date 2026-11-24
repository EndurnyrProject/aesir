defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsJuperos.Gate50171 do
  @moduledoc """
  Controls the temporary return portal.

  ## Behavior

  - Transfers visitors to the previous floor while enabled.

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
        map: "jupe_gate",
        x: 50,
        y: 171,
        dir: 0,
        sprite: -1,
        name: "gate",
        scope: :shared,
        unique_name: "gate#start#2",
        trigger: {2, 2}
      }
    ]

  @impl true
  def on_talk(ctx) do
    on_event("OnInit", ctx)
  end

  @impl true
  def on_event("OnInit", ctx) do
    disablenpc(ctx, "gate#start#2")
  end

  def on_event("OnTouch_", ctx) do
    warp(ctx, "juperos_02", 130, 142)
  end

  def on_event("OnTimer2000", ctx) do
    ctx |> enablenpc("gate#start") |> disablenpc("gate#start#2")
  end
end
