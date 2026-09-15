defmodule Aesir.ZoneServer.Content.Npc.Cities.Comodo.Zyosegirl do
  @moduledoc """
  Shares the Sea Lady's work gathering shellfish and her dream of city life.

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
        map: "cmd_fild04",
        x: 188,
        y: 74,
        dir: 4,
        sprite: 93,
        name: "Zyosegirl",
        scope: :shared,
        unique_name: "Zyosegirl#cmd"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Zyosegirl]")
    |> mes("People call me the")
    |> mes("Sea Lady because I'm")
    |> mes("always here working,")
    |> mes("gathering clams and other")
    |> mes("sea creatures to sell. It's")
    |> mes("a pretty good living, actually.")
    |> next()
    |> mes("[Zyosegirl]")
    |> mes("It's nice to be able to work")
    |> mes("outdoors, but someday, I want")
    |> mes("to save enough money and move")
    |> mes("to the city. I'm still young, you know, and I've got dreams")
    |> mes("that I want to fulfill~")
    |> close()
  end
end
