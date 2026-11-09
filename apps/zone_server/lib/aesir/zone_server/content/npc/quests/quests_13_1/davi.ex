defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.Davi do
  @moduledoc """
  Davi, an expedition member in the camp's main building who is sore from walking.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script quests/quests_13_1.txt
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "mid_campin",
        x: 292,
        y: 120,
        dir: 4,
        sprite: 849,
        name: "Davi",
        scope: :shared,
        unique_name: "Davi#ep13bs"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Davi]")
    |> mes("Ahhh, my body...")
    |> mes("I walked too much...")
    |> mes("and my body hurts.")
    |> emotion(:cry)
    |> close()
  end
end
