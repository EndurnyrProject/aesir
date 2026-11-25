defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMorocc.Researcher18114 do
  @moduledoc """
  A researcher struggles to breathe during a fire.

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
        x: 181,
        y: 14,
        dir: 7,
        sprite: 865,
        name: "Researcher",
        scope: :shared,
        unique_name: "Researcher#bpast_2_2"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> specialeffect(:cloaking)
    |> mes("[Researcher]")
    |> mes("Cough, cough!")
    |> mes("Argh... I can't breathe... I have to get out...")
    |> close()
  end
end
