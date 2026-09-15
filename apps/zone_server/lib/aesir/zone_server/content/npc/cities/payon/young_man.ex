defmodule Aesir.ZoneServer.Content.Npc.Cities.Payon.YoungMan do
  @moduledoc """
  Welcomes travelers to Payon and recommends fighting alongside varied companions.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Muad Dib
    - Darkchild
    - DracoRPG
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "payon",
        x: 134,
        y: 211,
        dir: 4,
        sprite: 59,
        name: "Young Man",
        scope: :shared,
        unique_name: "Young Man#payon"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Young Man]")
    |> mes("From your attire,")
    |> mes("I can see that you")
    |> mes("are a stranger here.")
    |> mes("Welcome to Payon.")
    |> next()
    |> mes("[Young Man]")
    |> mes(
      "You must be a well-experienced fighter, otherwise you'd never be able to arrive here after passing the steep, mountainous areas and dangerous creatures surrounding this city."
    )
    |> next()
    |> mes("[Young Man]")
    |> mes(
      "I'm no expert at fighting, but someone once told me that sheer strength alone won't be able to win some battles."
    )
    |> next()
    |> mes("[Young Man]")
    |> mes(
      "Sometimes, you may encounter creatures protected by a hard-shell that don't be damaged by physical attacks. Only psychic power, like Magic, can easily defeat such creatures."
    )
    |> next()
    |> mes("[Young Man]")
    |> mes(
      "Of course, not everyone can study magic. The point is that you should keep different kinds of friends and comrades close to you, as you can't possibly handle every situation by yourself."
    )
    |> close()
  end
end
