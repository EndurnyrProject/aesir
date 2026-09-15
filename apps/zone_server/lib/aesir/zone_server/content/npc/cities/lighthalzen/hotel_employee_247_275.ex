defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.HotelEmployee247275 do
  @moduledoc """
  Welcomes visitors to the Royal Dragon Hotel Bar.

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
        x: 247,
        y: 275,
        dir: 1,
        sprite: 868,
        name: "Hotel Employee",
        scope: :shared,
        unique_name: "Hotel Employee#zen4"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Hotel Employee]")
    |> mes("Welcome to the")
    |> mes("Royal Dragon Hotel Bar.")
    |> mes("How about a nice night")
    |> mes("cap before going to bed?")
    |> next()
    |> mes("[Hotel Employee]")
    |> mes("If you're looking")
    |> mes("for a friend, you")
    |> mes("can almost always")
    |> mes("make one in this bar.")
    |> mes("Alcohol certainly is the")
    |> mes("grease for social gears.")
    |> close()
  end
end
