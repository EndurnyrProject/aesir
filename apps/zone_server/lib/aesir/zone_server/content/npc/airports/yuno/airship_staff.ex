defmodule Aesir.ZoneServer.Content.Npc.Airports.Yuno.AirshipStaff do
  @moduledoc """
  Directs travelers between Juno and the international airship.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Muad_Dib

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "yuno",
        x: 14,
        y: 262,
        dir: 5,
        sprite: 91,
        name: "Airship Staff",
        scope: :shared,
        unique_name: "Airship Staff#yuno01"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Airship Staff]")
    |> mes("Welcome to Juno Airport.")
    |> mes("Please use this door to")
    |> mes("board the Airship that will")
    |> mes("be flying all the way to Izlude")
    |> mes("in the Rune-Midgarts Kingdom,")
    |> mes("and to Rachel in the Arunafeltz")
    |> mes("Republic.")
    |> next()
    |> mes("[Airship Staff]")
    |> mes("Otherwise, if Juno is")
    |> mes("your intended destination,")
    |> mes("please head down the stairs")
    |> mes("and ask the Arrival Staff to lead")
    |> mes("you to the main terminal. Thank")
    |> mes("you, and enjoy your travels.")
    |> close()
  end
end
