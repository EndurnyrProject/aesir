defmodule Aesir.ZoneServer.Content.Npc.Cities.Einbroch.Canphotii do
  @moduledoc """
  Reprimands visitors for entering the Einbroch factory work area.

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
        x: 43,
        y: 252,
        dir: 3,
        sprite: 852,
        name: "Canphotii",
        scope: :shared,
        unique_name: "Canphotii#ein"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Canphotii]")
    |> mes("Hustle, hustle!")
    |> mes("Pick up the pace!")
    |> mes("Anyone working too")
    |> mes("slowly will be punished!")
    |> next()
    |> mes("[Canphotii]")
    |> mes("Can't you understand")
    |> mes("that?! Now go to your")
    |> mes("station and get back to")
    |> mes("work! Wait, are you even")
    |> mes("an employee? If not, then")
    |> mes("stop wandering around!")
    |> next()
    |> mes("[Canphotii]")
    |> mes("You're not supposed")
    |> mes("to be able to get in here!")
    |> mes("I can't believe they let you")
    |> mes("in! This requires extreme")
    |> mes("disciplinary action!")
    |> close()
  end
end
