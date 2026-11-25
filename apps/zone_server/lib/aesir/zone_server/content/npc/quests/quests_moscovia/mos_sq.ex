defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.MosSq do
  @moduledoc """
  A decorative squirrel stands in the field.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Kisuka
    - brianluau
    - Gepard
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Lemongrass
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "mosk_fild01",
        x: 113,
        y: 108,
        dir: 5,
        sprite: 1104,
        name: "",
        scope: :shared,
        unique_name: "#mos_sq"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
  end
end
