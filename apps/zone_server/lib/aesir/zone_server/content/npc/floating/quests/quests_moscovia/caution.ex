defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.QuestsMoscovia.Caution do
  @moduledoc """
  Signs warn visitors not to swim in the marsh.

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
      %{name: "Caution", scope: :shared, unique_name: "NoSwim", hidden_name: "07rus"},
      %{
        map: "mosk_fild02",
        x: 101,
        y: 204,
        dir: 0,
        sprite: 837,
        name: "Caution",
        scope: :shared,
        unique_name: "Caution#rus01"
      },
      %{
        map: "mosk_fild02",
        x: 101,
        y: 200,
        dir: 0,
        sprite: 837,
        name: "Caution",
        scope: :shared,
        unique_name: "Caution#rus02"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx |> mes(" WARNING !! ") |> mes("No Swimming") |> close()
  end
end
