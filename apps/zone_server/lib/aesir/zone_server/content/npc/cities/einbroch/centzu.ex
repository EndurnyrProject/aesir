defmodule Aesir.ZoneServer.Content.Npc.Cities.Einbroch.Centzu do
  @moduledoc """
  Reflects on Einbroch's rapid growth and its environmental cost.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - reddozen
    - Komurka
    - erKURITA
    - RockmanEXE
    - Dj-Yhn
    - Silent
    - Evera
    - Samuray22
    - DZeroX
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "einbroch",
        x: 294,
        y: 312,
        dir: 3,
        sprite: 854,
        name: "Centzu",
        scope: :shared,
        unique_name: "Centzu#ein"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Centzu]")
    |> mes("I've lived here for")
    |> mes("a long time and I see")
    |> mes("that this huge city is still")
    |> mes("growing bigger everyday.")
    |> next()
    |> mes("[Centzu]")
    |> mes("How did Einbroch get so")
    |> mes("huge so quickly? I still can't")
    |> mes("believe there's been this much")
    |> mes("development. Well, I suppose")
    |> mes("it's not my concern. Nothing")
    |> mes("I do will make a difference... ")
    |> next()
    |> mes("[Centzu]")
    |> mes("Even though such")
    |> mes("rapid industrialization")
    |> mes("can't be good for the")
    |> mes("environment or the people,")
    |> mes("I'll just sit back, watch what")
    |> mes("happens and just enjoy life...")
    |> close()
  end
end
