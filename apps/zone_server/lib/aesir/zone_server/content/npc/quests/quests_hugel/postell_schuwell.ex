defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.PostellSchuwell do
  @moduledoc """
  Shows Postell during his visit to Allen.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - SinSloth
    - Samuray22
    - L0ne_W0lf
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
        map: "hu_in01",
        x: 385,
        y: 247,
        dir: 5,
        sprite: 97,
        name: "Postell Schuwell",
        scope: :shared,
        unique_name: "Postell Schuwell#D"
      }
    ]

  @impl true
  def on_event("OnInit", ctx), do: ev_oninit(ctx)
  def on_event("OnEnable", ctx), do: ev_onenable(ctx)
  def on_event("OnTimer100000", ctx), do: ev_ontimer100000(ctx)
  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Postell]")
    |> mes("Hey, uh...")
    |> mes("I'm in the middle")
    |> mes("of something here.")
    |> close()
  end

  def ev_oninit(ctx) do
    disablenpc(ctx, "Postell Schuwell#D")
  end

  def ev_onenable(ctx) do
    ctx |> enablenpc("Postell Schuwell#D") |> initnpctimer()
  end

  def ev_ontimer100000(ctx) do
    ctx |> disablenpc("Postell Schuwell#D") |> stopnpctimer()
  end
end
