defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Mereth do
  @moduledoc """
  Shares Mereth's remarks with visitors to Lighthalzen.

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
        x: 129,
        y: 54,
        dir: 1,
        sprite: 869,
        name: "Mereth",
        scope: :shared,
        unique_name: "Mereth#erem"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("^3355FF*Shhhhhhzzzz*")
    |> mes("*Shhhhhhzzzz*^000000")
    |> next()
    |> mes("[Mereth]")
    |> mes("Shhhhh....")
    |> mes("Aaaaaaaahhh...")
    |> next()
    |> mes("^3355FFThe employee turned his")
    |> mes("head and peered into your")
    |> mes("eyes through the black mask")
    |> mes("on his face. Mereth stared")
    |> mes("wordlessly for a moment and")
    |> mes("then began to dance a lively,")
    |> mes("creepily jovial jig.^000000")
    |> close()
  end
end
