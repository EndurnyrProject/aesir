defmodule Aesir.ZoneServer.Content.Npc.Cities.Gonryun.QianYuenShuang do
  @moduledoc """
  Reflects on Kunlun's chief and the safety his leadership provides.

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
        x: 118,
        y: 111,
        dir: 5,
        sprite: 89,
        name: "Qian Yuen Shuang",
        scope: :shared,
        unique_name: "Qian Yuen Shuang#gon"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Qian Yuen Shuang]")
    |> mes("The chief of this town is a man")
    |> mes("who opens his heart to others.")
    |> mes("However, I have heard that there")
    |> mes("are some people who don't like his personality...")
    |> next()
    |> mes("[Qian Yuen Shuang]")
    |> mes("Well, I like my town. The Chief's")
    |> mes("efforts have made our town safer.")
    |> mes("I just hope other people feel the")
    |> mes("same way about what he has done.")
    |> close()
  end
end
