defmodule Aesir.ZoneServer.Content.Npc.Cities.Aldebaran.FriendlyLookingMan do
  @moduledoc """
  Warns visitors about his noisy neighbor.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "aldeba_in",
        x: 219,
        y: 61,
        dir: 4,
        sprite: 109,
        name: "Friendly-Looking Man",
        scope: :shared,
        unique_name: "Friendly-Looking Man#ald"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Friendly-Looking Man]")
    |> mes("You don't have to listen to a guy right next to my room.")
    |> mes("Two years ago, he was in a mercenary training center and fell off from a tree")
    |> mes("while trying to gather a nut from it.")
    |> next()
    |> mes("[Friendly-Looking Man]")
    |> mes("He keeps talking to himself loud and it gives me a headache...")
    |> mes("Gosh!")
    |> close()
  end
end
