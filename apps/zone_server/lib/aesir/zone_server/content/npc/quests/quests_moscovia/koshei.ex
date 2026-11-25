defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.Koshei do
  @moduledoc """
  Koshei periodically threatens adventurers throughout the forest.

  ## Behavior

  - Timed events announce his threats and restart the timer.

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
        x: 5,
        y: 5,
        dir: 0,
        sprite: -1,
        name: "Koshei",
        scope: :shared,
        unique_name: "Koshei#rus47",
        trigger: {0, 0}
      }
    ]

  @impl true
  def on_event("OnInit", ctx), do: ev_oninit(ctx)
  def on_event("OnEnable", ctx), do: ev_onenable(ctx)
  def on_event("OnDisable", ctx), do: ev_ondisable(ctx)
  def on_event("OnTimer3000", ctx), do: ev_ontimer3000(ctx)
  def on_event("OnTimer63000", ctx), do: ev_ontimer63000(ctx)
  def on_event("OnTimer150000", ctx), do: ev_ontimer150000(ctx)
  def on_event("OnTimer300000", ctx), do: ev_ontimer300000(ctx)
  @impl true
  def on_talk(ctx), do: ctx

  def ev_oninit(ctx) do
    disablenpc(ctx, "Koshei#rus47")
  end

  def ev_onenable(ctx) do
    ctx |> initnpctimer() |> enablenpc("Koshei#rus47")
  end

  def ev_ondisable(ctx) do
    ctx |> stopnpctimer() |> disablenpc("Koshei#rus47")
  end

  def ev_ontimer3000(ctx) do
    mapannounce(
      ctx,
      "mosk_dun01",
      "Koshei, the Immortal : I will kill all who disturb me!! Cry in terror weak humans!!!",
      1,
      13_513_009
    )
  end

  def ev_ontimer63000(ctx) do
    mapannounce(
      ctx,
      "mosk_dun01",
      "Koshei, the Immortal : You worms, you mere monsters... I will curse all who are in my way!!",
      1,
      13_513_009
    )
  end

  def ev_ontimer150000(ctx) do
    mapannounce(
      ctx,
      "mosk_dun01",
      "Koshei, the Immortal : Mankind! Cry in terror!! Hahahahahahahhahahah!!!",
      1,
      13_513_009
    )
  end

  def ev_ontimer300000(ctx) do
    ctx |> stopnpctimer() |> initnpctimer()
  end
end
