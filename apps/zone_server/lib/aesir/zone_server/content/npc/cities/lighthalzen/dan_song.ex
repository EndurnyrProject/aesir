defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.DanSong do
  @moduledoc """
  Offers Dan Song's admiration for the player's eyes.

  ## Credits

  - Original from rAthena, authors and Contributors
    - erKURITA
    - Au{R}oN (Translated by Alan)
    - $ephiroth

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lighthalzen",
        x: 191,
        y: 134,
        dir: 3,
        sprite: 869,
        name: "Dan Song",
        scope: :shared,
        unique_name: "Dan Song#zen2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Dan Song]")
    |> mes("Those eyes of yours...")
    |> mes("So pure and so deep,")
    |> mes("like glimmering pools")
    |> mes("of light. So, so beautiful...")
    |> close()
  end
end
