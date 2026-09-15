defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.HealthyLookingGuy do
  @moduledoc """
  Denies accusations of hoarding item upgrade materials.

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
        map: "lhz_in02",
        x: 159,
        y: 198,
        dir: 7,
        sprite: 85,
        name: "Healthy Looking Guy",
        scope: :shared,
        unique_name: "Healthy Looking Guy#hol"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Healthy Looking Guy]")
    |> mes("Grrrrrr! Leave me alone!")
    |> mes("How many times do I have")
    |> mes("to keep telling you? I've never")
    |> mes("hoarded item upgrade materials!")
    |> mes("I swear that I'm innocent!")
    |> close()
  end
end
