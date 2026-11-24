defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsEin.Kenka do
  @moduledoc """
  A disturbed room reveals clues during the murder quest.

  ## Behavior

  - Reveals the scene after the murder investigation has progressed.

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
        x: 231,
        y: 170,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#kenka",
        trigger: {2, 2}
      }
    ]

  @impl true
  def on_event("OnTouch_", ctx) do
    describe_room(ctx)
  end

  @impl true
  def on_talk(ctx) do
    describe_room(ctx)
  end

  defp describe_room(ctx) do
    if get_char_var(ctx, :Shinokas_Quest, 0) > 8 do
      ctx
      |> mes("^3355FFThe open window rattles")
      |> mes("as you enter the room and")
      |> mes("are welcomed by a sudden")
      |> mes("chill. A trail of red footprints")
      |> mes("lies near your feet.^000000")
      |> next()
      |> mes("^3355FFA grey sheet lies")
      |> mes("rumpled on the bed,")
      |> mes("but you can see dark red")
      |> mes("stains in between the folds.^000000")
      |> close()
    else
      ctx
    end
  end
end
