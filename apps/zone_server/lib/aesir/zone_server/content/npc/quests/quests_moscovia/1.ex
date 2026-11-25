defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.M1 do
  @moduledoc """
  A temporary portal carries adventurers into Marozka’s cave.

  ## Behavior

  - Enables the portal for 30 seconds before disabling it.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Kisuka
    - brianluau
    - Gepard
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Lemongrass
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "mosk_dun01",
        x: 45,
        y: 250,
        dir: 3,
        sprite: 45,
        name: "1",
        scope: :shared,
        unique_name: "1#rus27",
        trigger: {3, 3}
      }
    ]

  @impl true
  def on_event("OnTouch_", ctx), do: ev_ontouch(ctx)
  def on_event("OnEnable", ctx), do: ev_onenable(ctx)
  def on_event("OnTimer30000", ctx), do: ev_ontimer30000(ctx)
  def on_event("OnInit", ctx), do: ev_oninit(ctx)
  @impl true
  def on_talk(ctx), do: ctx

  def ev_ontouch(ctx) do
    warp(ctx, "mosk_que", 49, 22)
  end

  def ev_onenable(ctx) do
    ctx |> initnpctimer() |> specialeffect(:portal2) |> enablenpc("1#rus27")
  end

  def ev_ontimer30000(ctx) do
    ctx |> stopnpctimer() |> ev_oninit()
  end

  def ev_oninit(ctx) do
    disablenpc(ctx, "1#rus27")
  end
end
