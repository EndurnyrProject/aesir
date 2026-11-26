defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.CommonLookingMan do
  @moduledoc """
  A diner shares his preference for Hugel restaurants.

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
        y: 52,
        dir: 3,
        sprite: 927,
        name: "Common-Looking Man",
        scope: :shared
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Common-Looking Man]")
    |> mes("The food here isn't bad,")
    |> mes("but my favorite restaurants")
    |> mes("are over in Hugel. The food")
    |> mes("over there is definitely best.")
    |> close()
  end
end
