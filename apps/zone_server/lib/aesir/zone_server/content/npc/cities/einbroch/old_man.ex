defmodule Aesir.ZoneServer.Content.Npc.Cities.Einbroch.OldMan do
  @moduledoc """
  Explains how assorted monster materials can be useful for crafting.

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
        map: "airport",
        x: 176,
        y: 41,
        dir: 4,
        sprite: 88,
        name: "Old Man",
        scope: :shared,
        unique_name: "Old Man#air"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Zhen Lan]")
    |> mes("Now, I hear that the")
    |> mes("monsters around here")
    |> mes("carry around some ore")
    |> mes("that dazzles with a sublimely")
    |> mes("beautiful light. Neat, huh?")
    |> next()
    |> mes("[Zhen Lan]")
    |> mes("These ores are a great")
    |> mes("material to use in making")
    |> mes("flower vases. My friend, who")
    |> mes("happens to be a doll maker,")
    |> mes("told me that. He makes these dolls using all sorts of materials.")
    |> next()
    |> mes("[Zhen Lan]")
    |> mes("He fashions them out of")
    |> mes("Well-Tanned Leather, stuffs")
    |> mes("them with Bird Feathers, and")
    |> mes("uses Cyfar or Zargon to make")
    |> mes("the eyes. He even uses a Jellopy at the bottom to balance the doll.")
    |> next()
    |> mes("[Zhen Lan]")
    |> mes("I guess that goes to show")
    |> mes("that things that seem useless")
    |> mes("might actually be handy in some")
    |> mes(
      "way. So don't worry about having too much stuff. Sooner or later, it might be useful to someone."
    )
    |> close()
  end
end
