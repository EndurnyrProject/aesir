defmodule Aesir.ZoneServer.Content.Npc.Cities.Alberta.Chad do
  @moduledoc """
  Shares Chad's skepticism about local legends.

  ## Credits

  - Original from rAthena, authors and Contributors
    - DZeroX

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [%{map: "alberta_in", x: 20, y: 183, dir: 0, sprite: 49, name: "Chad", scope: :shared}]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Chad]")
    |> mes(
      "People say the legendary weapon Gungnir never misses its target. I wonder if it's possibly true..."
    )
    |> next()
    |> mes("[Chad]")
    |> mes(
      "People also say that babies are assembled by the storks before delivery, girls dig guys who act like jerks, and that Santa Claus exists! But only in Lutie."
    )
    |> next()
    |> mes("[Chad]")
    |> mes("I wonder...")
    |> mes("If any of that")
    |> mes("is possibly")
    |> mes("true...")
    |> close()
  end
end
