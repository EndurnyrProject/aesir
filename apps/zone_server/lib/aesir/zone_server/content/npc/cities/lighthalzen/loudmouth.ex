defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Loudmouth do
  @moduledoc """
  Recounts a dubious wartime story to visitors.

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
      %{map: "lhz_in03", x: 184, y: 38, dir: 3, sprite: 55, name: "Loudmouth", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Loudmouth]")
    |> mes("Do you know who I am?!")
    |> mes("Just look at this peg leg.")
    |> mes("I was in the Comodo War,")
    |> mes("Ski Troop division! I lost my")
    |> mes("leg to earn your freedom!")
    |> next()
    |> mes("[Loudmouth]")
    |> mes("H-hey! What's that")
    |> mes("look for? What, you")
    |> mes("don't believe me?!")
    |> close()
  end
end
