defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMorocc.GrotesqueMan48227 do
  @moduledoc """
  A grotesque man produces a cloaking effect when spoken to.

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
        x: 48,
        y: 227,
        dir: 7,
        sprite: 999,
        name: "Grotesque Man",
        scope: :shared,
        unique_name: "Grotesque Man#zid2"
      }
    ]

  @impl true
  def on_talk(ctx) do
    specialeffect(ctx, :cloaking)
  end
end
