defmodule Aesir.ZoneServer.Content.Npc.Cities.Einbroch.Cendadt do
  @moduledoc """
  Discusses the Einbroch factory's disrepair and donated maintenance materials.

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
        x: 31,
        y: 217,
        dir: 3,
        sprite: 851,
        name: "Cendadt",
        scope: :shared,
        unique_name: "Cendadt#ein"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Cendadt]")
    |> mes("This factory has a lot")
    |> mes("of things that need fixing,")
    |> mes("pronto! I'm amazed that")
    |> mes("the place is still operating!")
    |> next()
    |> mes("[Cendadt]")
    |> mes("Lucky for us, I hear that")
    |> mes("some altruistic adventurers")
    |> mes("have been donating materials")
    |> mes("to help keep this factory from")
    |> mes("falling apart... Or worse.")
    |> mes("But that's just a rumor.")
    |> next()
    |> mes("[Cendadt]")
    |> mes("^666666*Sigh*^000000")
    |> mes("Even if it is true,")
    |> mes("there's nothing no one")
    |> mes("here can do. Nobody has")
    |> mes("the courage to challenge")
    |> mes("the system, you know?")
    |> next()
    |> mes("[Cendadt]")
    |> mes("I...")
    |> mes("I better get")
    |> mes("back to work")
    |> mes("before I get")
    |> mes("in trouble...")
    |> close()
  end
end
