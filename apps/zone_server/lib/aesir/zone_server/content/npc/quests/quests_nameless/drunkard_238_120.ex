defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.Drunkard238120 do
  @moduledoc """
  A drunkard amuses herself with laughter.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Koca
    - Yommy
    - brianluau
    - Euphy
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ve_in",
        x: 238,
        y: 120,
        dir: 4,
        sprite: 940,
        name: "Drunkard",
        scope: :shared,
        unique_name: "Drunkard#Aru1"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Drunkard]")
    |> mes("Hohohoho~")
    |> mes("Oh~ Hohohoho~")
    |> next()
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("She's kind of strange...")
    |> close()
  end
end
