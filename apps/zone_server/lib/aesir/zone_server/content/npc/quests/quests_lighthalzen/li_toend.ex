defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.LiToend do
  @moduledoc """
  Routes visitors according to their progress in the curse quest.

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
        x: 43,
        y: 114,
        dir: 0,
        sprite: 45,
        name: "",
        scope: :shared,
        unique_name: "#li_toend",
        trigger: {1, 1}
      }
    ]

  @impl true
  def on_event("OnTouch_", ctx), do: route_visitor(ctx)

  @impl true
  def on_talk(ctx), do: route_visitor(ctx)

  defp route_visitor(ctx) do
    if get_char_var(ctx, :lhz_curse, 0) > 30 do
      warp(ctx, "lhz_que01", 97, 30)
    else
      warp(ctx, "lhz_in01", 277, 130)
    end
  end
end
