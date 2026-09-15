defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Jiwon do
  @moduledoc """
  Praises Lighthalzen as a beautiful and peaceful place to live.

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
        x: 198,
        y: 285,
        dir: 5,
        sprite: 862,
        name: "Jiwon",
        scope: :shared,
        unique_name: "Jiwon#zen5"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Jiwon]")
    |> mes("I think we're really")
    |> mes("fortunate to be able to")
    |> mes("live in such a beautiful")
    |> mes("and peaceful city like this.")
    |> next()
    |> mes("[Jiwon]")
    |> mes("It's just so nice to")
    |> mes("have this pleasant weather,")
    |> mes("these lush gardens and to")
    |> mes("meet all of these kind people.")
    |> mes("Lighthalzen is like Asgard")
    |> mes("in Midgard, heaven on earth~")
    |> close()
  end
end
