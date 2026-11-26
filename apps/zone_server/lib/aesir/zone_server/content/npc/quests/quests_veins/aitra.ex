defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.Aitra do
  @moduledoc """
  Keeps Aitra hidden until enabled by the quest.

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
        x: 248,
        y: 104,
        dir: 5,
        sprite: 939,
        name: "Aitra",
        scope: :shared,
        unique_name: "Aitra#vol"
      }
    ]

  @impl true
  def on_event("OnInit", ctx), do: ev_oninit(ctx)
  @impl true
  def on_talk(ctx), do: ctx

  def ev_oninit(ctx), do: disablenpc(ctx, "Aitra#vol")
end
