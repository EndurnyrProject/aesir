defmodule Aesir.ZoneServer.Content.Npc.Cities.Ayothaya.YoungMan214142 do
  @moduledoc """
  Encourages visitors to learn Ayothaya's traditional martial arts.

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
        x: 214,
        y: 142,
        dir: 5,
        sprite: 843,
        name: "Young Man",
        scope: :shared,
        unique_name: "Young Man#5ayothaya"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Detzi]")
    |> mes(
      "In Ayothaya, we have our own traditional martial arts. We, the young men of the village, practice our traditional martial arts in order to become strong."
    )
    |> next()
    |> mes("[Detzi]")
    |> mes(
      "Why don't you learn our martial arts? I guarantee that it will help you greatly in your travels."
    )
    |> close()
  end
end
