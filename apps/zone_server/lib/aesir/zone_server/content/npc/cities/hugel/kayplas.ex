defmodule Aesir.ZoneServer.Content.Npc.Cities.Hugel.Kayplas do
  @moduledoc """
  Talks about wanting an inexpensive red bottle.

  ## Credits

  - Original from rAthena, authors and Contributors
    - vicious_pucca
    - Poki#3
    - erKURITA
    - Munin

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [%{map: "hugel", x: 86, y: 165, dir: 5, sprite: 896, name: "Kayplas", scope: :shared}]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Kayplas]")
    |> mes("Ooh, I really want to")
    |> mes("have that red bottle.")
    |> mes("I should ask my mom")
    |> mes("to buy me one. It doesn't")
    |> mes("look too expensive, does it?")
    |> close()
  end
end
