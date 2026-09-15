defmodule Aesir.ZoneServer.Content.Npc.Cities.Einbroch.Zherin do
  @moduledoc """
  Describes the responsibility of operating the factory blast furnace.

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
        x: 85,
        y: 261,
        dir: 3,
        sprite: 851,
        name: "Zherin",
        scope: :shared,
        unique_name: "Zherin#ein"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Zherin]")
    |> mes("I'm in charge of this")
    |> mes("blast furnace which")
    |> mes("contains all of this")
    |> mes("boiling magma.")
    |> next()
    |> mes("[Zherin]")
    |> mes("Even though it doesn't")
    |> mes("require actual labor, this")
    |> mes("job is pretty tiring. I've got")
    |> mes("to pay careful attention all")
    |> mes("the time. It's pretty stressful.")
    |> next()
    |> mes("[Zherin]")
    |> mes("Still, I'm proud of my job")
    |> mes("since I have the responsibility")
    |> mes("of ensuring employee safety.")
    |> mes("Anyway, don't get too close")
    |> mes("to the furnace. It won't do if")
    |> mes("you get burned on accident!")
    |> close()
  end
end
