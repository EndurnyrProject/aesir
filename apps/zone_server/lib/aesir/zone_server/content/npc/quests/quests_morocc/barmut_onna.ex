defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMorocc.BarmutOnna do
  @moduledoc """
  This hidden figure disables itself on initialization.

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
        map: "que_ba",
        x: 266,
        y: 268,
        dir: 3,
        sprite: 982,
        name: "",
        scope: :shared,
        unique_name: "#barmut_onna"
      }
    ]

  @impl true
  def on_event("OnInit", ctx), do: ev_oninit(ctx)
  @impl true
  def on_talk(ctx) do
    ev_oninit(ctx)
  end

  def ev_oninit(ctx) do
    disablenpc(ctx, "#barmut_onna")
  end
end
