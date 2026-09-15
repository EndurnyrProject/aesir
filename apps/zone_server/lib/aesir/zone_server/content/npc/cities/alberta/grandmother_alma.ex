defmodule Aesir.ZoneServer.Content.Npc.Cities.Alberta.GrandmotherAlma do
  @moduledoc """
  Warns adventurers about the dangers aboard the Sunken Ship.

  ## Credits

  - Original from rAthena, authors and Contributors
    - DZeroX

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "alberta",
        x: 93,
        y: 174,
        dir: 2,
        sprite: 103,
        name: "Grandmother Alma",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Grandmother Alma]")
    |> mes("Some time ago,")
    |> mes("a derelict ship")
    |> mes("drifted into")
    |> mes("Alberta harbour.")
    |> next()
    |> mes("[Grandmother Alma]")
    |> mes(
      "Hoping to save any survivors, some of the townspeople ventured into the ship. However, they all ran out terrified, saying that corpses were walking around inside the ship."
    )
    |> next()
    |> mes("[Grandmother Alma]")
    |> mes(
      "The ship was also packed with dangerous marine organisms, and they couldn't get inside, even if they wanted to."
    )
    |> next()
    |> mes("[Grandmother Alma]")
    |> mes(
      "We couldn't do anything about that ominous looking ship, and just left it as it was. Nowadays, exploration teams try to enter that ship and wipe out its monsters."
    )
    |> next()
    |> mes("[Grandmother Alma]")
    |> mes(
      "So it might be a good experience for a young person like yourself to be a recruit. But, it's still not worth risking your life if you're not strong enough."
    )
    |> close()
  end
end
