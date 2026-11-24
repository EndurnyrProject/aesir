defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsEin.M2ndControlPanel do
  @moduledoc """
  The second control panel is an inspection point in the factory quest.

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
        x: 49,
        y: 232,
        dir: 3,
        sprite: 111,
        name: "2nd Control Panel",
        scope: :shared,
        unique_name: "2nd Control Panel#ins"
      }
    ]

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :EinFactory, 0) == 1 or get_char_var(ctx, :EinFactory, 0) == 2 do
      ctx =
        if isbegin_quest(ctx, 8017) == 1 do
          changequest(ctx, 8017, 8018)
        else
          ctx
        end

      ctx
      |> set_char_var(:EinFactory, 2)
      |> mes("^3355FFIt's the 2nd control panel")
      |> mes("Zelmeto asked you to inspect.")
      |> mes("It looks totally broken: screws")
      |> mes("are missing, and the iron cover")
      |> mes("has been bent open, revealing")
      |> mes("a tangled mess of wires inside.^000000")
      |> close()
    else
      ctx
    end
  end
end
