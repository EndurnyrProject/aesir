defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.Sch1 do
  @moduledoc """
  Hides a figure until the investigation requires their appearance.

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
        x: 294,
        y: 152,
        dir: 0,
        sprite: 899,
        name: "????",
        scope: :shared,
        unique_name: "????#sch1"
      }
    ]

  @impl true
  def on_event("OnInit", ctx), do: ev_oninit(ctx)
  @impl true
  def on_talk(ctx) do
    ctx
  end

  def ev_oninit(ctx) do
    disablenpc(ctx, "????#sch1")
  end
end
