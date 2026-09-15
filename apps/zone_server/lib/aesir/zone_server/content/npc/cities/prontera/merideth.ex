defmodule Aesir.ZoneServer.Content.Npc.Cities.Prontera.Merideth do
  @moduledoc """
  Recounts Merideth's picnic encounter with Giant Hornets and a Queen Bee.

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
        map: "prontera",
        x: 106,
        y: 116,
        dir: 6,
        sprite: 91,
        name: "Merideth",
        scope: :shared,
        unique_name: "Merideth#pront"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Merideth]")
    |> mes(
      "The weather was nice on my day off so my family and I went for a picnic. We chose to go to a slightly secluded area where I saw something really interesting..."
    )
    |> next()
    |> mes("[Merideth]")
    |> mes(
      "It was a large group of Giant Hornets! What was even weirder was that they were all controlled by this one Queen Bee, following her every command."
    )
    |> next()
    |> mes("[Merideth]")
    |> mes(
      "They might just be bugs, but I think they've got the right idea. Men really ought to take commands from us women... We do things right!"
    )
    |> close()
  end
end
