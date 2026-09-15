defmodule Aesir.ZoneServer.Content.Npc.Cities.Gonryun.Guidev do
  @moduledoc """
  Welcomes visitors to Kunlun and recommends its scenery and miniatures.

  ## Credits

  - Original from rAthena, authors and Contributors
    - x[tsk]
    - KarLaeda

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "gonryun",
        x: 169,
        y: 71,
        dir: 3,
        sprite: 770,
        name: "Guidev",
        scope: :shared,
        unique_name: "Guidev#gon"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Li Xi Jiao]")
    |> mes("Welcome to Kunlun!")
    |> mes("Did you enjoy all the incredible")
    |> mes("scenery on your way here?")
    |> mes("The buildings may be small, but we")
    |> mes("all worked hard to build this city.")
    |> next()
    |> mes("[Li Xi Jiao]")
    |> mes("I have some miniatures of")
    |> mes("the Rune-Midgarts Kingdom.")
    |> mes("You can view all of Prontera in a")
    |> mes("single glance. The craftsmanship")
    |> mes("on these masterpieces is quite stunning!")
    |> next()
    |> mes("[Li Xi Jiao]")
    |> mes("If you look around carefully,")
    |> mes("You'll find all sorts of beautiful")
    |> mes("sights throughout the town.")
    |> close()
  end
end
