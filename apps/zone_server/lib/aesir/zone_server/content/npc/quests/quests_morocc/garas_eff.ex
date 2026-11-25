defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMorocc.GarasEff do
  @moduledoc """
  An inactive scene prop stands in Juno.

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
        map: "yuno",
        x: 343,
        y: 204,
        dir: 1,
        sprite: 111,
        name: "",
        scope: :shared,
        unique_name: "#garas_eff"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
  end
end
