defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMorocc.Jaeda do
  @moduledoc """
  Jaeda disables herself on initialization or when spoken to.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - Lupus
    - SinSloth
    - Samuray22
    - L0ne_W0lf
    - Gepard
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
        map: "cave",
        x: 85,
        y: 101,
        dir: 3,
        sprite: 401,
        name: "Jaeda",
        scope: :shared,
        unique_name: "Jaeda#garas1"
      }
    ]

  @impl true
  def on_event("OnInit", ctx), do: ev_oninit(ctx)
  @impl true
  def on_talk(ctx) do
    ev_oninit(ctx)
  end

  def ev_oninit(ctx) do
    disablenpc(ctx, "Jaeda#garas1")
  end
end
