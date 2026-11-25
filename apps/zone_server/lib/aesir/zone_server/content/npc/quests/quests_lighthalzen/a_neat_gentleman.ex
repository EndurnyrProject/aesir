defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.ANeatGentleman do
  @moduledoc """
  Keeps the president’s advisor hidden until he is needed.

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
        x: 75,
        y: 73,
        dir: 0,
        sprite: 109,
        name: "A Neat Gentleman",
        scope: :shared
      }
    ]

  @impl true
  def on_event("OnInit", ctx), do: disablenpc(ctx, "A Neat Gentleman")

  @impl true
  def on_talk(ctx), do: disablenpc(ctx, "A Neat Gentleman")
end
