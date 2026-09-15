defmodule Aesir.ZoneServer.Content.Npc.Cities.Aldebaran.YoungMan do
  @moduledoc """
  Enthuses about rare level 4 weapons dropped by boss monsters.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "aldebaran",
        x: 49,
        y: 93,
        dir: 4,
        sprite: 83,
        name: "Young Man",
        scope: :shared,
        unique_name: "Young Man#alde"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Miller]")
    |> mes("Aren't level 4 weapons cool!")
    |> mes("I can't believe such powerful")
    |> mes("weapons exist!")
    |> next()
    |> mes("[Miller]")
    |> mes(
      "Well, they're rarely seen in the open market, but boss monsters will drop them by a low chance if you happen to be able to kill them."
    )
    |> close()
  end
end
