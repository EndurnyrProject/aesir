defmodule Aesir.ZoneServer.Content.Npc.Cities.Einbroch.Vonstein do
  @moduledoc """
  Talks excitedly about the factory's molten metal.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - reddozen
    - Komurka
    - erKURITA
    - RockmanEXE
    - Dj-Yhn
    - Silent
    - Evera
    - Samuray22
    - DZeroX
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ein_in01",
        x: 64,
        y: 271,
        dir: 3,
        sprite: 855,
        name: "Vonstein",
        scope: :shared,
        unique_name: "Vonstein#ein"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Vonstein]")
    |> mes("Staring at this")
    |> mes("bubbling hot liquid")
    |> mes("metal gives me a good")
    |> mes("feeling inside. It's like")
    |> mes("that stuff can melt anything!")
    |> next()
    |> mes("[Vonstein]")
    |> mes("Imagine covering an")
    |> mes("entire street of people")
    |> mes("with that stuff! Bwahah--")
    |> mes("Oh, I'm sorry if I'm talking")
    |> mes("crazy talk! I'm just kidding~")
    |> close()
  end
end
