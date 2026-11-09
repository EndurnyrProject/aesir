defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.Sorcerer do
  @moduledoc """
  Biolay, a sorcerer of the expedition camp who is waiting to be taken home.

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
        map: "mid_camp",
        x: 166,
        y: 248,
        dir: 4,
        sprite: 937,
        name: "Sorcerer",
        scope: :shared,
        unique_name: "Sorcerer#ep13bs"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Biolay]")
    |> mes("Sob...")
    |> mes("Where is she?")
    |> next()
    |> mes("[Biolay]")
    |> mes("I was just wandering")
    |> mes("around Morocc and")
    |> mes("became faint. then")
    |> mes("I found myself here.")
    |> next()
    |> mes("[Biolay]")
    |> mes("I want to go back to my house.")
    |> emotion(:cry)
    |> close()
  end
end
