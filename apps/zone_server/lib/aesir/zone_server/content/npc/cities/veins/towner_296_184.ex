defmodule Aesir.ZoneServer.Content.Npc.Cities.Veins.Towner296184 do
  @moduledoc """
  Shares a resident's observations about life in Veins.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Muad_Dib

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "veins",
        x: 296,
        y: 184,
        dir: 3,
        sprite: 940,
        name: "Towner",
        scope: :shared,
        unique_name: "Towner#ve14"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Towner]")
    |> mes("Let me tell you a secret.")
    |> mes("But promise not to tell")
    |> mes("anyone else about it, okay?")
    |> next()
    |> mes("[Towner]")
    |> mes("When the time comes,")
    |> mes("the Temple of Cheshrumnir")
    |> mes("will open up and the giant")
    |> mes("Freya robot will launch!")
    |> mes("It'll destroy every country")
    |> mes("except Arunafeltz!")
    |> next()
    |> mes("[Towner]")
    |> mes("That robot can blow")
    |> mes("hurricanes from its mouth,")
    |> mes("and shoot lightning from")
    |> mes("its horns, and it can fire")
    |> mes("its fists away, and its")
    |> mes("chest is a flame thrower!")
    |> next()
    |> mes("[Towner]")
    |> mes("..............................")
    |> mes("You don't believe me, either.")
    |> mes("What did you just say? Zinger?")
    |> mes("Amazing Z? The hell's that?")
    |> close()
  end
end
