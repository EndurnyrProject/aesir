defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.Sch3 do
  @moduledoc """
  An initially disabled figure serves the prison investigation.

  ## Behavior

  - Disables the figure on initialization.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Toms
    - Euphy
    - Joseph
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "morocc",
        x: 298,
        y: 150,
        dir: 1,
        sprite: 899,
        name: "????",
        scope: :shared,
        unique_name: "????#sch3"
      }
    ]

  @impl true
  def on_event("OnInit", ctx), do: ev_oninit(ctx)
  @impl true
  def on_talk(ctx), do: ctx

  def ev_oninit(ctx), do: disablenpc(ctx, "????#sch3")
end
