defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.Serin do
  @moduledoc """
  Stages Serin’s transformation during the quest.

  ## Behavior

  - Plays timed effects before hiding the dummy and enabling Serin and the Dark Lord.

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
        y: 39,
        dir: 4,
        sprite: 90,
        name: "Serin",
        scope: :shared,
        unique_name: "Serin#dummy"
      }
    ]

  @impl true
  def on_event("OnDisable", ctx), do: ev_ondisable(ctx)
  def on_event("OnInit", ctx), do: ev_oninit(ctx)
  def on_event("OnEnable", ctx), do: ev_onenable(ctx)
  def on_event("OnStart", ctx), do: ev_onstart(ctx)
  def on_event("OnTimer3000", ctx), do: ev_ontimer3000(ctx)
  def on_event("OnTimer6000", ctx), do: ev_ontimer6000(ctx)
  def on_event("OnTimer9000", ctx), do: ev_ontimer9000(ctx)
  def on_event("OnTimer13000", ctx), do: ev_ontimer13000(ctx)
  @impl true
  def on_talk(ctx) do
    ctx
  end

  def ev_ondisable(ctx) do
    ev_oninit(ctx)
  end

  def ev_oninit(ctx) do
    disablenpc(ctx, "Serin#dummy")
  end

  def ev_onenable(ctx) do
    enablenpc(ctx, "Serin#dummy")
  end

  def ev_onstart(ctx) do
    initnpctimer(ctx)
  end

  def ev_ontimer3000(ctx) do
    specialeffect(ctx, :glasswall)
  end

  def ev_ontimer6000(ctx) do
    specialeffect(ctx, :crashearth)
  end

  def ev_ontimer9000(ctx) do
    specialeffect(ctx, :lord)
  end

  def ev_ontimer13000(ctx) do
    ctx
    |> donpcevent("Serin#dummy::OnDisable")
    |> donpcevent("Dark Lord#serin::OnEnable")
    |> donpcevent("Serin#serin::OnEnable")
    |> stopnpctimer()
  end
end
