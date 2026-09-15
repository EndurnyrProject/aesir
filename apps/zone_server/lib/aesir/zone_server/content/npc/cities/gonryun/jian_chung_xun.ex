defmodule Aesir.ZoneServer.Content.Npc.Cities.Gonryun.JianChungXun do
  @moduledoc """
  Celebrates Kunlun's year-round festival atmosphere.

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
        x: 200,
        y: 82,
        dir: 3,
        sprite: 774,
        name: "Jian Chung Xun",
        scope: :shared,
        unique_name: "Jian Chung Xun#gon"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Jian Chung Xun]")
    |> mes("I simply adore festivals.")
    |> mes("That's why I love this town.")
    |> mes("This town makes me feel like I am")
    |> mes("in the middle of a festival all year round.")
    |> close()
  end
end
