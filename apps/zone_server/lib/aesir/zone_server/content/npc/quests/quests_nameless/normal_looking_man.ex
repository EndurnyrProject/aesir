defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.NormalLookingMan do
  @moduledoc """
  A restaurant patron praises the food.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Koca
    - Yommy
    - brianluau
    - Euphy
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ra_in01",
        x: 301,
        y: 50,
        dir: 3,
        sprite: 927,
        name: "Normal-Looking Man",
        scope: :shared
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Normal-Looking Man]")
    |> mes("Mmm-Mmm!")
    |> mes("I love the food in")
    |> mes("this restaurant!")
    |> mes("They don't serve")
    |> mes("anything this this")
    |> mes("good anywhere else!")
    |> close()
  end
end
