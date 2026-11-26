defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.Agent do
  @moduledoc """
  An agent remains hidden until summoned for the Nameless Island quest.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Koca
    - Yommy
    - brianluau
    - Euphy
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "airplane_01",
        x: 95,
        y: 61,
        dir: 3,
        sprite: 899,
        name: "Agent",
        scope: :shared,
        unique_name: "Agent#pc1"
      }
    ]

  @impl true
  def on_event("OnInit", ctx), do: ev_oninit(ctx)
  @impl true
  def on_talk(ctx) do
    ctx
  end

  def ev_oninit(ctx) do
    hideonnpc(ctx, "Agent#pc1")
  end
end
