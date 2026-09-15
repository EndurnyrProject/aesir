defmodule Aesir.ZoneServer.Content.Npc.Cities.Einbroch.Tan do
  @moduledoc """
  Warns about Einbroch's pollution and recommends carrying a Flu Mask.

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
        x: 236,
        y: 191,
        dir: 3,
        sprite: 855,
        name: "Tan",
        scope: :shared,
        unique_name: "Tan#ein"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Tan]")
    |> mes("All the factories")
    |> mes("here in Einbroch are")
    |> mes("causing a serious air")
    |> mes("pollution problem.")
    |> next()
    |> mes("[Tan]")
    |> mes("I'm an Airship engineer and")
    |> mes("everyday, all day long, I deal")
    |> mes("with oil stains and all sorts")
    |> mes("of pollutants. I'm surprised")
    |> mes("I haven't gotten sick yet...")
    |> next()
    |> mes("[Tan]")
    |> mes("Still, I try to be careful")
    |> mes("when I can. Whenever I go")
    |> mes("out into the city's red fog,")
    |> mes("I always wear my Flu Mask.")
    |> mes("If you'll be here for a while,")
    |> mes("you should carry one with you.")
    |> close()
  end
end
