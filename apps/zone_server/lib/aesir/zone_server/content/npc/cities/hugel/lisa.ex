defmodule Aesir.ZoneServer.Content.Npc.Cities.Hugel.Lisa do
  @moduledoc """
  Complains about Hugel's lack of privacy and dreams of city life.

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
    spawn: [%{map: "hugel", x: 71, y: 197, dir: 3, sprite: 90, name: "Lisa", scope: :shared}]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Lisa]")
    |> mes("Hugel is a pretty")
    |> mes("small, homely village.")
    |> mes("Everyone knows everyone,")
    |> mes("everybody knows what")
    |> mes("everybody else is doing.")
    |> mes("It's so suffocating!")
    |> next()
    |> mes("[Lisa]")
    |> mes("There's no privacy in")
    |> mes("small towns. Someday,")
    |> mes("I wanna go out and")
    |> mes("live in the big city~")
    |> close()
  end
end
