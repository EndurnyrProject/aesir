defmodule Aesir.ZoneServer.Content.Npc.Cities.Veins.Kid291205 do
  @moduledoc """
  Shares a child's observations about life in Veins.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Muad_Dib

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "veins",
        x: 291,
        y: 205,
        dir: 3,
        sprite: 944,
        name: "Kid",
        scope: :shared,
        unique_name: "Kid#ve5"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Kid]")
    |> mes("Argh! I'm a war god")
    |> mes("protecting Goddess Freya")
    |> mes("and Arunafeltz! Ahhhhh!")
    |> mes("Death to all our enemies!")
    |> next()
    |> mes("[Kid]")
    |> mes("Burn, heretics, buuurn!")
    |> mes("Destroy your homes, your")
    |> mes("families, and build a new")
    |> mes("perfect world for Freya!")
    |> next()
    |> mes("[Kid]")
    |> mes("Hee hee! Doesn't that")
    |> mes("sound wonderful! When")
    |> mes("I grow up, I wanna be")
    |> mes("that kind of hero!")
    |> close()
  end
end
