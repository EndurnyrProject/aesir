defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.OldBed do
  @moduledoc """
  An old bed that can be searched during the treasure hunt.

  ## Behavior

  - Examining the bed reveals mushrooms or causes a bite.
  - At stage 21, lifting the bed sheet marks four locations on the minimap, advances the quest
    to stage 22 and warps the player away from the voice that discovers them.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Kisuka
    - brianluau
    - Gepard
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Lemongrass
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "treasure01",
        x: 24,
        y: 39,
        dir: 0,
        sprite: 111,
        name: "Old Bed",
        scope: :shared,
        unique_name: "Old Bed#rus38"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :rhea_rus_main, 0) >= 21 and get_char_var(ctx, :rhea_rus_main, 0) < 26 do
      {ctx, choice} =
        ctx
        |> mes("- An old bed covered with dust and must -")
        |> next()
        |> select(["On the bed", "Under the bed", "Bed sheet"])

      case choice do
        1 ->
          ctx
          |> mes("- Mushrooms grow on the bed -")
          |> next()
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("...Life......")
          |> close()

        2 ->
          ctx
          |> mes("- You look at the under the bed -")
          |> next()
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("Ouch?!")
          |> specialeffect2(:hit2)
          |> percent_heal(hp: -5, sp: 0)
          |> next()
          |> mes("- Something unidentified bites your hand !! -")
          |> close()

        _ ->
          lift_sheet(ctx)
      end
    else
      ctx
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp lift_sheet(ctx) do
    if get_char_var(ctx, :rhea_rus_main, 0) != 21 do
      ctx |> mes("- While running in a hurry, the sheet is a bit torn -") |> close()
    else
      ctx
      |> mes("- You raise the dirty sheet that has many holes -")
      |> next()
      |> player_says("...?! What is this?")
      |> next()
      |> mes("- There is a scar on the sheet that seems to have the location !! -")
      |> mark_locations(1, 0xFF0000)
      |> next()
      |> player_says("...This may be?!")
      |> next()
      |> mes("[Voice unidentified]")
      |> mes("Who is there!?")
      |> mark_locations(2, 0x00FF00)
      |> then(&emotion(&1, :huk, playerattached(&1)))
      |> next()
      |> player_says("Eek, it would be best to run away now!")
      |> set_char_var(:rhea_rus_main, 22)
      |> close2()
      |> warp("treasure01", 68, 28)
    end
  end

  defp mark_locations(ctx, mode, color) do
    [{165, 58, 1}, {61, 183, 2}, {98, 118, 3}, {27, 115, 4}]
    |> Enum.reduce(ctx, fn {x, y, id}, ctx -> viewpoint(ctx, mode, x, y, id, color) end)
  end

  defp player_says(ctx, line) do
    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes(line)
  end
end
