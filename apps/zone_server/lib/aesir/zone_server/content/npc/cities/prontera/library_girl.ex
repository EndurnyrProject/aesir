defmodule Aesir.ZoneServer.Content.Npc.Cities.Prontera.LibraryGirl do
  @moduledoc """
  Describes the books available in Prontera Library's eastern branch.

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
        map: "prt_in",
        x: 175,
        y: 50,
        dir: 0,
        sprite: 71,
        name: "Library Girl",
        scope: :shared,
        unique_name: "Library Girl#pront"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Library Girl Ellen]")
    |> mes(
      "Here in the Eastern branch of the Prontera Library, we provide Monster Encyclopedias in which creatures are organized by their properties. We also have books on Merchant and Blacksmith skills."
    )
    |> mes(
      "Ooh~! The other branch of our library also has many interesting things to read! So if you get a chance, you just might want to visit."
    )
    |> close()
  end
end
