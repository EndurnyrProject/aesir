defmodule Aesir.ZoneServer.Content.Npc.Cities.Jawaii.JawaiiResident168247 do
  @moduledoc """
  Directs Jawaii tourists to lodging and return ships.

  ## Credits

  - Original from rAthena, authors and Contributors
    - jAthena
    - DNett123
    - L0ne_w0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "jawaii",
        x: 168,
        y: 247,
        dir: 5,
        sprite: 724,
        name: "Jawaii Resident",
        scope: :shared,
        unique_name: "Jawaii Resident#desc2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Waja Waja]")
    |> mes("Ah, you must be a tourist.")
    |> mes("If you're lost, just head West. Accommodations for newlyweds")
    |> mes("are located in the western part of Jawaii. The lodging here is")
    |> mes("pretty amazing.")
    |> next()
    |> mes("[Waja Waja]")
    |> mes(
      "There are four different themed rooms, so you can choose one to your liking. There's a Guide around if you want to ask for more information."
    )
    |> next()
    |> mes("[Waja Waja]")
    |> mes("When you want to go back, please head to the NorthWest to board")
    |> mes(
      "a ship to Alberta. If you want to sail to Izlude, there's a ship waiting in the SouthEast."
    )
    |> close()
  end
end
