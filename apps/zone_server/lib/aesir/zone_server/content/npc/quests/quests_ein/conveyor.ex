defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsEin.Conveyor do
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
        x: 46,
        y: 197,
        dir: 3,
        sprite: 111,
        name: "Conveyor",
        scope: :shared,
        unique_name: "Conveyor#ins"
      }
    ]

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :EinFactory, 0) == 7 or get_char_var(ctx, :EinFactory, 0) == 8 do
      ctx =
        if isbegin_quest(ctx, 8023) == 1 do
          changequest(ctx, 8023, 8024)
        else
          ctx
        end

      ctx
      |> set_char_var(:EinFactory, 8)
      |> mes("^3355FFThe conveyor's movements")
      |> mes("look jittery and clumsy. The")
      |> mes("mechanical arm also doesn't")
      |> mes("look powerful enough to bear")
      |> mes("the loads that it's carrying. The screws in the conveyor look")
      |> mes("loose and rusted over.^000000")
      |> close()
    else
      ctx
    end
  end
end
