defmodule Aesir.ZoneServer.Content.Npc.Cities.Veins.OldLady177147 do
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
        x: 177,
        y: 147,
        dir: 3,
        sprite: 942,
        name: "Old Lady",
        scope: :shared,
        unique_name: "Old Lady#ve2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Old Lady]")
    |> mes("Owning a lot of stuff")
    |> mes("might seem great, but")
    |> mes("many things aren't that")
    |> mes("valuable when you think")
    |> mes("of them in terms of")
    |> mes("real emotional value.")
    |> next()
    |> mes("[Old Lady]")
    |> mes("Well, that might have been")
    |> mes("a dangerous remark when")
    |> mes("I'm trying to sell things to")
    |> mes("customers. Still, I wish")
    |> mes("I could carry a wider")
    |> mes("selection of goods.")
    |> next()
    |> mes("[Old Lady]")
    |> mes("Of course, we're here")
    |> mes("in the middle of the desert,")
    |> mes("so maybe I'm asking too much.")
    |> close()
  end
end
