defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsEin.M3rdPressureGovernor do
  @moduledoc """
  The third pressure governor is an inspection point in the factory quest.

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
        x: 108,
        y: 217,
        dir: 3,
        sprite: 111,
        name: "3rd Pressure Governor",
        scope: :shared,
        unique_name: "3rd Pressure Governor#1"
      }
    ]

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :EinFactory, 0) == 3 or get_char_var(ctx, :EinFactory, 0) == 4 do
      ctx =
        if isbegin_quest(ctx, 8019) == 1 do
          changequest(ctx, 8019, 8020)
        else
          ctx
        end

      ctx
      |> set_char_var(:EinFactory, 4)
      |> mes("^3355FFAt first glance, this")
      |> mes("pressure governor looks")
      |> mes("perfectly fine. But after you")
      |> mes("check it more carefully, you")
      |> mes("find that it's making strange")
      |> mes("grinding noises and a few of")
      |> mes("the surface screws are loose.")
      |> close()
    else
      ctx
    end
  end
end
