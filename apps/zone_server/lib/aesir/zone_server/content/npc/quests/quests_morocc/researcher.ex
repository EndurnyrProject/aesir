defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMorocc.Researcher do
  @moduledoc """
  A researcher warns others about a fire.

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
        x: 176,
        y: 43,
        dir: 7,
        sprite: 402,
        name: "Researcher",
        scope: :shared,
        unique_name: "Researcher#bpast_2_1"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> specialeffect(:cloaking)
    |> mes("[Researcher]")
    |> mes("Fire!")
    |> mes("Everybody, move, move!")
    |> close()
  end
end
