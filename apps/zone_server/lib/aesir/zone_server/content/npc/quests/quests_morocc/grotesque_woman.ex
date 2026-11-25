defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMorocc.GrotesqueWoman do
  @moduledoc """
  A grotesque woman produces a cloaking effect when spoken to.

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
        x: 104,
        y: 55,
        dir: 3,
        sprite: 980,
        name: "Grotesque Woman",
        scope: :shared,
        unique_name: "Grotesque Woman#eva1"
      }
    ]

  @impl true
  def on_talk(ctx) do
    specialeffect(ctx, :cloaking)
  end
end
