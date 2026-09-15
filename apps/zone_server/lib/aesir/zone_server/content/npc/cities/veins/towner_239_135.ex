defmodule Aesir.ZoneServer.Content.Npc.Cities.Veins.Towner239135 do
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
        map: "ve_in",
        x: 239,
        y: 135,
        dir: 5,
        sprite: 946,
        name: "Towner",
        scope: :shared,
        unique_name: "Towner#ve27"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Towner]")
    |> mes("Isn't the sun so hot?")
    |> mes("Doesn't it make you feel")
    |> mes("so thirsty? Well, you may")
    |> mes("want to consider quenching")
    |> mes("that nasty thirst with liquor!")
    |> next()
    |> mes("[Towner]")
    |> mes("My job is to serve")
    |> mes("delicious, life giving")
    |> mes("liquor to my customers to")
    |> mes("relieve their parched throats.")
    |> mes("Seeing their drunken smiles")
    |> mes("really makes my day~")
    |> close()
  end
end
