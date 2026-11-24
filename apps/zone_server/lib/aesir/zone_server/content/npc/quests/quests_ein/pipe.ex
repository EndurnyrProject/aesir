defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsEin.Pipe do
  @moduledoc """
  The pipe is an inspection point in the factory quest.

  ## Behavior

  - Records the inspection and advances the corresponding quest log entry when active.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Evera
    - MasterOfMuppets
    - Lupus
    - KarLaeda
    - SinSloth
    - L0ne_W0lf
    - Yommy
    - Paradox924X
    - Kisuka
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ein_in01",
        x: 100,
        y: 266,
        dir: 3,
        sprite: 111,
        name: "Pipe",
        scope: :shared,
        unique_name: "Pipe#ins"
      }
    ]

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :EinFactory, 0) == 9 or get_char_var(ctx, :EinFactory, 0) == 10 do
      ctx =
        if isbegin_quest(ctx, 8025) == 1 do
          changequest(ctx, 8025, 8026)
        else
          ctx
        end

      ctx
      |> set_char_var(:EinFactory, 10)
      |> mes("^3355FFThe inspection of this")
      |> mes("pipe didn't take very long.")
      |> mes("It's bloated and worn out")
      |> mes("from long durations of ")
      |> mes("being overloaded with")
      |> mes("pressure. It's a wonder")
      |> mes("it hasn't exploded yet.")
      |> close()
    else
      ctx
    end
  end
end
