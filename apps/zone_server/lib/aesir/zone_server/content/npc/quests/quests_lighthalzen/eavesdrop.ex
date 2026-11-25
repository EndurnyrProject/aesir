defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.Eavesdrop do
  @moduledoc """
  Lets the player overhear a suspicious conversation.

  ## Behavior

  - Reveals the conversation during the president quest.

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
        map: "yuno_pre",
        x: 117,
        y: 60,
        dir: 0,
        sprite: 111,
        name: "Eavesdrop",
        scope: :shared,
        trigger: {10, 5}
      }
    ]

  @impl true
  def on_event("OnTouch_", ctx), do: overhear(ctx)

  @impl true
  def on_talk(ctx), do: overhear(ctx)

  defp overhear(ctx) do
    if get_char_var(ctx, :lhz_boss, 0) == 16 do
      ctx
      |> mes("^3355FFWhat the...?")
      |> mes("You can hear")
      |> mes("whispers coming")
      |> mes("from the window.^000000")
      |> next()
      |> mes("[????]")
      |> mes("^333333That's expected...")
      |> mes("But... Why did...")
      |> mes("... the president...^000000")
      |> next()
      |> mes("[?????]")
      |> mes("^666666.......So...................")
      |> mes("...their investigation...")
      |> mes("............of course.........")
      |> mes("...just bait...................^000000")
      |> next()
      |> mes("[????]")
      |> mes("^333333...Next election.....")
      |> mes("..............................")
      |> mes("....you'll be................")
      |> mes("...............Can't stop us.^000000")
      |> next()
      |> mes("^3355FFThe whispers grow")
      |> mes("lower and lower until")
      |> mes("you can no longer hear")
      |> mes("anything. One of those")
      |> mes("voices seemed so familiar...^000000")
      |> close()
    else
      ctx
    end
  end
end
