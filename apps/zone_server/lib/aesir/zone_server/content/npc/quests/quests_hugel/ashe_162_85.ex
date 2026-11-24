defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.Ashe16285 do
  @moduledoc """
  Ashe passes the stolen file to the player.

  ## Behavior

  - Directs the player to her contact and updates the quest.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - SinSloth
    - Samuray22
    - L0ne_W0lf
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "hu_in01",
        x: 162,
        y: 85,
        dir: 4,
        sprite: 95,
        name: "Ashe",
        scope: :shared,
        unique_name: "Ashe#2"
      }
    ]

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :hg_odin, 0) do
      progress when progress in [22, 23] ->
        ctx
        |> mes("[Ashe]")
        |> mes("This...")
        |> mes("This doesn't")
        |> mes("look good at all!")
        |> close()

      25 ->
        ctx
        |> mes("^3355FFAshe picked up")
        |> mes("the file that Laura")
        |> mes("tossed away.^000000")
        |> next()
        |> mes("[Ashe]")
        |> mes("Um, I've got a favor")
        |> mes("of my own to ask you.")
        |> mes("Would you please bring")
        |> mes("this file to Morocc? Just")
        |> mes("bring it to my comrade")
        |> mes("over at the South Gate.")
        |> next()
        |> mes("[Ashe]")
        |> mes("I'm sorry, but we don't")
        |> mes("have much time left. I guess")
        |> mes("this is the last time we will")
        |> mes("ever see each other, so thank")
        |> mes("you for all your help, friend.")
        |> next()
        |> set_char_var(:hg_odin, 59)
        |> changequest(11007, 11008)
        |> mes("[Ashe]")
        |> mes("Don't worry, my comrade")
        |> mes("at Morocc's South Gate will")
        |> mes("explain everything once you")
        |> mes("find him. Please hurry!")
        |> close()

      59 ->
        ctx
        |> mes("[Ashe]")
        |> mes("Don't worry, my comrade")
        |> mes("at Morocc's South Gate will")
        |> mes("explain everything once you")
        |> mes("find him. Please hurry, and")
        |> mes("find him as soon as you can!")
        |> close()

      _ ->
        ctx
    end
  end
end
