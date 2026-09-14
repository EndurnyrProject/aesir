defmodule Aesir.ZoneServer.Content.Npc.PreRe.Jobs.Novice.Novice.Guard do
  @moduledoc """
  Directs pre-renewal novices from the courtyard into the training castle.

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
        y: 116,
        dir: 2,
        sprite: 105,
        name: "Guard",
        unique_name: "Guard#nv1"
      },
      %{
        map: "new_2-1",
        x: 144,
        y: 116,
        dir: 2,
        sprite: 105,
        name: "Guard",
        unique_name: "Guard#nv2-1"
      },
      %{
        map: "new_3-1",
        x: 144,
        y: 116,
        dir: 2,
        sprite: 105,
        name: "Guard",
        unique_name: "Guard#nv3-1"
      },
      %{
        map: "new_4-1",
        x: 144,
        y: 116,
        dir: 2,
        sprite: 105,
        name: "Guard",
        unique_name: "Guard#nv4-1"
      },
      %{
        map: "new_5-1",
        x: 144,
        y: 116,
        dir: 2,
        sprite: 105,
        name: "Guard",
        unique_name: "Guard#nv5-1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Training Grounds Guard]")
    |> mes("Welcome to the Training Grounds.")
    |> mes(
      "You are now in the outer court yard. Please go inside the castle to begin your training."
    )
    |> close()
  end
end
