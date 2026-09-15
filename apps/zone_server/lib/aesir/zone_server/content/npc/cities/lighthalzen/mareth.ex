defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Mareth do
  @moduledoc """
  Shares Mareth's remarks with visitors to Lighthalzen.

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
        x: 157,
        y: 47,
        dir: 1,
        sprite: 797,
        name: "Mareth",
        scope: :shared,
        unique_name: "Mareth#seram"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Mareth]")
    |> mes("Yoo hoo hoo~")
    |> mes("Oh, how I love")
    |> mes("love love chocolate!")
    |> emotion(:throb)
    |> next()
    |> mes("[Mareth]")
    |> mes("Eat it up...")
    |> mes("Or just melt it.")
    |> mes("Slather it all over me.")
    |> mes("Booyah. New life aspiration.")
    |> close()
  end
end
