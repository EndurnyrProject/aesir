defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAirship.Ferlock do
  @moduledoc """
  Controls Ferlock’s temporary appearance in the laboratory.

  ## Behavior

  - Enables Ferlock on entry and disables him after two minutes.

  ## Credits

  - Original from rAthena, authors and contributors:
    - Samuray22
    - SinSloth
    - L0ne_W0lf
    - brianluau
    - Joseph
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
        map: "ein_in01",
        x: 263,
        y: 35,
        dir: 3,
        sprite: 873,
        name: "Ferlock",
        scope: :shared,
        unique_name: "Ferlock#lab"
      }
    ]

  @impl true
  def on_event("OnEnter", ctx), do: ev_onenter(ctx)
  def on_event("OnTimer120000", ctx), do: ev_ontimer120000(ctx)
  def on_event("OnInit", ctx), do: ev_oninit(ctx)
  @impl true
  def on_talk(ctx) do
    ctx
  end

  def ev_onenter(ctx) do
    ctx |> enablenpc("Ferlock#lab") |> initnpctimer()
  end

  def ev_ontimer120000(ctx) do
    ev_oninit(ctx)
  end

  def ev_oninit(ctx) do
    ctx |> disablenpc("Ferlock#lab") |> stopnpctimer()
  end
end
