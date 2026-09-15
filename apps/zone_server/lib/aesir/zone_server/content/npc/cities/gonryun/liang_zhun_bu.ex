defmodule Aesir.ZoneServer.Content.Npc.Cities.Gonryun.LiangZhunBu do
  @moduledoc """
  Praises Kunlun's independence and resistance to invaders.

  ## Credits

  - Original from rAthena, authors and Contributors
    - x[tsk]
    - KarLaeda

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "gonryun",
        x: 268,
        y: 88,
        dir: 3,
        sprite: 776,
        name: "Liang Zhun Bu",
        scope: :shared,
        unique_name: "Liang Zhun Bu#gon"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Liang Zhun Bu]")
    |> mes("We are proud to be an independent")
    |> mes("nation, and have been fighting")
    |> mes("against the evil invaders who've")
    |> mes("wanted to conquer this blessed land for many years...")
    |> next()
    |> mes("[Liang Zhun Bu]")
    |> mes("But we have victoriously fended")
    |> mes("off every invasion! As long")
    |> mes("as we believe in ourselves,")
    |> mes("we shall never forget the")
    |> mes("Triumphal Song that has helped us in our struggles.")
    |> close()
  end
end
