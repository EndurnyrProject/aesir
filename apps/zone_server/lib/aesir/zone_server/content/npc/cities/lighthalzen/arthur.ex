defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Arthur do
  @moduledoc """
  Complains about the bank's uncomfortable chairs while enjoying its cool interior.

  ## Credits

  - Original from rAthena, authors and Contributors
    - erKURITA
    - Au{R}oN (Translated by Alan)
    - $ephiroth

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lhz_in02",
        x: 34,
        y: 41,
        dir: 1,
        sprite: 849,
        name: "Arthur",
        scope: :shared,
        unique_name: "Arthur#zen16"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Arthur]")
    |> mes("The chairs here are")
    |> mes("so not ergonomic. And")
    |> mes("they're uncomfortable too!")
    |> mes("But it's sooo cool inside this")
    |> mes("bank and I just wanted to get")
    |> mes("get away from all this heat...")
    |> close()
  end
end
