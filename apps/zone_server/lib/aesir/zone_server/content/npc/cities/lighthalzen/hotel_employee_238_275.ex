defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.HotelEmployee238275 do
  @moduledoc """
  Introduces the Royal Dragon Hotel's hospitality and front desk.

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
        x: 238,
        y: 275,
        dir: 5,
        sprite: 869,
        name: "Hotel Employee",
        scope: :shared,
        unique_name: "Hotel Employee#zen1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Hotel Employee]")
    |> mes("''Hospitality with a smile")
    |> mes("and total devotion to your")
    |> mes("comfort.'' That's our motto")
    |> mes("in the Royal Dragon Hotel.")
    |> mes("Please inquire at the front")
    |> mes("desk if you wish to check in.")
    |> close()
  end
end
