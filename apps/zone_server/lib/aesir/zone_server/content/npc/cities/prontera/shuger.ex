defmodule Aesir.ZoneServer.Content.Npc.Cities.Prontera.Shuger do
  @moduledoc """
  Warns new adventurers about Porings and the stronger Poporing.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prontera",
        x: 101,
        y: 288,
        dir: 3,
        sprite: 98,
        name: "Shuger",
        scope: :shared,
        unique_name: "Shuger#pront"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Shuger]")
    |> mes("Outside the safety of the city, there is a pink beast known as ^000077Poring^000000.")
    |> next()
    |> mes("[Shuger]")
    |> mes(
      "Though it's cute in appearance and does not actively harm people, Poring is known to absorb items that are on the ground into its own body."
    )
    |> next()
    |> mes("[Shuger]")
    |> mes(
      "So if there's something on the ground that you want to pick up, be careful lest it be consumed by a Poring. Then again... Porings are pretty weak..."
    )
    |> next()
    |> mes("[Shuger]")
    |> mes(
      "The green colored ^000077Poporing^000000 is tougher than Poring. Newbies generally make the mistake of attacking it without being aware of its power... So be careful!"
    )
    |> close()
  end
end
