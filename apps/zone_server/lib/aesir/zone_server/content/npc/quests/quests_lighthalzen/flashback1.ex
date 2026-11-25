defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.Flashback1 do
  @moduledoc """
  A flashback recalls Kazien questioning the player.

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
        x: 187,
        y: 247,
        dir: 3,
        sprite: 139,
        name: "",
        scope: :shared,
        unique_name: "#flashback1",
        trigger: {2, 2}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena
  @impl true
  def on_event("OnTouch_", ctx) do
    ev_ontouch(ctx)
  end

  @impl true
  def on_talk(ctx) do
    ev_ontouch(ctx)
  end

  def ev_ontouch(ctx) do
    if get_char_var(ctx, :lhz_rekenber, 0) == 22 do
      ctx =
        ctx
        |> cutin("lhz_kaz11", 2)
        |> mes("[Kazien]")
        |> mes("-Don't you have anything to protect, huh?- ")
        |> mes("-Are you sure that you're always doing the right thing?-")
        |> next()
        |> mes("[Kazien]")
        |> mes("Answer me! Answer me! Answer meee!")
        |> next()
        |> set_char_var(:lhz_rekenber, 23)
        |> cutin("", 255)

      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes(".............Damn it.")
      |> close()
    else
      ctx
    end
  end
end
