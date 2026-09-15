defmodule Aesir.ZoneServer.Content.Npc.Cities.Veins.OldMan121199 do
  @moduledoc """
  Shares an elderly resident's observations about life in Veins.

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
        x: 121,
        y: 199,
        dir: 3,
        sprite: 945,
        name: "Old Man",
        scope: :shared,
        unique_name: "Old Man#ve2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Old Man]")
    |> mes("This isn't good.")
    |> mes("The elderly outnumber")
    |> mes("the youth here in Veins.")
    |> mes("We're too close to becoming")
    |> mes("something of a retirement")
    |> mes("community. You see it, right?")
    |> next()
    |> mes("[Old Man]")
    |> mes("I guess the young people")
    |> mes("aren't content living here")
    |> mes("since we lack a lot of the")
    |> mes("material excitement of other")
    |> mes("towns. They can't appreciate")
    |> mes("what's really special here...")
    |> close()
  end
end
