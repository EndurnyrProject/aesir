defmodule Aesir.ZoneServer.Content.Npc.Cities.Veins.Prisoner do
  @moduledoc """
  Shares a prisoner's observations about life in Veins.

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
        map: "ve_in",
        x: 119,
        y: 386,
        dir: 3,
        sprite: 946,
        name: "Prisoner",
        scope: :shared,
        unique_name: "Prisoner#ve1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Prisoner]")
    |> mes("Unbelievable!")
    |> mes("What kind of country")
    |> mes("is this?! How can you")
    |> mes("lock me up just because")
    |> mes("I don't believe in Freya?!")
    |> next()
    |> mes("[Prisoner]")
    |> mes("This isn't civilized!")
    |> mes("You're a bunch of savages")
    |> mes("if you can't respect my")
    |> mes("beliefs, you know that?")
    |> mes("Someone, someone help!")
    |> close()
  end
end
