defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Avetis do
  @moduledoc """
  Describes Avetis's illness and inability to afford medicine after missing work.

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
        map: "lhz_in03",
        x: 239,
        y: 38,
        dir: 3,
        sprite: 849,
        name: "Avetis",
        scope: :shared,
        unique_name: "Avetis#zen10"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Avetis]")
    |> mes("A-ack...")
    |> mes("^333333*Cough cough*^000000")
    |> mes("Would you give me")
    |> mes("some m-medicine?!")
    |> mes("^333333*Cough cough haack*^000000")
    |> mes("Sweet Christmas, it hurts...")
    |> next()
    |> mes("[Avetis]")
    |> mes("I sk-skipped work")
    |> mes("because I've been too")
    |> mes("sick t-to go. ^333333*Cough*^000000")
    |> mes("But now I don't have")
    |> mes("the money to ^333333*Haack*^000000")
    |> mes("buy med-medicine... ")
    |> close()
  end
end
