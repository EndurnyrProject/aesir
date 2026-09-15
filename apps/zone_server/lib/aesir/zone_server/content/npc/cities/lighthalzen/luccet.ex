defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Luccet do
  @moduledoc """
  Shares Luccet's remarks with visitors to Lighthalzen.

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
        map: "lhz_in01",
        x: 43,
        y: 52,
        dir: 3,
        sprite: 703,
        name: "Luccet",
        scope: :shared,
        unique_name: "Luccet#li_party"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Luccet]")
    |> mes("Shhhh! Hey, my brother's")
    |> mes("''it,'' so I gotta find a place")
    |> mes("to hide! Wait, would you just")
    |> mes("stand really still? I could")
    |> mes("just hide behind you! No?")
    |> mes("Nuts! Olly olly oxen free!")
    |> close()
  end
end
