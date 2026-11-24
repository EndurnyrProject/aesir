defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.Ashe17190 do
  @moduledoc """
  Ashe entrusts the player with a file for her contact.

  ## Behavior

  - Advances the quest and directs the player to Morocc.

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
  - Added the missing `changequest 11007,11008` after `set hg_odin,59`, matching Ashe#2’s identical handoff.
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "hu_in01",
        x: 171,
        y: 90,
        dir: 0,
        sprite: 139,
        name: "Ashe",
        scope: :shared,
        unique_name: "Ashe#3",
        trigger: {2, 2}
      }
    ]

  @impl true
  def on_event("OnTouch_", ctx), do: on_talk(ctx)

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :hg_odin, 0) == 25 do
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
    else
      ctx
    end
  end
end
