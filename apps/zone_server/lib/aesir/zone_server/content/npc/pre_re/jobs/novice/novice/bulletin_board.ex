defmodule Aesir.ZoneServer.Content.Npc.PreRe.Jobs.Novice.Novice.BulletinBoard do
  @moduledoc """
  Welcomes novices to the pre-renewal training grounds.

  ## Credits

  - Original from rAthena, authors: Dr.Evil and MasterOfMuppets.
  - Elixir adaptation: transpiled and refactored by an LLM.
  """

  use Aesir.ZoneServer.Npc,
    scope: :pre_renewal,
    spawn: [
      %{
        map: "new_1-1",
        x: 66,
        y: 114,
        dir: 4,
        sprite: 111,
        name: "Bulletin Board",
        unique_name: "Bulletin Board#nv"
      },
      %{
        map: "new_2-1",
        x: 66,
        y: 114,
        dir: 4,
        sprite: 111,
        name: "Bulletin Board",
        unique_name: "Bulletin Board#nv2"
      },
      %{
        map: "new_3-1",
        x: 66,
        y: 114,
        dir: 4,
        sprite: 111,
        name: "Bulletin Board",
        unique_name: "Bulletin Board#nv3"
      },
      %{
        map: "new_4-1",
        x: 66,
        y: 114,
        dir: 4,
        sprite: 111,
        name: "Bulletin Board",
        unique_name: "Bulletin Board#nv4"
      },
      %{
        map: "new_5-1",
        x: 66,
        y: 114,
        dir: 4,
        sprite: 111,
        name: "Bulletin Board",
        unique_name: "Bulletin Board#nv5"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("^FF0000=================================^000000")
    |> mes(
      "^FF0000 ^000000 ^E40CAA[Welcome]^CC0000 to ^FF9000Novice^7FFF00 Training ^00FF00Grounds ^E40CAA[Welcome]^FF0000^000000"
    )
    |> mes("^FF0000=================================^000000")
    |> close()
  end
end
