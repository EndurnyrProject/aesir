defmodule Aesir.ZoneServer.Content.Npc.Cities.Einbroch.Gesin do
  @moduledoc """
  Complains about exhaustion and his wife's pursuit of wealth.

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
        map: "ein_in01",
        x: 103,
        y: 239,
        dir: 1,
        sprite: 849,
        name: "Gesin",
        scope: :shared,
        unique_name: "Gesin#ein"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Gesin]")
    |> mes("Arrrgh!")
    |> mes("This is killing me!")
    |> mes("Why should I be rich?")
    |> mes("What's wrong with living")
    |> mes("within our means?")
    |> next()
    |> mes("[Gesin]")
    |> mes("I've got no problem")
    |> mes("with my current way")
    |> mes("of life, but the old ball")
    |> mes("and chain disagrees.")
    |> mes("Why is she so obsessed")
    |> mes("with riches and power?")
    |> next()
    |> mes("[Gesin]")
    |> mes("Well, in any case, I'd")
    |> mes("like to help her, but I can't")
    |> mes("get up! I'm exhausted and")
    |> mes("my body is just overtaxed.")
    |> mes("I have no strength at all.")
    |> next()
    |> mes("[Gesin]")
    |> mes("This is horrible~")
    |> mes("I should be resting")
    |> mes("instead of worrying")
    |> mes("about making money...")
    |> close()
  end
end
