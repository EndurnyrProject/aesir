defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsJuperos.Warp80221 do
  @moduledoc """
  Temporary warp portal behind the crest device of Juperos security checkpoint 2-1.

  ## Behavior

  - Opens with a portal effect and sound when the checkpoint's crest device accepts its
    Crest Piece.
  - Sends whoever steps in past the checkpoint, then closes 22.5 seconds after opening.

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
        map: "jupe_area2",
        x: 80,
        y: 221,
        dir: 0,
        sprite: 139,
        name: "Warp",
        scope: :shared,
        unique_name: "Warp#2-1",
        trigger: {2, 2}
      }
    ]

  @impl true
  def on_event("OnInit", ctx), do: disablenpc(ctx, "Warp#2-1")

  def on_event("OnEnable", ctx) do
    ctx
    |> enablenpc("Warp#2-1")
    |> specialeffect(:big_portal)
    |> soundeffectall("jupe_warp.wav", 0)
    |> initnpctimer()
  end

  def on_event("OnTouch_", ctx), do: warp(ctx, "jupe_area2", 116, 259)

  def on_event("OnTimer22500", ctx), do: ctx |> stopnpctimer() |> disablenpc("Warp#2-1")

  @impl true
  def on_talk(ctx), do: on_event("OnInit", ctx)
end
