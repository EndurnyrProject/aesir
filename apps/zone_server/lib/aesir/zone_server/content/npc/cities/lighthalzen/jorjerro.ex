defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Jorjerro do
  @moduledoc """
  Describes Jorjerro sleeping motionlessly.

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
        x: 110,
        y: 40,
        dir: 3,
        sprite: 89,
        name: "Jorjerro",
        scope: :shared,
        unique_name: "Jorjerro#fhero"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("^3355FFThis man here")
    |> mes("is motionless,")
    |> mes("and for all intents")
    |> mes("and purposes, is")
    |> mes("soundly asleep.^000000")
    |> close()
  end
end
