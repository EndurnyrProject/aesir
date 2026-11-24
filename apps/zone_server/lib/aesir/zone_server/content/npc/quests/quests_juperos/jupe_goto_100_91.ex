defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsJuperos.JupeGoto10091 do
  @moduledoc """
  Controls the temporary second-floor portal.

  ## Behavior

  - Transfers visitors while the timed portal is enabled.

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
        map: "juperos_01",
        x: 100,
        y: 91,
        dir: 0,
        sprite: -1,
        name: "jupe_goto",
        scope: :shared,
        unique_name: "jupe_goto#2",
        trigger: {2, 2}
      }
    ]

  @impl true
  def on_talk(ctx) do
    on_event("OnInit", ctx)
  end

  @impl true
  def on_event("OnInit", ctx) do
    disablenpc(ctx, "jupe_goto#2")
  end

  def on_event("OnEnable", ctx) do
    ctx |> enablenpc("jupe_goto#2") |> disablenpc("jupe_goto#1") |> initnpctimer()
  end

  def on_event("OnTouch_", ctx) do
    warp(ctx, "juperos_02", 128, 278)
  end

  def on_event("OnTimer2000", ctx) do
    ctx |> enablenpc("jupe_goto#1") |> disablenpc("jupe_goto#2")
  end
end
