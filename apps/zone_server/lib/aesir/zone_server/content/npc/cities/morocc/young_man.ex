defmodule Aesir.ZoneServer.Content.Npc.Cities.Morocc.YoungMan do
  @moduledoc """
  Describes Morocc’s ancient pyramids and the monsters living inside them.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "moc_ruins",
        x: 123,
        y: 154,
        dir: 0,
        sprite: 99,
        name: "Young Man",
        scope: :shared,
        unique_name: "Young Man#moc01"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Young Man]")
    |> mes(
      "The town's completely destroyed, but that giant triangular structure hasn't been harmed at all. Maybe it's protected by some kinda special power."
    )
    |> next()
    |> mes("[Young Man]")
    |> mes(
      "You know...Those giant, triangular buildings at the NorthWest corner of Morocc known are known to us as Pyramids..."
    )
    |> next()
    |> mes("[Young Man]")
    |> mes(
      "Those things have been around here for thousands and thousands of years. No one knows when and why they were built, or who built them."
    )
    |> next()
    |> mes("[Young Man]")
    |> mes(
      "All we know is that tons of monsters live inside those weird buildings. You might wanna stay away from those really dangerous places."
    )
    |> next()
    |> mes("[Young Man]")
    |> mes(
      "Those monsters in the Pyramid would be very, very sensitive to sweet flash smell of people...."
    )
    |> close()
  end
end
