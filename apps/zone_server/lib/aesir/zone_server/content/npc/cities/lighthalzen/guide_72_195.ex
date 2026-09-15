defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Guide72195 do
  @moduledoc """
  Directs visitors toward the restricted library and laboratory.

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
        map: "lhz_in01",
        x: 72,
        y: 195,
        dir: 0,
        sprite: 90,
        name: "Guide",
        scope: :shared,
        unique_name: "Guide#lt1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Geonuii]")
    |> mes("Greetings. This path")
    |> mes("leads to the Library and")
    |> mes("the Laboratory. Please be")
    |> mes("aware that these places")
    |> mes("are restricted from access")
    |> mes("by the general public.")
    |> close()
  end
end
