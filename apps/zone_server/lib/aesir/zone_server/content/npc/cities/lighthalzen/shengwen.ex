defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Shengwen do
  @moduledoc """
  Shares Shengwen's remarks with visitors to Lighthalzen.

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
        x: 306,
        y: 324,
        dir: 3,
        sprite: 870,
        name: "Shengwen",
        scope: :shared,
        unique_name: "Shengwen#zen7"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Shengwen]")
    |> mes("Am I just getting")
    |> mes("paranoid? I really")
    |> mes("think that some of")
    |> mes("the people I know")
    |> mes("are disappearing")
    |> mes("for no good reason!")
    |> next()
    |> mes("[Shengwen]")
    |> mes("I mean, all of my close")
    |> mes("friends are all alright,")
    |> mes("but I'm starting not to see")
    |> mes("certain acquaintances and")
    |> mes("familiar faces. Maybe I'm")
    |> mes("just thinking too much...")
    |> close()
  end
end
