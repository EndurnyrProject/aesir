defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.HotelEmployee do
  @moduledoc """
  Offers hotel assistance and directions to the front desk.

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
        x: 242,
        y: 172,
        dir: 1,
        sprite: 868,
        name: "Hotel Employee",
        scope: :shared,
        unique_name: "Hotel Employee#zen3"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Hotel Employee]")
    |> mes("If you are experiencing")
    |> mes("any sort of inconvenience,")
    |> mes("please do not hesitate and")
    |> mes("let us know right away.")
    |> next()
    |> mes("[Hotel Employee]")
    |> mes("Please use the stairs")
    |> mes("at the northern end to")
    |> mes("go downstairs so that you")
    |> mes("can go to the Front Desk.")
    |> mes("Thank you and I hope that")
    |> mes("you enjoy your stay here.")
    |> close()
  end
end
