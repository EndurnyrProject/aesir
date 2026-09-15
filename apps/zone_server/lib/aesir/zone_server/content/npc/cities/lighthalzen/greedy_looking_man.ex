defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.GreedyLookingMan do
  @moduledoc """
  Describes Khramptd's dream of building a palace on expensive land.

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
        x: 205,
        y: 208,
        dir: 4,
        sprite: 853,
        name: "Greedy Looking Man",
        scope: :shared,
        unique_name: "Greedy Looking Man#li_01"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Khramptd]")
    |> mes("The land around here")
    |> mes("is some pretty expensive")
    |> mes("property. Yes, it's perfect")
    |> mes("for building my awesome palace!")
    |> mes("I don't have enough funds at the")
    |> mes("moment, but the day will come~")
    |> close()
  end
end
