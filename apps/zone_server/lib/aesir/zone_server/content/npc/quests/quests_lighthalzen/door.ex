defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.Door do
  @moduledoc """
  A door offers an exit from the cube room.

  ## Behavior

  - Offers the player a way out of the room.

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
        map: "lhz_cube",
        x: 250,
        y: 184,
        dir: 0,
        sprite: 111,
        name: "Door",
        scope: :shared,
        unique_name: "Door#cube"
      }
    ]

  @impl true
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^3355FFYou've come upon a")
      |> mes("door that leads outside.^000000")
      |> next()
      |> select(["Exit", "Cancel"])

    case choice do
      1 -> warp(ctx, "lighthalzen", 310, 302)
      _ -> close(ctx)
    end
  end
end
