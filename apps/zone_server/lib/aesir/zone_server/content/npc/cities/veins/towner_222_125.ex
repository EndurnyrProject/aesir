defmodule Aesir.ZoneServer.Content.Npc.Cities.Veins.Towner222125 do
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
        x: 222,
        y: 125,
        dir: 5,
        sprite: 943,
        name: "Towner",
        scope: :shared,
        unique_name: "Towner#ve24"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Towner]")
    |> mes("I really want to")
    |> mes("ask out the woman")
    |> mes("right in front of me.")
    |> mes("Do you think she'll...?")
    |> next()
    |> mes("[Towner]")
    |> mes("Crap! Did I say that")
    |> mes("out loud? I-I-I really")
    |> mes("didn't want her to hear!")
    |> close()
  end
end
