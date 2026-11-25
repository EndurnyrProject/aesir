defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.QuestsMoscovia.MosRus do
  @moduledoc """
  The Gray Wolf and Maria Morebna share a timed visibility controller.

  ## Behavior

  - Events enable them temporarily and disable them after two minutes.

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
      %{name: "mos_rus", scope: :shared, unique_name: "mos_rus#main"},
      %{
        map: "mosk_dun01",
        x: 50,
        y: 256,
        dir: 3,
        sprite: 972,
        name: "Gray Wolf",
        scope: :shared,
        unique_name: "Gray Wolf#rus05"
      },
      %{
        map: "mosk_dun01",
        x: 46,
        y: 256,
        dir: 3,
        sprite: 958,
        name: "Maria Morebna",
        scope: :shared,
        unique_name: "Maria Morebna#rus46"
      }
    ]

  @impl true
  def on_event("OnEnable", ctx), do: ev_onenable(ctx)
  def on_event("OnTimer120000", ctx), do: ev_ontimer120000(ctx)
  def on_event("OnDisable", ctx), do: ev_ondisable(ctx)
  def on_event("OnInit", ctx), do: ev_oninit(ctx)
  @impl true
  def on_talk(ctx), do: ctx

  def ev_onenable(ctx) do
    ctx |> initnpctimer() |> enablenpc()
  end

  def ev_ontimer120000(ctx) do
    ev_ondisable(ctx)
  end

  def ev_ondisable(ctx) do
    ctx |> stopnpctimer() |> ev_oninit()
  end

  def ev_oninit(ctx) do
    disablenpc(ctx)
  end
end
