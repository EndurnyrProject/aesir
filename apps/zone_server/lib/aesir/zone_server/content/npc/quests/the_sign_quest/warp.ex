defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.Warp do
  @moduledoc """
  Controls the quest's exit warp.

  ## Behavior

  - Enables or disables the exit and sends players to Niflheim on touch.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Kargha
    - L0ne_W0lf
    - Kazukin
    - Kisuka
    - CalciumKid
    - tr0n
    - Euphy
    - Joseph
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "que_sign01",
        x: 196,
        y: 44,
        dir: 0,
        sprite: -1,
        name: "Warp",
        scope: :shared,
        unique_name: "Warp#serin",
        trigger: {35, 35}
      }
    ]

  @impl true
  def on_talk(ctx), do: disablenpc(ctx, "Warp#serin")

  @impl true
  def on_event("OnDisable", ctx), do: disablenpc(ctx, "Warp#serin")
  def on_event("OnInit", ctx), do: disablenpc(ctx, "Warp#serin")
  def on_event("OnEnable", ctx), do: enablenpc(ctx, "Warp#serin")
  def on_event("OnTouch_", ctx), do: warp(ctx, "niflheim", 30, 156)
end
