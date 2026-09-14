defmodule Aesir.ZoneServer.Content.Npc.PreRe.Jobs.Novice.Novice.Guard144107 do
  @moduledoc """
  Offers encouragement at the pre-renewal training castle entrance.

  ## Credits

  - Original from rAthena, authors: Dr.Evil and MasterOfMuppets.
  - Elixir adaptation: transpiled and refactored by an LLM.
  """

  use Aesir.ZoneServer.Npc,
    scope: :pre_renewal,
    spawn: [
      %{
        map: "new_1-1",
        x: 144,
        y: 107,
        dir: 2,
        sprite: 105,
        name: "Guard",
        unique_name: "Guard#nv2"
      },
      %{
        map: "new_2-1",
        x: 144,
        y: 107,
        dir: 2,
        sprite: 105,
        name: "Guard",
        unique_name: "Guard#nv2-2"
      },
      %{
        map: "new_3-1",
        x: 144,
        y: 107,
        dir: 2,
        sprite: 105,
        name: "Guard",
        unique_name: "Guard#nv3-2"
      },
      %{
        map: "new_4-1",
        x: 144,
        y: 107,
        dir: 2,
        sprite: 105,
        name: "Guard",
        unique_name: "Guard#nv4-2"
      },
      %{
        map: "new_5-1",
        x: 144,
        y: 107,
        dir: 2,
        sprite: 105,
        name: "Guard",
        unique_name: "Guard#nv5-2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Training Grounds Guard]")
    |> greet(:rand.uniform(2))
    |> close()
  end

  defp greet(ctx, 2) do
    ctx
    |> mes("Come in!")
    |> mes("I would like")
    |> mes("to welcome you to")
    |> mes("the Training Grounds!")
    |> next()
    |> mes("[Training Grounds Guard]")
    |> mes("In here, you can prepare")
    |> mes("yourself for your future")
    |> mes("adventures throughout the")
    |> mes("Ragnarok world!")
  end

  defp greet(ctx, 1) do
    ctx
    |> mes("Go, Novice, go!")
    |> mes("Fight, and grow stronger! Look towards a brighter tomorrow!")
  end
end
