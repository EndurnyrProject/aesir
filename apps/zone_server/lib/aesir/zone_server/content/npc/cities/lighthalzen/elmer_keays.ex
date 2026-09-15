defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.ElmerKeays do
  @moduledoc """
  Expresses Elmer Keays's enduring affection for his partner.

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
        x: 66,
        y: 94,
        dir: 3,
        sprite: 866,
        name: "Elmer Keays",
        scope: :shared,
        unique_name: "Elmer Keays#li_03"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Elmer Keays]")
    |> mes("Walking side by side")
    |> mes("with you like this reminds")
    |> mes("me of the old days. Back")
    |> mes("then, everyone was jealous")
    |> mes("that I had such a beautiful")
    |> mes("woman by my side. Heh heh~")
    |> next()
    |> mes("[Elmer Keays]")
    |> mes("You're still the most")
    |> mes("precious sight to these")
    |> mes("old eyes, my dear. I'm")
    |> mes("really lucky to be with you.")
    |> emotion(:chup)
    |> emotion(:chupchup)
    |> close()
  end
end
