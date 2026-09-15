defmodule Aesir.ZoneServer.Content.Npc.Cities.Comodo.Hallosu do
  @moduledoc """
  Explains that a Paros Lighthouse tower is closed for renovation.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "cmd_fild07",
        x: 52,
        y: 280,
        dir: 4,
        sprite: 100,
        name: "Hallosu",
        scope: :shared,
        unique_name: "Hallosu#cmd"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Hallosu]")
    |> mes("Hello, this is one of the")
    |> mes("lighthouses that make up")
    |> mes("Paros Lighthouse. However,")
    |> mes("right now it's undergoing")
    |> mes("renovation, so it's not")
    |> mes("open to the public.")
    |> close()
  end
end
