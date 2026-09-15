defmodule Aesir.ZoneServer.Content.Npc.Cities.Veins.Towner263153 do
  @moduledoc """
  Shares a resident's observations about life in Veins.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Muad_Dib

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "veins",
        x: 263,
        y: 153,
        dir: 5,
        sprite: 943,
        name: "Towner",
        scope: :shared,
        unique_name: "Towner#ve13"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Towner]")
    |> mes("The clothes we make here")
    |> mes("are high, airy, and sewn")
    |> mes("with high quality fabric.")
    |> mes("Of course, we need to wear")
    |> mes("stuff like this since the")
    |> mes("weather is unbearably hot.")
    |> next()
    |> mes("[Towner]")
    |> mes("The fabric? Well,")
    |> mes("I'll give you a hint.")
    |> mes("It's made of something")
    |> mes("related to camels. Heh!")
    |> mes("I'll leave you to figure it")
    |> mes("out on your own. Haha!")
    |> close()
  end
end
