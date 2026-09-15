defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Sefith do
  @moduledoc """
  Shares Sefith's remarks with visitors to Lighthalzen.

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
        map: "lighthalzen",
        x: 132,
        y: 103,
        dir: 5,
        sprite: 734,
        name: "Sefith",
        scope: :shared,
        unique_name: "Sefith#li_01"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Sefith]")
    |> mes("Good looks. Intelligence.")
    |> mes("Excellent manners. A strong,")
    |> mes("manly chin and overpowering,")
    |> mes("piercing eyes. Perfectly balanced passion and charisma. All the")
    |> mes("good things that ladies want.")
    |> next()
    |> mes("[Sefith]")
    |> mes("But enough about me. Let's")
    |> mes("discuss how sorry I should")
    |> mes("feel for any other man living")
    |> mes("in Lighthalzen. They don't hold")
    |> mes("a candle to my studliness~")
    |> close()
  end
end
