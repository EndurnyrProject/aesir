defmodule Aesir.ZoneServer.Content.Npc.Cities.Gonryun.YuJiuXia do
  @moduledoc """
  Longs to taste alcohol but settles for Kunlun's new tea.

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
        map: "gon_in",
        x: 173,
        y: 27,
        dir: 3,
        sprite: 774,
        name: "Yu Jiu Xia",
        scope: :shared,
        unique_name: "Yu Jiu Xia#gon"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Yu Jiu Xia]")
    |> mes("Geez, just as I thought.")
    |> mes("They won't sell alcohol to me.")
    |> mes("Maybe its cuz I'm too young...")
    |> mes("Hmmm...I wonder how it tastes...")
    |> next()
    |> mes("[Yu Jiu Xia]")
    |> mes("However, I know they're making")
    |> mes("some tasty tea that even kids")
    |> mes("like me can enjoy.")
    |> mes("It makes my mouth water just")
    |> mes("thinking about this new tea.")
    |> close()
  end
end
