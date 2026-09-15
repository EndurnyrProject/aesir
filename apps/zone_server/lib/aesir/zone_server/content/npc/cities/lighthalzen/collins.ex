defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Collins do
  @moduledoc """
  Discusses Collins's hope that his son will join the Rekenber Corporation.

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
        x: 115,
        y: 159,
        dir: 3,
        sprite: 866,
        name: "Collins",
        scope: :shared,
        unique_name: "Collins#zen1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Collins]")
    |> mes("I really wish that my")
    |> mes("son will be able to join")
    |> mes("the Rekenber Corporation.")
    |> mes("They certainly provide the")
    |> mes("best jobs in Lighthalzen.")
    |> next()
    |> mes("[Collins]")
    |> mes("Although they're a large,")
    |> mes("major corporation, it's")
    |> mes("almost impossible to get")
    |> mes("employed by them. How")
    |> mes("do people get hired there")
    |> mes("in the first place anyway?")
    |> close()
  end
end
