defmodule Aesir.ZoneServer.Content.Npc.Cities.Hugel.Emily do
  @moduledoc """
  Shares Emily's fondness for Hugel and her sister's unease.

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
    spawn: [%{map: "hugel", x: 126, y: 151, dir: 3, sprite: 90, name: "Emily", scope: :shared}]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Emily]")
    |> mes("I feel so blessed to")
    |> mes("live in this quant, little")
    |> mes("town. It's so beautiful, and")
    |> mes("everyone here is so nice~")
    |> next()
    |> mes("[Emily]")
    |> mes("For some reason, my older")
    |> mes("sister wants to move out of")
    |> mes("Hugel as soon as she can. She")
    |> mes("Says that she's getting crept")
    |> mes("out by the people that live here.")
    |> mes("Don't you think that sounds weird?")
    |> close()
  end
end
