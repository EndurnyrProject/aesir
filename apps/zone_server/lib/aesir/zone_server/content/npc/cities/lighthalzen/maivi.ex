defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Maivi do
  @moduledoc """
  Shares Maivi's remarks with visitors to Lighthalzen.

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
        x: 78,
        y: 120,
        dir: 3,
        sprite: 862,
        name: "Maivi",
        scope: :shared,
        unique_name: "Maivi#zen1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Maivi]")
    |> mes("...")
    |> next()
    |> mes("[Maivi]")
    |> mes("...")
    |> mes("......")
    |> next()
    |> mes("[Maivi]")
    |> mes("Ah...")
    |> mes("I just had the nicest")
    |> mes("nap. This nice weather")
    |> mes("never fails to relax me.")
    |> mes("The air here is so clean,")
    |> mes("not like that Einbroch~")
    |> next()
    |> mes("[Maivi]")
    |> mes("This clean, pristine")
    |> mes("environment is all thanks")
    |> mes("to the Rekenber Corporation.")
    |> mes("It's incredible what they can")
    |> mes("do with technology now, isn't")
    |> mes("it? Ahhh, it's so peaceful~")
    |> close()
  end
end
