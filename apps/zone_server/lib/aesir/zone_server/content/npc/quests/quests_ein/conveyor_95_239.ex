defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsEin.Conveyor95239 do
  @moduledoc """
  This conveyor is an inspection point in the factory quest.

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
        x: 95,
        y: 239,
        dir: 3,
        sprite: 111,
        name: "Conveyor",
        scope: :shared,
        unique_name: "Conveyor#ins2"
      }
    ]

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :EinFactory, 0) == 11 or get_char_var(ctx, :EinFactory, 0) == 12 do
      ctx =
        if isbegin_quest(ctx, 8027) == 1 do
          changequest(ctx, 8027, 8028)
        else
          ctx
        end

      ctx
      |> set_char_var(:EinFactory, 12)
      |> mes("^3355FFThis conveyor seems")
      |> mes("to have similar problems")
      |> mes("as its smaller version. Its")
      |> mes("movements are awkward,")
      |> mes("erratic and weak, and almost")
      |> mes("all of its screws are rusted.^000000")
      |> close()
    else
      ctx
    end
  end
end
