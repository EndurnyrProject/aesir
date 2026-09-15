defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Tadem do
  @moduledoc """
  Shares Tadem's remarks with visitors to Lighthalzen.

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
        x: 31,
        y: 34,
        dir: 3,
        sprite: 847,
        name: "Tadem",
        scope: :shared,
        unique_name: "Tadem#zen6"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Tadem]")
    |> mes("I do so enjoy the")
    |> mes("architectural structure")
    |> mes("of this bank. It's quite")
    |> mes("artistic with both classical")
    |> mes("and modern elements. Would")
    |> mes("you not agree? Fascinating...")
    |> close()
  end
end
