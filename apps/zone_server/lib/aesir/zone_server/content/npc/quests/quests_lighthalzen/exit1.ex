defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.Exit1 do
  @moduledoc """
  A hidden passage leads to the cube room.

  ## Behavior

  - Allows entry only to players with the required quest flag.

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
        map: "lhz_dun02",
        x: 224,
        y: 6,
        dir: 0,
        sprite: 45,
        name: "Exit1",
        scope: :shared,
        unique_name: "Exit1#lt",
        trigger: {1, 1}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena
  @impl true
  def on_event("OnTouch_", ctx) do
    if Rathena.truthy?(:erlang.band(get_char_var(ctx, :MISC_QUEST, 0), 512)) do
      warp(ctx, "lhz_cube", 231, 90)
    else
      ctx
      |> mes("^3355FFYou found a passage that")
      |> mes("seems to lead somewhere,")
      |> mes("but you get the feeling that")
      |> mes("you shouldn't enter it for now.^000000")
      |> close()
    end
  end

  @impl true
  def on_talk(ctx), do: ctx
end
