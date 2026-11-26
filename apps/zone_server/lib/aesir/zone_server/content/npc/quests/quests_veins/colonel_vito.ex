defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.ColonelVito do
  @moduledoc """
  Hides Colonel Vito until the camp scene requires him.

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
        map: "thor_camp",
        x: 187,
        y: 228,
        dir: 5,
        sprite: 946,
        name: "Colonel Vito",
        scope: :shared,
        unique_name: "Colonel Vito#1"
      }
    ]

  @impl true
  def on_event("OnInit", ctx), do: ev_oninit(ctx)
  @impl true
  def on_talk(ctx) do
    ctx
  end

  def ev_oninit(ctx) do
    disablenpc(ctx, "Colonel Vito#1")
  end
end
