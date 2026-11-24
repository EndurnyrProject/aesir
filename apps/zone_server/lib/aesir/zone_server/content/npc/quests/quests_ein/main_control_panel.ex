defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsEin.MainControlPanel do
  @moduledoc """
  The main control panel is an inspection point in the factory quest.

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
        x: 62,
        y: 258,
        dir: 3,
        sprite: 111,
        name: "Main Control Panel",
        scope: :shared,
        unique_name: "Main Control Panel#ins"
      }
    ]

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :EinFactory, 0) == 5 or get_char_var(ctx, :EinFactory, 0) == 6 do
      ctx =
        if isbegin_quest(ctx, 8021) == 1 do
          changequest(ctx, 8021, 8022)
        else
          ctx
        end

      ctx
      |> set_char_var(:EinFactory, 6)
      |> mes("^3355FFThe main control panel")
      |> mes("doesn't look like it has")
      |> mes("any problems. But after")
      |> mes("tapping on its surface,")
      |> mes("you hear a disheartening")
      |> mes("hollow sound. It looks like")
      |> mes("it's missing some parts...^000000")
      |> close()
    else
      ctx
    end
  end
end
