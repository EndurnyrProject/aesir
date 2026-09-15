defmodule Aesir.ZoneServer.Content.Npc.Cities.Veins.Towner163212 do
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
        x: 163,
        y: 212,
        dir: 3,
        sprite: 940,
        name: "Towner",
        scope: :shared,
        unique_name: "Towner#ve21"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Towner]")
    |> mes("There's nothing but")
    |> mes("old people and children")
    |> mes("in this town. Where's a")
    |> mes("decent man worth marrying?")
    |> mes("There's a few bachelors that")
    |> mes("are my age, but... Well...")
    |> next()
    |> mes("[Towner]")
    |> mes("They're all too hairy or")
    |> mes("too muscular. I don't think")
    |> mes("I'll be able to get married")
    |> mes("anytime soon! Oh, the misery!")
    |> close()
  end
end
