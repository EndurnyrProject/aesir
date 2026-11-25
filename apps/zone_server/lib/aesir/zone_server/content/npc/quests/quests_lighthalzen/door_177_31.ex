defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.Door17731 do
  @moduledoc """
  The archive door lets the investigator leave the restricted area.

  ## Behavior

  - Warns unauthorized visitors and opens for the active investigation.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Samuray22
    - Gepard
    - Euphy
    - Joseph
    - Capuche
    - JohnnyPlayy
    - Persian
    - Vicious_Pucca
    - aoa00
    - Evera
    - MasterOfMuppets
    - Lupus
    - Lord Gywall
    - DeNy
    - Vicious
    - Playtester
    - Silent
    - SinSloth

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lhz_in01",
        x: 177,
        y: 31,
        dir: 0,
        sprite: 111,
        name: "Door",
        scope: :shared,
        unique_name: "Door#sneak"
      }
    ]

  @impl true
  def on_talk(ctx) do
    quest = get_char_var(ctx, :lhz_boss, 0)

    cond do
      quest < 29 ->
        ctx
        |> mes("[Guard]")
        |> mes("This is a")
        |> mes("restricted area.")
        |> mes("Please keep clear")
        |> mes("if you do not have")
        |> mes("special authorization.")
        |> mes("Thank you for cooperating.")
        |> close()

      quest < 36 ->
        {ctx, choice} =
          ctx
          |> mes("^3355FFThe door is shut, but")
          |> mes("there is a device that")
          |> mes("looks sort of like the")
          |> mes("entry keypad that was on")
          |> mes("the other side of this door.^000000")
          |> next()
          |> select(["Manipulate device.", "Investigate further."])

        case choice do
          1 ->
            ctx
            |> mes("^3355FFOnce you touch the")
            |> mes("device, it automatically")
            |> mes("responds and the door")
            |> mes("quickly slides open.^000000")
            |> close2()
            |> warp("lhz_in01", 177, 26)

          2 ->
            close(ctx)

          _ ->
            ctx
        end

      true ->
        ctx
    end
  end
end
