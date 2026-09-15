defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.HotelEmployee251212 do
  @moduledoc """
  Explains the Royal Dragon Hotel's priority policy for the Couple Suite.

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
        x: 251,
        y: 212,
        dir: 3,
        sprite: 868,
        name: "Hotel Employee",
        scope: :shared,
        unique_name: "Hotel Employee#zen2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Hotel Employee]")
    |> mes("This is the Couple Suite.")
    |> mes("A single can also check")
    |> mes("in here, but our hotel will")
    |> mes("prioritize couples when")
    |> mes("assigning this room.")
    |> close()
  end
end
