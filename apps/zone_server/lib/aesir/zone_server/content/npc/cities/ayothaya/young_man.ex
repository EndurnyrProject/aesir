defmodule Aesir.ZoneServer.Content.Npc.Cities.Ayothaya.YoungMan do
  @moduledoc """
  Warns visitors about Ayothaya's ancient haunted building.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ayothaya",
        x: 189,
        y: 120,
        dir: 3,
        sprite: 843,
        name: "Young Man",
        scope: :shared,
        unique_name: "Young Man#Thang"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Thang]")
    |> mes("There's an ancient,")
    |> mes("dreadful building in")
    |> mes("Ayothaya that no one")
    |> mes("here dares approach...")
    |> next()
    |> mes("[Thang]")
    |> mes(
      "In the past, a few curious people went inside, despite the horror stories, and never returned. What on earth could be going on inside of that place?"
    )
    |> next()
    |> mes("[Thang]")
    |> mes(
      "However, if you want to prove your courage to others, confronting the danger inside might be a worthy challenge for an adventurer..."
    )
    |> mes("I think.")
    |> close()
  end
end
